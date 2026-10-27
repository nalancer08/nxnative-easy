"""Selected upstream changes stay isolated from the active checkout, even on conflicts."""
import importlib.util
import json
import sys
from unittest.mock import patch
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('sync_upstream',ROOT/'scripts/sync_upstream.py')
assert spec is not None and spec.loader is not None
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

    def test_full_main_merge_is_isolated(self):
        sync.merge_main(self.root,self.candidate,self.upstream)
        self.assertEqual((self.candidate/'file').read_text(),'upstream\n')
        self.assertEqual((self.root/'file').read_text(),'base\n')
        self.assertEqual(sync.git(self.root,'rev-parse','HEAD'),self.base)

    def test_report_detects_new_profiles_with_versions(self):
        sync.git(self.root,'switch','upstream')
        folder=self.root/'dm/games/0100000000000001';folder.mkdir(parents=True)
        (folder/'game.tsv').write_text('name\tExample\nbuild\tv0\t1.0\n')
        self.commit('new game');head=sync.git(self.root,'rev-parse','HEAD')
        sync.git(self.root,'switch','main')
        change=sync.profile_changes(self.root,head)
        self.assertEqual(change['added'],[dict(id='0100000000000001',name='Example',versions=['1.0'])])
        self.assertEqual(change['updated'],[])
        self.assertEqual(change['removed'],[])

    def test_full_merge_command_passes_python_to_validation(self):
        policy=Path(self.temp.name)/'policy.json'
        policy.write_text(json.dumps(dict(baseline=self.base,integrated=[])))
        output=(Path(self.temp.name)/'report').resolve()
        original_git=sync.git;original_run=subprocess.run
        def git(root,*args):
            if args==('remote','get-url','upstream'):return 'https://github.com/seedds/nxnative.git'
            if args==('fetch','upstream','main'):return ''
            if args==('rev-parse','FETCH_HEAD'):return self.upstream
            return original_git(root,*args)
        def run(command,**kwargs):
            if len(command)>1 and str(command[1]).endswith('scripts/sync_game_catalog.py'):
                return subprocess.CompletedProcess(command,0)
            return original_run(command,**kwargs)
        with patch.object(sync,'ROOT',self.root),patch.object(sync,'POLICY',policy),patch.object(sync,'git',side_effect=git), \
             patch.object(sync,'build_python',return_value=sys.executable),patch.object(sync,'validate') as check, \
             patch.object(sync.subprocess,'run',side_effect=run):
            self.assertEqual(sync.main(['--output',str(output),'--merge-main']),0)
        check.assert_called_once_with(output/'candidate',output,sys.executable)
        self.assertEqual((self.root/'file').read_text(),'base\n')
        self.assertIn('synthetic checks passed',json.loads((output/'report.json').read_text())['candidate_status'])
