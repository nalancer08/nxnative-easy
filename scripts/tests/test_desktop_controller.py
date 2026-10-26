"""Exercise live GameController profiles and notification refresh with snapshot devices."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]

@unittest.skipUnless(sys.platform=='darwin','requires Apple GameController')
class DesktopController(unittest.TestCase):
    def test_controller_lifecycle(self):
        with tempfile.TemporaryDirectory() as tmp:
            executable=Path(tmp)/'controllers'
            subprocess.run(['xcrun','swiftc','-parse-as-library','-swift-version','5',
                str(ROOT/'desktop/NxNativeEasy/ControllerMonitor.swift'),
                str(ROOT/'desktop/NxNativeEasy/tests/controller_check.swift'),
                '-framework','AppKit','-framework','GameController','-o',str(executable)],check=True)
            subprocess.run([str(executable)],check=True)

    def test_live_input_and_release(self):
        with tempfile.TemporaryDirectory() as tmp:
            executable=Path(tmp)/'input'
            subprocess.run(['xcrun','swiftc','-parse-as-library','-swift-version','5',
                str(ROOT/'desktop/NxNativeEasy/ControllerMonitor.swift'),
                str(ROOT/'desktop/NxNativeEasy/ControllerTest.swift'),
                str(ROOT/'desktop/NxNativeEasy/tests/controller_input_check.swift'),
                '-framework','SwiftUI','-framework','AppKit','-framework','GameController','-o',str(executable)],check=True)
            subprocess.run([str(executable)],check=True)
