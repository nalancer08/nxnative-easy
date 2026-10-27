"""Metadata decisions use internal identities and reject stale inputs, never filename tags."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('inspection',ROOT/'scripts/inspect_game.py')
inspection=importlib.util.module_from_spec(spec);spec.loader.exec_module(inspection)


def package(file,kind,version,display=None,title='010093801237C000'):
    return dict(file=file,kind=kind,version=version,display_version=display,name='Synthetic Game',title_id=title,content_id=title if kind=='base' else title[:-3]+'800')


class GameInspection(unittest.TestCase):
    def test_internal_version_beats_filename(self):
        value=inspection.summarize(dict(schema=1,packages=[package('base.xci','base',0,'1.0'),package('update-v999999.nsp','update',65536,'1.1'),package('no tags.nsp','update',131072,'1.2')],errors=[]))
        self.assertEqual((value['status'],value['display_version'],value['selected_file']),('ready','1.2','no tags.nsp'))
        self.assertEqual(value['base_version'],'1.0')
        self.assertEqual(len(value['updates']),2)

    def test_base_only_and_unknown_display_are_honest(self):
        value=inspection.summarize(dict(schema=1,packages=[package('base.xci','base',0)],errors=[]))
        self.assertEqual(value['updates'],[])
        self.assertIsNone(value['display_version'])

    def test_multiple_games_missing_base_and_partial_errors(self):
        base=package('base.xci','base',0)
        for packages,errors,status in [([package('update.nsp','update',1)],[],'base_missing'),([base,package('other.xci','base',0,title='010015100B514000')],[],'multiple_games'),([base],[dict(file='bad.nsp',code='metadata_unreadable')],'incomplete')]:
            self.assertEqual(inspection.summarize(dict(schema=1,packages=packages,errors=errors))['status'],status)

    def test_manifest_drives_build_and_rejects_changed_inputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary)
            for name in ['original.xci','untagged.nsp']:(folder/name).write_bytes(b'synthetic')
            value=inspection.summarize(dict(schema=1,packages=[package('original.xci','base',0,'1.0'),package('untagged.nsp','update',196608,'1.3')],errors=[]))
            value['sources']={p.name:[p.stat().st_size,p.stat().st_mtime_ns] for p in folder.iterdir()}
            app,family=inspection.family_from_metadata(folder,value)
            self.assertEqual(app,int('010093801237C000',16))
            self.assertEqual(family['updates'],[(196608,(folder/'untagged.nsp').resolve())])
            self.assertEqual((folder/'untagged.nsp').read_bytes(),b'synthetic')
            bad=copy.deepcopy(value);bad['packages'][1]['file']='../escape.nsp'
            with self.assertRaises(ValueError):inspection.family_from_metadata(folder,bad)
            (folder/'untagged.nsp').write_bytes(b'changed')
            with self.assertRaises(ValueError):inspection.family_from_metadata(folder,value)

    def test_key_errors_do_not_claim_base_is_missing(self):
        for code,status in [('keys_unreadable','keys_unreadable'),('metadata_unreadable','metadata_unreadable')]:
            self.assertEqual(inspection.summarize(dict(schema=1,packages=[],errors=[dict(file='x',code=code)]))['status'],status)

    def test_added_package_invalidates_inspection(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary);(folder/'base.xci').write_bytes(b'base')
            value=inspection.summarize(dict(schema=1,packages=[package('base.xci','base',0)],errors=[]))
            value['sources']={p.name:[p.stat().st_size,p.stat().st_mtime_ns] for p in folder.iterdir()}
            (folder/'new.nsp').write_bytes(b'update')
            with self.assertRaises(ValueError):inspection.family_from_metadata(folder,value)
