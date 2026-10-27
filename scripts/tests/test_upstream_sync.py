"""Selected upstream changes stay isolated from the active checkout, even on conflicts."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('sync_upstream',ROOT/'scripts/sync_upstream.py')
sync=importlib.util.module_from_spec(spec);spec.loader.exec_module(sync)

class UpstreamSync(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)/'repo';self.root.mkdir()
        sync.git(self.root,'init','-b','main')
        sync.git(self.root,'config','user.name','Test')
        sync.git(self.root,'config','user.email','test@example.invalid')
        (self.root/'file').write_text('base\n');self.commit('base');self.base=sync.git(self.root,'rev-parse','HEAD')
        sync.git(self.root,'switch','-c','upstream')
        (self.root/'file').write_text('upstream\n');self.commit('upstream');self.upstream=sync.git(self.root,'rev-parse','HEAD')
        sync.git(self.root,'switch','main')
        self.candidate=Path(self.temp.name)/'candidate'

    def commit(self,message):
        sync.git(self.root,'add','.');sync.git(self.root,'commit','-m',message)

    def test_stage_preserves_active_checkout(self):
        sync.stage(self.root,self.candidate,self.upstream,[self.upstream],set())
        self.assertEqual((self.candidate/'file').read_text(),'upstream\n')
        self.assertEqual((self.root/'file').read_text(),'base\n')
        self.assertEqual(sync.git(self.root,'rev-parse','HEAD'),self.base)
        self.assertIn(self.upstream,sync.git(self.candidate,'log','-1','--format=%B'))

    def test_dirty_checkout_is_preserved(self):
        (self.root/'file').write_text('local edits\n')
        with self.assertRaises(ValueError):sync.stage(self.root,self.candidate,self.upstream,[self.upstream],set())
        self.assertFalse(self.candidate.exists())
        self.assertEqual((self.root/'file').read_text(),'local edits\n')

    def test_conflict_stays_in_candidate(self):
        (self.root/'file').write_text('fork\n');self.commit('fork')
        with self.assertRaises(subprocess.CalledProcessError):sync.stage(self.root,self.candidate,self.upstream,[self.upstream],set())
        self.assertEqual((self.root/'file').read_text(),'fork\n')
        self.assertEqual(sync.git(self.root,'status','--porcelain'),'')
        self.assertIn('UU file',sync.git(self.candidate,'status','--porcelain'))

    def test_rejects_integrated_and_non_upstream_requests_before_staging(self):
        (self.root/'local').write_text('fork');self.commit('fork');local=sync.git(self.root,'rev-parse','HEAD')
        for revision,integrated in ((self.upstream,{self.upstream}),(local,set()),('--help',set())):
            with self.subTest(revision=revision),self.assertRaises(ValueError):
                sync.stage(self.root,self.candidate,self.upstream,[revision],integrated)
            self.assertFalse(self.candidate.exists())

    def test_report_keeps_review_separate_from_integration(self):
        rows=sync.commits(self.root,self.base,self.upstream,set())
        self.assertEqual(rows[0]['status'],'needs review')
        self.assertEqual(sync.commits(self.root,self.base,self.upstream,{self.upstream})[0]['status'],'integrated')
        self.assertIn('graphics',sync.areas(['dm/gfx/nvn/file.c']))
        self.assertIn('runtime/saves/input',sync.areas(['dm/host/hle_fs.c']))
