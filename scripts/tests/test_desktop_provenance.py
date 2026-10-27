"""Real local Git history and private metadata fixtures; no game builds/devices."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]

@unittest.skipUnless(sys.platform=='darwin','Swift Foundation model')
class DesktopProvenance(unittest.TestCase):
    def test_history_metadata_and_redacted_diagnostics(self):
        with tempfile.TemporaryDirectory() as temporary:
            executable=Path(temporary)/'provenance'
            subprocess.run(['xcrun','swiftc','-parse-as-library','-swift-version','5',
                str(ROOT/'desktop/NxNativeEasy/BuildActivity.swift'),str(ROOT/'desktop/NxNativeEasy/GameLibrary.swift'),
                str(ROOT/'desktop/NxNativeEasy/tests/provenance_check.swift'),'-o',str(executable)],check=True)
            subprocess.run([str(executable)],check=True,timeout=20)
