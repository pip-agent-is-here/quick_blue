"""Offline generator primitives; the real-build manifest is verified separately."""
import hashlib
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('capture', Path(__file__).with_name('capture-build-inputs.py'))
assert spec is not None and spec.loader is not None
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        self.git('config', 'user.name', 'Test')
        self.git('config', 'user.email', 'test@example.invalid')
        (self.root / 'source').write_text('original')
        (self.root / '.gitignore').write_text('ignored\n')
        self.git('add', '.')
        self.git('commit', '-qm', 'baseline')

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.root).decode().strip()

    def test_hash_reads_actual_bytes(self):
        self.assertEqual(capture.digest(self.root / 'source'), hashlib.sha256(b'original').hexdigest())

    def test_modified_and_untracked_inputs_are_not_clean_commit(self):
        (self.root / 'source').write_text('modified')
        (self.root / 'new').write_text('untracked')
        snapshot = capture.source_snapshot(self.root)
        self.assertEqual(snapshot['head'], self.git('rev-parse', 'HEAD'))
        self.assertIn(' M source', snapshot['status'])
        self.assertIn('?? new', snapshot['status'])
        files = {entry['path']: entry for entry in snapshot['files']}
        self.assertEqual(files['source']['sha256'], hashlib.sha256(b'modified').hexdigest())
        self.assertIn('new', files)

    def test_deleted_inputs_recorded(self):
        (self.root / 'source').unlink()
        self.assertIn({'path': 'source', 'missing': True}, capture.source_snapshot(self.root)['files'])

    def test_symlinks_record_target_and_ignored_outputs_excluded(self):
        os.symlink('source', self.root / 'link')
        (self.root / 'ignored').write_text('build output')
        files = capture.source_snapshot(self.root)['files']
        self.assertIn({'path': 'link', 'symlink': 'source'}, files)
        self.assertNotIn('ignored', [entry['path'] for entry in files])

    def test_failed_command_is_not_success(self):
        with self.assertRaises(subprocess.CalledProcessError):
            capture.run(['git', 'not-a-command'], self.root)


if __name__ == '__main__':
    unittest.main()
