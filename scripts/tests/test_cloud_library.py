"""Exercise library continuity against temporary metadata and read-only fake helpers."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(sys.platform == 'darwin', 'native macOS library')
class CloudLibraryTests(unittest.TestCase):
    def test_library_monitoring_and_cloud_account_isolation(self):
        with tempfile.TemporaryDirectory(prefix='nxe-library-') as temporary:
            folder = Path(temporary)
            source, executable = folder / 'BuildModel.swift', folder / 'check'
            source.write_text((ROOT / 'desktop/NxNativeEasy/main.swift').read_text()
                              .split('@main struct NxNativeEasyApp: App {')[0])
            files = sorted(str(p) for p in (ROOT / 'desktop/NxNativeEasy').glob('*.swift')
                           if p.name != 'main.swift')
            built = subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-swift-version', '5',
                                    str(source), *files,
                                    str(ROOT / 'desktop/NxNativeEasy/tests/cloud_library_check.swift'),
                                    '-o', str(executable), '-framework', 'SwiftUI', '-framework',
                                    'AppKit', '-framework', 'GameController', '-framework', 'WebKit'],
                                   capture_output=True, text=True, timeout=240)
            self.assertEqual(built.returncode, 0, built.stdout + built.stderr)
            ran = subprocess.run([str(executable)], capture_output=True, text=True, timeout=30)
            self.assertEqual(ran.returncode, 0, ran.stdout + ran.stderr)
            self.assertIn('scoped device monitoring and title guards passed', ran.stdout)
