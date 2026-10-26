"""Run the same language preference and text model used by the desktop app."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]

@unittest.skipUnless(sys.platform=='darwin','requires Swift Foundation')
class DesktopLocalization(unittest.TestCase):
    def test_language_model(self):
        with tempfile.TemporaryDirectory() as tmp:
            exe=Path(tmp)/'languages'
            subprocess.run(['xcrun','swiftc',str(ROOT/'desktop/NxNativeEasy/Localization.swift'),
                            str(ROOT/'desktop/NxNativeEasy/tests/localization_check.swift'),'-o',str(exe)],check=True)
            subprocess.run([str(exe)],check=True)
