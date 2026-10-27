"""Exercise the actual Foundation profile storage used by the iOS controls editor."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

@unittest.skipUnless(sys.platform=='darwin','requires Apple Foundation')
class PadProfiles(unittest.TestCase):
    def test_runtime_storage(self):
        with tempfile.TemporaryDirectory() as temporary:
            exe=Path(temporary)/'profiles'
            subprocess.run(['clang','-fobjc-arc','-Wall','-Wextra','-Werror',str(Path(__file__).with_name('pad_profiles_check.m')),
                            '-framework','Foundation','-framework','CoreGraphics','-o',str(exe)],check=True)
            subprocess.run([str(exe)],check=True)
