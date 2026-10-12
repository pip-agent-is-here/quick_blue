"""Offline metadata/byte fixtures; no build, signing or publication proof."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('validate-release.py')
PACKAGES = ('quick_blue_platform_interface', 'quick_blue_darwin', 'quick_blue_linux', 'quick_blue_windows', 'quick_blue')
SUFFIXES = ('android.apk', 'ios-simulator.zip', 'macos.zip', 'linux-x64.tar.gz', 'windows-x64.zip')


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for package in PACKAGES:
            (self.root / package).mkdir()
            (self.root / package / 'pubspec.yaml').write_text('version: 1.2.3\n')
        self.manifest = {'schema_version': 1, 'release_tag': 'v1.2.3', 'package_version': '1.2.3',
                         'assets': [{'name': 'quick_blue-example-v1.2.3-' + suffix,
                                     'sha256': hashlib.sha256(suffix.encode()).hexdigest()} for suffix in SUFFIXES]}

    def run_validator(self, manifest=None, *args, tag='v1.2.3'):
        path = self.root / 'manifest.json'
        path.write_text(json.dumps(self.manifest if manifest is None else manifest))
        return subprocess.run([sys.executable, str(SCRIPT), '--repo-root', str(self.root),
                               '--tag', tag, '--manifest', str(path), *args], capture_output=True, text=True)

    def reject(self, manifest=None, *args, tag='v1.2.3', message):
        result = self.run_validator(manifest, *args, tag=tag)
        self.assertEqual(result.returncode, 65, result.stdout + result.stderr)
        self.assertIn(message, result.stderr)

    def test_full_positive(self):
        result = self.run_validator()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('5 assets', result.stdout)

    def test_partial_requires_explicit_selection(self):
        self.manifest['assets'] = self.manifest['assets'][3:4]
        self.reject(message='missing assets')
        result = self.run_validator(None, '--platform', 'linux')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_tag_rules(self):
        for tag in ('1.2.3', 'v1.2', 'v1.2.3+build', 'v1.2.3\n', 'v1.2.3/evil', 'v1.2.3-', ''):
            with self.subTest(tag=tag):
                self.reject(tag=tag, message='malformed release tag')
        self.reject(tag='v9.0.0', message='does not match package version')

    def test_existing_prerelease_and_dot_tag_rule(self):
        for version in ('1.2.3-beta.1', '1.2.3.preview'):
            tag = 'v' + version
            for package in PACKAGES:
                (self.root / package / 'pubspec.yaml').write_text('version: ' + version + '\n')
            # Dot suffix is accepted by the workflow but not the package script.
            manifest = copy.deepcopy(self.manifest)
            manifest['release_tag'] = tag
            manifest['package_version'] = version
            for asset in manifest['assets']:
                asset['name'] = asset['name'].replace('v1.2.3', tag)
            result = self.run_validator(manifest, tag=tag)
            self.assertEqual(result.returncode, 0 if '-' in version else 65, result.stderr)

    def test_package_versions(self):
        for package in PACKAGES:
            path = self.root / package / 'pubspec.yaml'
            for value in ('version: 9.0.0\n', 'version: bad\n', '', 'version: 1.2.3\nversion: 1.2.3\n'):
                with self.subTest(package=package, value=value):
                    path.write_text(value)
                    self.reject(message=package)
            path.write_text('version: 1.2.3\n')

    def test_manifest_identity(self):
        for key, value, message in (('schema_version', True, 'schema_version'), ('schema_version', 2, 'schema_version'),
                                    ('release_tag', 'v9.0.0', 'release_tag'), ('package_version', '9.0.0', 'package_version')):
            manifest = copy.deepcopy(self.manifest)
            manifest[key] = value
            self.reject(manifest, message=message)

    def test_missing_duplicate_unexpected_assets(self):
        manifest = copy.deepcopy(self.manifest)
        manifest['assets'].pop()
        self.reject(manifest, message='missing assets')
        manifest = copy.deepcopy(self.manifest)
        manifest['assets'].append(manifest['assets'][0])
        self.reject(manifest, message='duplicate asset')
        manifest = copy.deepcopy(self.manifest)
        manifest['assets'][0]['name'] = '../evil.apk'
        self.reject(manifest, message='unexpected asset')
        manifest['assets'][0]['name'] = 'quick_blue-example-v9.0.0-android.apk'
        self.reject(manifest, message='unexpected asset')

    def test_checksum_entries(self):
        for value in ('', 'a' * 63, 'g' * 64, 12, None, 'a' * 64 + '\n'):
            manifest = copy.deepcopy(self.manifest)
            manifest['assets'][0]['sha256'] = value
            self.reject(manifest, message='sha256')

    def test_wrong_shapes(self):
        for manifest in ([], {'assets': []}, dict(self.manifest, assets={}),
                         dict(self.manifest, assets=[None]), dict(self.manifest, assets=[{'name': 12}])):
            self.reject(manifest, message='invalid')

    def test_artifact_bytes_and_sidecars(self):
        for suffix, asset in zip(SUFFIXES, self.manifest['assets']):
            (self.root / asset['name']).write_bytes(suffix.encode())
            (self.root / (asset['name'] + '.sha256')).write_text(asset['sha256'] + '  ' + asset['name'] + '\n')
        result = self.run_validator(None, '--artifact-dir', str(self.root))
        self.assertEqual(result.returncode, 0, result.stderr)
        asset = self.manifest['assets'][0]
        path = self.root / asset['name']
        path.write_bytes(b'changed')
        self.reject(None, '--artifact-dir', str(self.root), message='checksum mismatch')
        path.write_bytes(SUFFIXES[0].encode())
        sidecar = self.root / (asset['name'] + '.sha256')
        for text in ('bad', asset['sha256'] + '  wrong.apk\n', '0' * 64 + '  ' + asset['name'] + '\n',
                     asset['sha256'] + '  ' + asset['name'] + '\nextra\n'):
            sidecar.write_text(text)
            self.reject(None, '--artifact-dir', str(self.root), message='sidecar')
        sidecar.unlink()
        self.reject(None, '--artifact-dir', str(self.root), message='cannot read')
        path.unlink()
        self.reject(None, '--artifact-dir', str(self.root), message='cannot read')

    def test_json_duplicate_keys_and_invalid_json(self):
        path = self.root / 'bad.json'
        for text in ('{"schema_version":1,"schema_version":1}', '{bad', 'null'):
            path.write_text(text)
            result = subprocess.run([sys.executable, str(SCRIPT), '--repo-root', str(self.root), '--tag', 'v1.2.3',
                                     '--manifest', str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 65)
            self.assertIn('invalid', result.stderr)

    def test_metadata_only_cli(self):
        result = subprocess.run([sys.executable, str(SCRIPT), '--repo-root', str(self.root), '--tag', 'v1.2.3'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('metadata only', result.stdout)

    def test_workflow_artifact_contract(self):
        workflow = SCRIPT.parent.parent / '.github/workflows/example-release.yml'
        text = workflow.read_text()
        for suffix in SUFFIXES:
            with self.subTest(suffix=suffix):
                self.assertIn('-' + suffix, text)
        # Guard intentional preservation of the existing tag grammar.
        self.assertEqual(text.count('^v[0-9]+\\.[0-9]+\\.[0-9]+([.-][0-9A-Za-z.-]+)?$'), 5)

    def test_usage_and_missing_inputs(self):
        result = subprocess.run([sys.executable, str(SCRIPT), '--tag', 'v1.2.3', '--artifact-dir', str(self.root)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('requires --manifest', result.stderr)
        (self.root / PACKAGES[0] / 'pubspec.yaml').unlink()
        self.reject(message='cannot read')


if __name__ == '__main__':
    unittest.main()
