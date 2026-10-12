#!/usr/bin/env python3
"""Validate release declarations offline, optionally checking local artifact bytes.

No tag checkout, build provenance, signing, reproducibility or publication is
attested. Additional manifest provenance fields are intentionally not validated.
The existing workflow tag grammar and publish-packages.sh version grammar are
preserved; a tag must also equal 'v' plus the shared package version.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

PACKAGES = ('quick_blue_platform_interface', 'quick_blue_darwin', 'quick_blue_linux',
            'quick_blue_windows', 'quick_blue')
ASSET_SUFFIXES = {'android': 'android.apk', 'ios': 'ios-simulator.zip',
                  'macos': 'macos.zip', 'linux': 'linux-x64.tar.gz',
                  'windows': 'windows-x64.zip'}
TAG = re.compile(r'v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?')
VERSION = re.compile(r'[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?')
CHECKSUM = re.compile(r'[0-9a-fA-F]{64}')


class ValidationError(ValueError):
    pass


def read_text(path):
    try:
        return path.read_text(encoding='utf-8')
    except (OSError, UnicodeError) as error:
        raise ValidationError(f'cannot read {path}: {error}') from error


def release_version(root, tag):
    if not isinstance(tag, str) or TAG.fullmatch(tag) is None:
        raise ValidationError(f'malformed release tag: {tag!r}')
    versions = {}
    for package in PACKAGES:
        # Match the repository's literal top-level version convention, not a
        # partial YAML parser that silently accepts duplicate definitions.
        values = re.findall(r'^version: (.*)$', read_text(root / package / 'pubspec.yaml'), re.M)
        if len(values) != 1 or VERSION.fullmatch(values[0]) is None:
            raise ValidationError(f'{package}: missing, duplicate or malformed package version')
        versions[package] = values[0]
    version = versions[PACKAGES[0]]
    for package, value in versions.items():
        if value != version:
            raise ValidationError(f'{package}: package version {value!r}; expected {version!r} from {PACKAGES[0]}')
    if tag != 'v' + version:
        raise ValidationError(f'release tag {tag!r} does not match package version {version!r}')
    return version


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValidationError(f'invalid manifest: duplicate JSON key {key!r}')
        result[key] = value
    return result


def load_manifest(path):
    try:
        return json.loads(read_text(path), object_pairs_hook=unique_object)
    except (ValueError, RecursionError) as error:
        raise ValidationError(f'invalid manifest: {error}') from error


def digest(path):
    checksum = hashlib.sha256()
    try:
        with path.open('rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                checksum.update(chunk)
    except OSError as error:
        raise ValidationError(f'cannot read {path}: {error}') from error
    return checksum.hexdigest()


def validate_manifest(manifest, tag, version, platforms, artifact_dir=None):
    if not isinstance(manifest, dict):
        raise ValidationError('invalid manifest: expected an object')
    if type(manifest.get('schema_version')) is not int or manifest['schema_version'] != 1:
        raise ValidationError('invalid manifest schema_version: expected integer 1')
    for field, expected in (('release_tag', tag), ('package_version', version)):
        if manifest.get(field) != expected:
            raise ValidationError(f'invalid manifest {field}: expected {expected!r}')
    assets = manifest.get('assets')
    if not isinstance(assets, list):
        raise ValidationError('invalid manifest assets: expected an array')
    expected = {f'quick_blue-example-{tag}-{ASSET_SUFFIXES[platform]}' for platform in platforms}
    seen = set()
    for asset in assets:
        if not isinstance(asset, dict) or not isinstance(asset.get('name'), str):
            raise ValidationError('invalid asset: expected object with string name')
        name = asset['name']
        if name in seen:
            raise ValidationError(f'duplicate asset: {name}')
        if name not in expected:
            raise ValidationError(f'unexpected asset: {name!r}')
        seen.add(name)
        checksum = asset.get('sha256')
        if not isinstance(checksum, str) or CHECKSUM.fullmatch(checksum) is None:
            raise ValidationError(f'invalid sha256 entry for {name}')
        if artifact_dir is not None:
            actual = digest(artifact_dir / name)
            if actual != checksum.lower():
                raise ValidationError(f'checksum mismatch for {name}: actual {actual}, declared {checksum}')
            sidecar = read_text(artifact_dir / (name + '.sha256'))
            # GNU/BSD text mode and GNU binary mode; exactly one named entry.
            match = re.fullmatch(r'([0-9a-fA-F]{64}) [ *]([^\r\n]+)\n?', sidecar)
            if match is None or match[2] != name or match[1].lower() != actual:
                raise ValidationError(f'invalid sidecar for {name}: expected one matching checksum and filename')
    missing = expected - seen
    if missing:
        raise ValidationError('missing assets: ' + ', '.join(sorted(missing)))
    return len(seen)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo-root', type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument('--tag', required=True, help='Expected declared release tag, e.g. v0.5.0')
    parser.add_argument('--manifest', type=Path, help='schema_version=1 JSON asset manifest')
    parser.add_argument('--platform', action='append', choices=tuple(ASSET_SUFFIXES),
                        help='Explicit partial manifest selection; repeat for multiple platforms. Default: all five.')
    parser.add_argument('--artifact-dir', type=Path, help='Also hash bytes and check .sha256 sidecars')
    args = parser.parse_args(argv)
    if args.artifact_dir is not None and args.manifest is None:
        parser.error('--artifact-dir requires --manifest')
    try:
        version = release_version(args.repo_root, args.tag)
        if args.manifest is None:
            print(f'Validated {args.tag}: five package versions (metadata only; no assets checked)')
        else:
            count = validate_manifest(load_manifest(args.manifest), args.tag, version,
                                      args.platform or tuple(ASSET_SUFFIXES), args.artifact_dir)
            scope = 'bytes and sidecars checked' if args.artifact_dir else 'metadata only; no bytes checked'
            print(f'Validated {args.tag}: {count} assets ({scope})')
    except ValidationError as error:
        print(f'Release validation failed: {error}', file=sys.stderr)
        return 65
    return 0


if __name__ == '__main__':
    sys.exit(main())
