"""Observe synthetic committed save metadata without cloud, accounts or devices."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(sys.platform == 'darwin', 'native macOS observer')
class LocalSaveTests(unittest.TestCase):
    def test_first_save_and_later_changes_without_cloud(self):
        with tempfile.TemporaryDirectory(prefix='nxe-local-save-') as temporary:
            executable = Path(temporary) / 'check'
            source = ROOT / 'desktop/NxNativeEasy'
            built = subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-swift-version', '5',
                                    str(source / 'LocalSaveMonitor.swift'), str(source / 'SavesHelp.swift'),
                                    str(source / 'DesignSystem.swift'),
                                    str(source / 'Localization.swift'), str(source / 'tests/local_save_check.swift'),
                                    '-o', str(executable)], capture_output=True, text=True, timeout=120)
            self.assertEqual(built.returncode, 0, built.stdout + built.stderr)
            ran = subprocess.run([str(executable)], capture_output=True, text=True, timeout=10)
            self.assertEqual(ran.returncode, 0, ran.stdout + ran.stderr)
            self.assertIn('original bytes preserved', ran.stdout)
