"""Compile the actual desktop progress/update model, without an app or game."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]

@unittest.skipUnless(sys.platform=='darwin','Swift Foundation model')
class BuildActivity(unittest.TestCase):
    def test_native_model(self):
        with tempfile.TemporaryDirectory() as temporary:
            executable=Path(temporary)/'activity'
            subprocess.run(['xcrun','swiftc',str(ROOT/'desktop/NxNativeEasy/BuildActivity.swift'),str(ROOT/'desktop/NxNativeEasy/tests/build_activity_check.swift'),'-o',str(executable)],check=True)
            subprocess.run([str(executable)],check=True)
