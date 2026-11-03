"""Evidence-based recommendations do not treat a new launcher as a game update."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[2]

@unittest.skipUnless(sys.platform == 'darwin', 'Swift Foundation policy')
class GameHealth(unittest.TestCase):
    def test_expiry_versions_and_missing_history(self):
        with tempfile.TemporaryDirectory() as folder:
            check = Path(folder) / 'check.swift'
            check.write_text('''import Foundation
@main struct Check {
 static func main() throws {
  let now=Date(timeIntervalSince1970:1000000)
  func require(_ value:Bool) throws {if !value {throw NSError(domain:"Game health",code:1)}}
  try require(GameCareEvidence().state(now:now) == .notInstalled)
  try require(GameCareEvidence(installed:true,rebuild:nil).state(now:now) == .unknown)
  try require(GameCareEvidence(installed:true,rebuild:false).state(now:now) == .current)
  try require(GameCareEvidence(installed:true,rebuild:true).state(now:now) == .rebuild)
  try require(GameCareEvidence(installed:true,installedVersion:"1",preparedVersion:"2",rebuild:false).state(now:now) == .contentUpdate)
  try require(GameCareEvidence(installed:true,expires:now,rebuild:true).state(now:now) == .expired)
  try require(GameCareEvidence(installed:true,expires:now.addingTimeInterval(48*3600),rebuild:false).state(now:now) == .expiring)
  try require(GameCareEvidence(installed:true,rebuild:false,preparedRevision:"a",installedRevision:"b").state(now:now) == .current)
  let root=URL(fileURLWithPath:CommandLine.arguments[1])
  try require(EasyBuildStamp.prepared(folder:root,target:"ios")==nil)
  let record:[String:Any]=["easy_version":"1.20.0","easy_build":33,"light_ipa":"/fake/old.ipa","source_revision":String(repeating:"a",count:40)]
  try JSONSerialization.data(withJSONObject:record).write(to:root.appendingPathComponent("nxnative-ios.json"))
  try require(EasyBuildStamp.prepared(folder:root,target:"ios",ipa:URL(fileURLWithPath:"/fake/new.ipa"))==nil)
  try require(EasyBuildStamp.prepared(folder:root,target:"ios",ipa:URL(fileURLWithPath:"/fake/old.ipa"))?.build==33)
  print("Game health PASS: expiry priority, content differences, no launcher-only update, missing history and exact IPA association")
 }
}''')
            exe = Path(folder) / 'health'
            subprocess.run(['xcrun','swiftc','-parse-as-library', str(ROOT/'desktop/NxNativeEasy/GameHealth.swift'),str(check),'-o',str(exe)],check=True)
            subprocess.run([str(exe),folder],check=True,timeout=15)
