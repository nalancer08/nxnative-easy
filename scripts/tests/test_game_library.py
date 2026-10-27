"""Exercise the real local library store with synthetic folders; never launch a game."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]

@unittest.skipUnless(sys.platform=='darwin','Swift Foundation model')
class GameLibrary(unittest.TestCase):
    def test_persistence_outputs_and_non_destructive_removal(self):
        with tempfile.TemporaryDirectory() as temporary:
            executable=Path(temporary)/'library'
            subprocess.run(['xcrun','swiftc','-parse-as-library','-swift-version','5',
                str(ROOT/'desktop/NxNativeEasy/BuildActivity.swift'),str(ROOT/'desktop/NxNativeEasy/GameLibrary.swift'),
                str(ROOT/'desktop/NxNativeEasy/tests/library_check.swift'),'-o',str(executable)],check=True)
            subprocess.run([str(executable)],check=True,timeout=20)
