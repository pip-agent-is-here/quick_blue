#!/usr/bin/env python3
"""Build and capture observed local Linux inputs; never publishes anything.

Run from repository root: python3 scripts/capture-build-inputs.py
Evidence is written to .dart_tool/build-provenance. A release tag is only a
package-derived declaration, not proof that HEAD is a release/tagged commit.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def run(command, root):
    return subprocess.check_output(command, cwd=root, stderr=subprocess.STDOUT).decode()


def source_snapshot(root):
    paths = run(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], root).split('\0')
    files = []
    for name in sorted(set(filter(None, paths))):
        path = root / name
        if path.is_symlink():
            files.append({'path': name, 'symlink': os.readlink(path)})
        elif path.is_file():
            files.append({'path': name, 'sha256': digest(path)})
        else:
            files.append({'path': name, 'missing': True})
    return {'head': run(['git', 'rev-parse', 'HEAD'], root).strip(),
            'status': run(['git', 'status', '--porcelain=v1'], root), 'files': files}


def capture(root, output):
    output.mkdir(parents=True, exist_ok=True)
    commands = []

    def observe(command, cwd, name):
        commands.append({'argv': command, 'cwd': str(cwd.relative_to(root)), 'log': name})
        try:
            text = run(command, cwd)
        except subprocess.CalledProcessError as error:
            (output / name).write_bytes(error.output)
            raise
        (output / name).write_text(text)
        return text

    tools = {}
    for tool, args in [('flutter', ['--version', '--machine']), ('dart', ['--version']),
                       ('clang', ['--version']), ('cmake', ['--version']),
                       ('ninja', ['--version']), ('pkg-config', ['--version'])]:
        tools[tool] = {'executable': str(Path(shutil.which(tool) or tool).resolve()),
                       'observed': observe([tool] + args, root, tool + '.txt')}
    tools['gtk'] = {'observed': observe(['pkg-config', '--modversion', 'gtk+-3.0'], root, 'gtk.txt')}
    observe(['flutter', 'pub', 'get'], root, 'pub-get.txt')
    dependencies = json.loads(observe(['dart', 'pub', 'deps', '--json'], root, 'dependencies.json'))
    before = source_snapshot(root)
    dependency_files = ['pubspec.lock', '.dart_tool/package_config.json']
    dependency_hashes = {name: digest(root / name) for name in dependency_files}
    observe(['flutter', 'build', 'linux', '--release', '--no-pub'], root / 'quick_blue/example', 'build.txt')
    after = source_snapshot(root)
    if before != after:
        raise RuntimeError('Source changed during build; refusing misleading provenance')
    if dependency_hashes != {name: digest(root / name) for name in dependency_files}:
        raise RuntimeError('Resolved dependency inputs changed during build')
    match = re.search(r'^version: (\S+)$', (root / 'quick_blue/pubspec.yaml').read_text(), re.M)
    if match is None:
        raise RuntimeError('Missing package version')
    version = match.group(1)
    tag = 'v' + version
    name = f'quick_blue-example-{tag}-linux-x64.tar.gz'
    bundle = root / 'quick_blue/example/build/linux/x64/release/bundle'
    if not bundle.is_dir():
        raise RuntimeError('Successful build did not produce a Linux bundle')
    with tarfile.open(output / name, 'w:gz') as archive:
        for child in sorted(bundle.iterdir()):
            archive.add(child, arcname=child.name)
    checksum = digest(output / name)
    (output / (name + '.sha256')).write_text(f'{checksum}  {name}\n')
    build_root = root / 'quick_blue/example/build/linux/x64/release'
    native_files = {str(p.relative_to(root)): digest(p) for p in sorted(build_root.rglob('*'))
                    if p.is_file() and p.name in ('CMakeCache.txt', 'build.ninja')}
    bundle_files = {str(p.relative_to(bundle)): digest(p) for p in sorted(bundle.rglob('*')) if p.is_file()}
    evidence = {entry['log']: digest(output / entry['log']) for entry in commands}
    manifest = {'schema_version': 1, 'release_tag': tag, 'package_version': version,
                'assets': [{'name': name, 'sha256': checksum}],
                'provenance': {'scope': 'observed local Linux build inputs only',
                               'release_tag_kind': 'declared package-derived label; not observed Git tag',
                               'source': before, 'toolchains': tools, 'dependencies': dependencies,
                               'dependency_files': dependency_hashes, 'native_build_files': native_files,
                               'bundle_files': bundle_files, 'commands': commands, 'evidence_files': evidence,
                               'limitations': ['not hardware/native semantics proof', 'not reproducibility proof',
                                               'not signing or publication proof',
                                               'dependency identities/lock hashes, not exhaustive dependency byte attestation']}}
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    capture(root, root / '.dart_tool/build-provenance')
    print('Captured .dart_tool/build-provenance/manifest.json')
