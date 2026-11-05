"""Check interaction invariants without sending OS input or touching user data."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(sys.platform == 'darwin', 'native macOS controls')
class DesktopInteractionTests(unittest.TestCase):
    def test_controls_contrast_and_retained_page(self):
        with tempfile.TemporaryDirectory(prefix='nxe-ui-audit-') as temporary:
            folder = Path(temporary)
            for source in (ROOT / 'desktop/NxNativeEasy').glob('*.swift'):
                if source.name == 'main.swift':
                    (folder / 'MainModel.swift').write_text(source.read_text().split('@main struct NxNativeEasyApp: App {')[0])
                else:
                    shutil.copyfile(source, folder / source.name)
            check = ROOT / 'desktop/NxNativeEasy/tests/ui_interaction_check.swift'
            executable = folder / 'check'
            built = subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-swift-version', '5',
                                    *(str(p) for p in sorted(folder.glob('*.swift'))), str(check),
                                    '-o', str(executable), '-framework', 'SwiftUI', '-framework',
                                    'AppKit', '-framework', 'GameController', '-framework', 'WebKit'],
                                   capture_output=True, text=True, timeout=240)
            self.assertEqual(built.returncode, 0, built.stdout + built.stderr)
            ran = subprocess.run([str(executable)], capture_output=True, text=True, timeout=30)
            self.assertEqual(ran.returncode, 0, ran.stdout + ran.stderr)
            self.assertIn('Desktop interaction PASS', ran.stdout)
