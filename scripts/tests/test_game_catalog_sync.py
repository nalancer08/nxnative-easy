"""New profiles must reach artwork, live catalog inventory and both README galleries."""
import importlib.util
import json
import shutil
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('catalog_sync',ROOT/'scripts/sync_game_catalog.py')
assert spec is not None and spec.loader is not None
sync=importlib.util.module_from_spec(spec);spec.loader.exec_module(sync)
ID='0100000000000001'

class GameCatalogSync(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        (self.root/'dm/games').mkdir(parents=True)
        (self.root/'docs/images').mkdir(parents=True)
        (self.root/'desktop/NxNativeEasy').mkdir(parents=True)
        for name in ['README.md','README-es.md']:(self.root/name).write_text('Personal intro\n<table>\n</table>\nPersonal footer\n')
        self.add_game(ID,'Example',image=True)

    def add_game(self,title,name,image=True):
        folder=self.root/'dm/games'/title;folder.mkdir()
        (folder/'README.md').write_text('# '+name)
        (folder/'game.tsv').write_text(f'name\t{name}\nbuild\tv0\t1.0\n')
        table=self.root/'dm/games/README.md'
        with table.open('a') as out:out.write(f'| [{name}]({title}/README.md) | `{title}` |\n')
        if image:(self.root/f'docs/images/{title}.png').write_bytes(b'synthetic image')

    def source(self,title=ID,name='Example'):
        return f'<table><td><img src="docs/images/{title}.png" alt="{name}"><br>{name}<sub>~1 GB</sub></td></table>'

    def test_addition_and_version_change_propagate_everywhere_and_are_idempotent(self):
        sync.sync(self.root,write=True,upstream_html=self.source())
        other='0100000000000002';self.add_game(other,'Another Game')
        with self.assertRaises(ValueError):sync.sync(self.root)
        sync.sync(self.root,write=True,upstream_html=self.source(other,'Another Game'))
        with (self.root/f'dm/games/{ID}/game.tsv').open('a') as out:out.write('build\tv1\t2.0\n')
        with self.assertRaises(ValueError):sync.sync(self.root)
        sync.sync(self.root,write=True)
        games=json.loads((self.root/sync.CATALOG).read_text())['games']
        self.assertEqual(len(games),2)
        self.assertEqual(next(g for g in games if g['id']==ID)['versions'],['1.0','2.0'])
        self.assertEqual(set(json.loads((self.root/sync.ART).read_text())),{ID,other})
        for name in ['README.md','README-es.md']:
            text=(self.root/name).read_text()
            self.assertIn('Personal intro',text);self.assertIn('Personal footer',text)
            self.assertIn(other,text);self.assertIn(ID,text)
        self.assertEqual(sync.sync(self.root),[])

    def test_missing_image_or_game_note_stops_before_writing(self):
        original=(self.root/'README.md').read_text()
        with self.assertRaises(ValueError):sync.sync(self.root,write=True)
        self.assertEqual((self.root/'README.md').read_text(),original)
        (self.root/f'dm/games/{ID}/README.md').unlink()
        with self.assertRaises(ValueError):sync.outputs(self.root,self.source())

    def test_external_image_is_rejected(self):
        outside=self.root/'outside.png';outside.write_bytes(b'synthetic')
        image=self.root/f'docs/images/{ID}.png';image.unlink();image.symlink_to(outside)
        with self.assertRaises(ValueError):sync.outputs(self.root,self.source())

    def test_repository_catalog_is_current(self):
        self.assertEqual(sync.sync(ROOT),[])

    def test_removed_profile_is_removed_from_every_generated_surface(self):
        other='0100000000000002';self.add_game(other,'Another Game')
        sync.sync(self.root,write=True,upstream_html=self.source()+self.source(other,'Another Game'))
        shutil.rmtree(self.root/'dm/games'/ID)
        table=self.root/'dm/games/README.md';table.write_text('\n'.join(line for line in table.read_text().splitlines() if ID not in line)+'\n')
        sync.sync(self.root,write=True)
        self.assertNotIn(ID,json.loads((self.root/sync.ART).read_text()))
        self.assertEqual([g['id'] for g in json.loads((self.root/sync.CATALOG).read_text())['games']],[other])
        for name in ['README.md','README-es.md']:self.assertNotIn(ID,(self.root/name).read_text())
