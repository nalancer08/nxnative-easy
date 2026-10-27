"""Native client IPC uses only a synthetic process; no Apple account, Keychain or device."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]

@unittest.skipUnless(sys.platform=='darwin','native macOS client')
class SideloadClient(unittest.TestCase):
    def test_protocol_policy_and_save_locations(self):
        with tempfile.TemporaryDirectory() as temporary:
            executable=Path(temporary)/'client'
            subprocess.run(['xcrun','swiftc','-parse-as-library','-swift-version','5',
                str(ROOT/'desktop/NxNativeEasy/BuildActivity.swift'),str(ROOT/'desktop/NxNativeEasy/Sideloading.swift'),
                str(ROOT/'desktop/NxNativeEasy/SavesHelp.swift'),str(ROOT/'desktop/NxNativeEasy/Localization.swift'),
                str(ROOT/'desktop/NxNativeEasy/tests/sideload_check.swift'),'-o',str(executable)],check=True)
            subprocess.run([str(executable)],check=True,timeout=20)
