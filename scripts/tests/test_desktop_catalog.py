"""Execute the live catalog parser/search model used by the desktop UI."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]

@unittest.skipUnless(sys.platform=='darwin','requires Swift Foundation')
class DesktopCatalog(unittest.TestCase):
    def test_profile_discovery_and_search(self):
        with tempfile.TemporaryDirectory() as tmp:
            exe=Path(tmp)/'catalog'
            subprocess.run(['xcrun','swiftc',str(ROOT/'desktop/NxNativeEasy/GameCatalog.swift'),
                            str(ROOT/'desktop/NxNativeEasy/tests/catalog_check.swift'),'-o',str(exe)],check=True)
            subprocess.run([str(exe),str(ROOT)],check=True)
