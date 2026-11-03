"""Exercise the real pre-game model with a file-free fake native backend."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[3]
TESTS = Path(__file__).resolve().parent


@unittest.skipUnless(sys.platform == 'darwin' and shutil.which('xcrun'), 'needs macOS Swift')
class AutomaticContinuityTests(unittest.TestCase):
    def test_delivery_conflict_lifecycle_and_play(self):
        with tempfile.TemporaryDirectory(prefix='nxe-auto-cloud-') as folder:
            root = Path(folder)
            obj, exe = root / 'backend.o', root / 'check'
            subprocess.run(['xcrun', 'clang', '-Wall', '-Werror', '-c',
                            str(TESTS / 'cloud_automatic_backend.c'), '-o', str(obj)], check=True, capture_output=True)
            built = subprocess.run(['xcrun', '-sdk', 'macosx', 'swiftc', '-swift-version', '5',
                                    '-parse-as-library', '-module-cache-path', str(root / 'modules'),
                                    str(REPO / 'dm/ios/Sources/CloudSavePanel.swift'),
                                    str(TESTS / 'cloud_automatic_check.swift'), str(obj), '-o', str(exe)],
                                   capture_output=True, text=True, timeout=180)
            self.assertEqual(built.returncode, 0, built.stdout + built.stderr)
            ran = subprocess.run([str(exe)], capture_output=True, text=True, timeout=20)
            self.assertEqual(ran.returncode, 0, ran.stdout + ran.stderr)
            self.assertIn('play guards passed', ran.stdout)


if __name__ == '__main__':
    unittest.main()
