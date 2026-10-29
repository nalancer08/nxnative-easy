"""Disposable cache deletion is bounded, previewed and guarded; only synthetic files."""
from pathlib import Path
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
import cache_cleanup as cleanup

class Cleanup(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.cache=self.root/'010093801237C000_build/shader/cache';self.cache.mkdir(parents=True)
        (self.cache/'compiled.bin').write_bytes(b'cache')
        for name in ['game.nsp','output.ipa','prod.keys','save/slot','romfs/game']:
            p=self.root/name;p.parent.mkdir(exist_ok=True);p.write_bytes(b'original')
    def test_only_selected_cache_removed_and_originals_unchanged(self):
        preview=cleanup.candidates(self.root)
        self.assertEqual(len(preview),1);self.assertEqual(preview[0]['bytes'],5)
        self.assertEqual(cleanup.delete(self.root,preview),5)
        for path in ['game.nsp','output.ipa','prod.keys','save/slot','romfs/game']:self.assertEqual((self.root/path).read_bytes(),b'original')
    def test_changed_preview_and_arbitrary_path_rejected(self):
        preview=cleanup.candidates(self.root);(self.cache/'compiled.bin').write_bytes(b'changed')
        with self.assertRaises(ValueError):cleanup.delete(self.root,preview)
        with self.assertRaises(ValueError):cleanup.delete(self.root,[dict(path='../save',digest='x',bytes=1)])
        self.assertTrue(self.cache.exists())
    def test_links_and_protected_content_exclude_entire_cache(self):
        (self.cache/'link').symlink_to(self.root/'save')
        self.assertEqual(cleanup.candidates(self.root),[])
        (self.cache/'link').unlink();(self.cache/'prod.keys').write_bytes(b'private')
        self.assertEqual(cleanup.candidates(self.root),[])
    def test_active_build_blocks_deletion(self):
        preview=cleanup.candidates(self.root)
        with cleanup.build_lock(self.root),self.assertRaises(ValueError):cleanup.delete(self.root,preview)
        self.assertTrue((self.cache/'compiled.bin').exists())

    def test_replaced_directory_is_not_the_approved_cache(self):
        preview=cleanup.candidates(self.root);self.cache.rename(self.cache.with_name('preserved'))
        self.cache.mkdir();(self.cache/'new').write_bytes(b'do not remove')
        with self.assertRaises(ValueError):cleanup.delete(self.root,preview)
        self.assertTrue((self.cache/'new').exists())

if __name__=='__main__':unittest.main()
