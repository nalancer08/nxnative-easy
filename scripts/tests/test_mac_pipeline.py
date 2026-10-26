"""Check destination isolation and successful Mac output discovery without a game."""
import json
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
