"""Run the same Foundation preference and geometry helpers used by the gamepad."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


@unittest.skipUnless(sys.platform == 'darwin', 'requires Apple Foundation')
class PadGeometryTests(unittest.TestCase):
    def test_runtime_geometry_and_preferences(self):
        with tempfile.TemporaryDirectory() as tmp:
            executable = str(Path(tmp) / 'pad-check')
            source = Path(__file__).with_name('pad_geometry_check.m')
            subprocess.run(['clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror',
                            str(source), '-framework', 'Foundation', '-framework',
                            'CoreGraphics', '-o', executable], check=True)
            subprocess.run([executable], check=True)


if __name__ == '__main__':
    unittest.main()
