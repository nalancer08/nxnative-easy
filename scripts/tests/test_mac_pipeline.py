"""Check destination isolation and successful Mac output discovery without a game."""
import json
import plistlib
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import build_mac

class MacPipeline(unittest.TestCase):
    def test_mac_build_uses_adhoc_and_preserves_ios_state(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);(root/'base.nsp').write_bytes(b'synthetic')
            (root/'prod.keys').write_bytes(b'synthetic')
            (root/'nxnative-ios.json').write_text('{"existing":"preserve"}')
            calls=[]
            class Builder:
                def cli(self,args):
                    calls.append(args)
                    host=Path(args[args.index('-o')+1])/'Contents/MacOS/dmhost'
                    host.parent.mkdir(parents=True);host.write_bytes(b'synthetic')
                    (host.parents[1]/'Resources/romfs').mkdir(parents=True)
                    (host.parents[1]/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'org.nxnative.test','DMTitleID':'010093801237C000','CFBundleShortVersionString':'1.0'}))
                    return 0
            with patch.object(build_mac,'load_builder',return_value=Builder()),patch.object(build_mac.platform,'machine',return_value='arm64'):
                self.assertEqual(build_mac.main([temp,'--keys-folder',temp]),0)
            self.assertEqual(calls[0][calls[0].index('--platform')+1],'mac-app')
            self.assertEqual(calls[0][calls[0].index('--mac-sign')+1],'-')
            self.assertTrue(Path(json.loads((root/'nxnative-mac.json').read_text())['app_path']).is_dir())
            self.assertEqual((root/'nxnative-ios.json').read_text(),'{"existing":"preserve"}')

    def test_failure_leaves_previous_mac_record(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);(root/'base.nsp').write_bytes(b'synthetic');(root/'prod.keys').write_bytes(b'synthetic')
            (root/'nxnative-mac.json').write_text('{"app_path":"old"}')
            class Builder:
                def cli(self,args):return 1
            with patch.object(build_mac,'load_builder',return_value=Builder()),patch.object(build_mac.platform,'machine',return_value='arm64'):
                self.assertEqual(build_mac.main([temp,'--keys-folder',temp]),1)
            self.assertEqual((root/'nxnative-mac.json').read_text(),'{"app_path":"old"}')

    def test_incomplete_app_does_not_replace_previous_record(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);(root/'base.nsp').write_bytes(b'synthetic');(root/'prod.keys').write_bytes(b'synthetic')
            (root/'nxnative-mac.json').write_text('{"app_path":"old"}')
            class Builder:
                def cli(self,args):
                    host=Path(args[args.index('-o')+1])/'Contents/MacOS/dmhost'
                    host.parent.mkdir(parents=True);host.write_bytes(b'synthetic')
                    return 0
            with patch.object(build_mac,'load_builder',return_value=Builder()),patch.object(build_mac.platform,'machine',return_value='arm64'):
                with self.assertRaisesRegex(ValueError,'embedded game data required'):
                    build_mac.main([temp,'--keys-folder',temp])
            self.assertEqual((root/'nxnative-mac.json').read_text(),'{"app_path":"old"}')

    def test_update_preserves_identity_and_records_new_version(self):
        self.check_update('org.nxnative.custom',False)

    def test_identity_mismatch_keeps_previous_record(self):
        self.check_update('org.nxnative.changed',True)

    def check_update(self,bundle,fail):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);(root/'base.nsp').write_bytes(b'synthetic');(root/'prod.keys').write_bytes(b'synthetic')
            previous={'schema':1,'app_path':str(root/'old.app'),'bundle_id':'org.nxnative.custom','title_id':'010093801237C000','version':'1.0'}
            state=root/'nxnative-mac.json';state.write_text(json.dumps(previous));before=state.read_text();calls=[]
            class Builder:
                def cli(self,args):
                    calls.append(args);out=Path(args[args.index('-o')+1]);host=out/'Contents/MacOS/dmhost'
                    host.parent.mkdir(parents=True);host.write_bytes(b'fixture');(out/'Contents/Resources/romfs').mkdir(parents=True)
                    (out/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':bundle,'DMTitleID':'010093801237C000','CFBundleShortVersionString':'2.0'}))
                    return 0
            with patch.object(build_mac,'load_builder',return_value=Builder()),patch.object(build_mac.platform,'machine',return_value='arm64'):
                if fail:
                    with self.assertRaisesRegex(ValueError,'identity changed'):build_mac.main([temporary,'--keys-folder',temporary])
                    self.assertEqual(state.read_text(),before)
                else:
                    self.assertEqual(build_mac.main([temporary,'--keys-folder',temporary]),0)
                    self.assertEqual(json.loads(state.read_text())['version'],'2.0')
            self.assertEqual(calls[0][calls[0].index('--bundle-id')+1],'org.nxnative.custom')
