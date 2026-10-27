"""Drop/selection workflow tests run only against synthetic local files."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]

@unittest.skipUnless(sys.platform=='darwin','SwiftUI workflow')
class DesktopWorkflow(unittest.TestCase):
    def test_drop_boundaries_and_original_preservation(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary);source=folder/'BuildModel.swift';executable=folder/'workflow'
            source.write_text((ROOT/'desktop/NxNativeEasy/main.swift').read_text().split('@main struct NxNativeEasyApp: App {')[0])
            files=sorted(str(p) for p in (ROOT/'desktop/NxNativeEasy').glob('*.swift') if p.name!='main.swift')
            subprocess.run(['xcrun','swiftc','-parse-as-library','-swift-version','5',str(source),*files,
                str(ROOT/'desktop/NxNativeEasy/tests/workflow_check.swift'),'-o',str(executable),
                '-framework','SwiftUI','-framework','AppKit','-framework','GameController'],check=True)
            subprocess.run([str(executable)],check=True,timeout=20)
