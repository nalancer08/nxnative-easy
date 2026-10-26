"""Exercise the wrapper and archive splitter with synthetic packages, never game data."""
import importlib.util
import json
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

SCRIPTS=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(SCRIPTS))
import build_ios
import split_ipa


def fixture(path,bundle='org.nxnative.test',extra=None):
    with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_DEFLATED) as z:
        z.writestr('Payload/Test.app/Info.plist',plistlib.dumps(dict(CFBundleIdentifier=bundle,
            CFBundleExecutable='Game',CFBundleShortVersionString='1.0')))
        for name,data in {'Game':b'executable','dm/profile':b'profile','msl/shader':b'library',
                          'romfs/data/test':b'game bytes'}.items(): z.writestr('Payload/Test.app/'+name,data)
        for name,data in (extra or {}).items():z.writestr(name,data)


class Pipeline(unittest.TestCase):
    def test_split_and_preserve_source(self):
        with tempfile.TemporaryDirectory() as temp:
            original=Path(temp)/'example.ipa';fixture(original)
            before=original.read_bytes();out=split_ipa.split_ipa(original)
            self.assertEqual(before,original.read_bytes())
            self.assertEqual((out/'romfs/data/test').read_bytes(),b'game bytes')
            with zipfile.ZipFile(next(out.glob('*.ipa'))) as z:
                self.assertIsNone(z.testzip());self.assertFalse(any('/romfs/' in n for n in z.namelist()))
                self.assertEqual(z.read('Payload/Test.app/Game'),b'executable')
                self.assertTrue(plistlib.loads(z.read('Payload/Test.app/Info.plist'))['UIFileSharingEnabled'])

    def test_reject_unsafe_archive_without_outputs(self):
        for name in ['../escape','Payload/Test.app/prod.keys','Payload/Test.app/title.keys']:
            with self.subTest(path=name),tempfile.TemporaryDirectory() as temp:
                original=Path(temp)/'example.ipa';fixture(original,extra={name:b'reject'})
                with self.assertRaises(ValueError):split_ipa.split_ipa(original)
                self.assertEqual(list(Path(temp).iterdir()),[original])

    def test_failed_export_cleans_only_its_output(self):
        with tempfile.TemporaryDirectory() as temp:
            original=Path(temp)/'example.ipa';fixture(original);before=original.read_bytes()
            with patch.object(split_ipa.shutil,'copyfileobj',side_effect=OSError('test disk failure')):
                with self.assertRaises(OSError):split_ipa.split_ipa(original)
            self.assertEqual(original.read_bytes(),before)
            self.assertEqual(list(Path(temp).iterdir()),[original])

    def test_reject_signed_build(self):
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp)/'signed.ipa';fixture(p,extra={'Payload/Test.app/_CodeSignature/CodeResources':b'signed'})
            with self.assertRaises(ValueError):build_ios.verify_ipa(p)

    def test_pipeline_persists_identity_and_emits_lightweight(self):
        with tempfile.TemporaryDirectory() as temp:
            game=Path(temp);(game/'base.nsp').write_bytes(b'fixture');(game/'prod.keys').write_bytes(b'test-only')
            calls=[]
            class Builder:
                def cli(self,args):
                    calls.append(args);fixture(Path(args[args.index('-o')+1]));return 0
            with patch.object(build_ios,'load_builder',return_value=Builder()):
                self.assertEqual(build_ios.main([temp]),0)
                state=json.loads((game/'nxnative-ios.json').read_text())
                self.assertEqual(state['bundle_id'],'org.nxnative.test')
                self.assertTrue(list(Path(state['light_dir']).glob('*.ipa')))
                self.assertEqual(build_ios.main([temp,'--dry-run']),0)
                self.assertEqual(len(calls),1)
                with self.assertRaises(ValueError):build_ios.main([temp,'--bundle-id','changed','--dry-run'])
            self.assertEqual(calls[0][calls[0].index('--team-id')+1],'0000000000')

    def test_parallel_build_is_rejected(self):
        with build_ios.build_lock():
            with self.assertRaises(ValueError):
                with build_ios.build_lock(): pass

    def test_dry_run_never_loads_builder_or_keys(self):
        with tempfile.TemporaryDirectory() as temp:
            game=Path(temp);(game/'base.nsp').write_bytes(b'fixture')
            with patch.object(build_ios,'load_builder',side_effect=AssertionError('unexpected build')):
                self.assertEqual(build_ios.main([temp,'--dry-run']),0)
            self.assertEqual(len(list(game.iterdir())),1)


if __name__=='__main__':unittest.main()
