"""Transactional export/relocation tests with synthetic games and renewal records."""
import fcntl
import json
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import build_ios
import game_export as export
import organize_export


def ipa(path, payload=b'code'):
    info={'CFBundleIdentifier':'org.nxnative.test','CFBundleDisplayName':'Link: Adventure',
          'CFBundleExecutable':'Game','CFBundleShortVersionString':'1.1.0'}
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as z:
        z.writestr('Payload/Game.app/Info.plist',plistlib.dumps(info))
        for n,v in {'Game':payload,'dm/profile':b'profile','msl/shader':b'shader','romfs/data/world':b'original game data'}.items():
            z.writestr('Payload/Game.app/'+n,v)


class Exports(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name).resolve();self.game=self.root/'Originals';self.game.mkdir()
        (self.game/'base.nsp').write_bytes(b'original');(self.game/'prod.keys').write_bytes(b'fixture')
        self.parent=self.root/'My games';self.jobs=self.root/'settings/refresh-jobs.json'
        self.jobs.parent.mkdir();self.jobs.write_text('[]')
        self.count=0

    def build(self, payload=b'code', fail=False):
        owner=self
        class Builder:
            def cli(self,args):
                owner.count+=1
                if fail:raise OSError('synthetic build failure')
                ipa(Path(args[args.index('-o')+1]),payload);return 0
        real_publish=export.publish
        def publish(*a,**k):return real_publish(*a,**k,jobs_path=self.jobs)
        with patch.object(build_ios,'load_builder',return_value=Builder()),patch.object(export,'publish',side_effect=publish):
            return build_ios.main([str(self.game),'--keys-folder',str(self.game),'--export-dir',str(self.parent)])

    def record(self):return json.loads((self.game/'nxnative-ios.json').read_text())

    def test_named_layout_one_ipa_and_no_full_duplicate(self):
        self.build();r=self.record();folder=Path(r['export_folder'])
        self.assertEqual(folder,self.parent/'Link - Adventure/iPhone - iPad')
        self.assertEqual({x.name for x in folder.iterdir()},{'Link - Adventure.ipa','Datos',export.MARKER})
        self.assertTrue(Path(r['romfs_path']).is_dir());self.assertIsNone(r['full_ipa'])
        self.assertEqual(len(list(self.parent.rglob('*.ipa'))),1)
        self.assertEqual((self.game/'base.nsp').read_bytes(),b'original')
        self.assertFalse(list(self.parent.glob('**/*preparing*')))
        self.assertFalse((self.parent/'Originals').exists())

    def test_rebuild_replaces_single_export_and_failure_preserves_it(self):
        self.build();r=self.record();p=Path(r['light_ipa']);old=p.read_bytes()
        with self.assertRaises(OSError):self.build(fail=True)
        self.assertEqual(p.read_bytes(),old);self.assertEqual(self.record(),r)
        self.build(b'updated');self.assertNotEqual(p.read_bytes(),old)
        self.assertEqual(len(list(self.parent.rglob('*.ipa'))),1)

    def test_existing_renewal_keeps_exact_previous_package_and_identity(self):
        self.build();p=Path(self.record()['light_ipa']);h=export.digest(p)
        before={'id':'phone:org.game','ipa':str(p),'sha256':h,'effectiveID':'same.team','team':'same','account':'independent','enabled':True,'gameFolder':str(self.game)}
        self.jobs.write_text(json.dumps([before]));self.build(b'new engine')
        after=json.loads(self.jobs.read_text())[0]
        self.assertEqual({k:v for k,v in before.items() if k!='ipa'},{k:v for k,v in after.items() if k!='ipa'})
        self.assertEqual(export.digest(Path(after['ipa'])),h);self.assertIn('/.renewal/',after['ipa'])
        self.assertNotEqual(export.digest(p),h)

    def test_unmanaged_destination_is_not_overwritten(self):
        p=self.parent/'Link - Adventure/iPhone - iPad';p.mkdir(parents=True);(p/'notes.txt').write_text('keep')
        with self.assertRaisesRegex(ValueError,'already contains files'):self.build()
        self.assertEqual((p/'notes.txt').read_text(),'keep');self.assertFalse((self.game/'nxnative-ios.json').exists())

    def test_modified_export_and_empty_save_folder_are_preserved(self):
        self.build();p=Path(self.record()['export_folder']);(p/'save').mkdir()
        with self.assertRaisesRegex(ValueError,'added or changed'):self.build(b'new')
        self.assertTrue((p/'save').is_dir())

    def test_nested_metadata_named_file_is_still_user_content(self):
        self.build();p=Path(self.record()['romfs_path'])/export.MARKER;p.write_text('keep my file')
        with self.assertRaisesRegex(ValueError,'added or changed'):self.build(b'new')
        self.assertEqual(p.read_text(),'keep my file')

    def test_state_write_failure_rolls_back_atomic_swap(self):
        self.build();r=self.record();old=Path(r['light_ipa']).read_bytes();before=(self.game/'nxnative-ios.json').read_bytes()
        original=export.atomic_json
        def fail_state(p,v):
            if Path(p)==self.game/'nxnative-ios.json':raise OSError('disk full')
            return original(p,v)
        with patch.object(export,'atomic_json',side_effect=fail_state),self.assertRaises(OSError):self.build(b'new')
        self.assertEqual(Path(r['light_ipa']).read_bytes(),old)
        self.assertEqual((self.game/'nxnative-ios.json').read_bytes(),before)

    def test_installer_lease_blocks_export_without_changes(self):
        self.build();r=self.record();old=Path(r['light_ipa']).read_bytes()
        with (self.jobs.parent/'installer.lock').open('a') as f:
            fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)
            with self.assertRaises(BlockingIOError):self.build(b'new')
        self.assertEqual(Path(r['light_ipa']).read_bytes(),old)

    def test_move_legacy_export_without_building_or_changing_renewal_package(self):
        # Turn a generated package into the shape used by old Easy versions.
        self.build();r=self.record();legacy=self.game/'old-unsigned-light-example';legacy.mkdir()
        p=Path(r['light_ipa']);p.rename(legacy/'old-unsigned.ipa')
        data=Path(r['romfs_path']);data.rename(legacy/'romfs')
        legacy_record=dict(r,light_ipa=str(legacy/'old-unsigned.ipa'),light_dir=str(legacy))
        for k in ['export_folder','export_parent','romfs_path']:legacy_record.pop(k,None)
        (self.game/'nxnative-ios.json').write_text(json.dumps(legacy_record))
        h=export.digest(legacy/'old-unsigned.ipa');job={'ipa':str(legacy/'old-unsigned.ipa'),'sha256':h,'team':'same','account':'same','gameFolder':str(self.game)}
        self.jobs.write_text(json.dumps([job]));count=self.count
        out=organize_export.organize(self.game,'ios',self.root/'Clean',jobs_path=self.jobs)
        self.assertEqual(self.count,count);new=self.record()
        self.assertEqual(export.digest(Path(new['light_ipa'])),h)
        after=json.loads(self.jobs.read_text())[0];self.assertEqual(after['sha256'],h);self.assertEqual(after['team'],'same')
        self.assertEqual(after['ipa'],new['light_ipa']);self.assertFalse(legacy.exists())
        self.assertTrue((out/'Datos/romfs/data/world').is_file())

    def test_safe_title_is_a_single_visible_component(self):
        for s in ['../../escape','A/B:C','..','', '\x00x']:
            n=export.safe_name(s);self.assertEqual(Path(n).name,n);self.assertFalse(n.startswith('.'))


if __name__=='__main__':unittest.main()
