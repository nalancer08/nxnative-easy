"""Run the actual game settings reader against a synthetic app/preferences domain."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]
@unittest.skipUnless(sys.platform=='darwin','SwiftUI options')
class Options(unittest.TestCase):
    def test_settings_contract(self):
        with tempfile.TemporaryDirectory() as temp:
            output=Path(temp)/'options'
            subprocess.run(['xcrun','swiftc','-parse-as-library','-swift-version','5',str(ROOT/'desktop/NxNativeEasy/DesignSystem.swift'),str(ROOT/'desktop/NxNativeEasy/GameLaunchOptions.swift'),str(ROOT/'desktop/NxNativeEasy/tests/launch_options_check.swift'),'-o',str(output)],check=True)
            subprocess.run([str(output)],check=True,timeout=15)
