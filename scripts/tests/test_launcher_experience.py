"""Check update discovery with synthetic public-release responses, never update a real app."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(sys.platform == 'darwin', 'native macOS experience')
class LauncherExperienceTests(unittest.TestCase):
    def test_published_release_discovery(self):
        with tempfile.TemporaryDirectory(prefix='nxe-experience-') as temporary:
            folder = Path(temporary)
            model = folder / 'BuildModel.swift'
            model.write_text((ROOT / 'desktop/NxNativeEasy/main.swift').read_text()
                             .split('@main struct NxNativeEasyApp: App {')[0])
            files = sorted(str(p) for p in (ROOT / 'desktop/NxNativeEasy').glob('*.swift')
                           if p.name != 'main.swift')
            executable = folder / 'check'
            built = subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-swift-version', '5',
                                    str(model), *files,
                                    str(ROOT / 'desktop/NxNativeEasy/tests/launcher_experience_check.swift'),
                                    '-o', str(executable), '-framework', 'SwiftUI', '-framework',
                                    'AppKit', '-framework', 'GameController', '-framework', 'WebKit'],
                                   capture_output=True, text=True, timeout=240)
            self.assertEqual(built.returncode, 0, built.stdout + built.stderr)
            result = subprocess.run([str(executable)], capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('published update channel', result.stdout)
