"""A conflicted upstream produces a draft proposal without changing main or integration metadata."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('proposal',ROOT/'scripts/propose_upstream.py')
assert spec and spec.loader
proposal=importlib.util.module_from_spec(spec);spec.loader.exec_module(proposal)
class Proposal(unittest.TestCase):
    def test_conflict_is_reported_on_separate_branch_only(self):
        original_run=subprocess.run
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);repo=root/'fork';repo.mkdir();remote=root/'origin.git'
            def git(*args):return subprocess.check_output(['git','-C',str(repo),*args],text=True,stderr=subprocess.DEVNULL).strip()
            original_run(['git','init','--bare',str(remote)],check=True,capture_output=True)
            git('init','-b','main');git('config','user.name','Synthetic');git('config','user.email','test@example.invalid')
            (repo/'README.md').write_text('base\n')
            (repo/'README-es.md').write_text('Spanish intro\n')
            (repo/'desktop/NxNativeEasy').mkdir(parents=True)
            for name in ['game-artwork.json','game-catalog.json']:(repo/'desktop/NxNativeEasy'/name).write_text('{}')
            git('add','.');git('commit','-m','base');base=git('rev-parse','HEAD')
            git('switch','-c','upstream');(repo/'README.md').write_text('upstream\n');git('commit','-am','upstream');head=git('rev-parse','HEAD')
            git('switch','main');(repo/'README.md').write_text('our UI\n');(repo/'docs').mkdir();(repo/'docs/upstream-sync.json').write_text(json.dumps({'integrated_head':base}));git('add','.');git('commit','-m','our work')
            git('remote','add','origin',str(remote));git('push','origin','main');before=git('rev-parse','HEAD');calls=[]
            def redirected_git(*args):
                if args[0]=='fetch':return git('fetch','.', 'upstream')
                return git(*args)
            def run(args,*a,**kwargs):
                if args[0]=='gh':
                    calls.append(args)
                    return subprocess.CompletedProcess(args,0,'[]' if args[1:3]==['pr','list'] else '', '')
                return original_run(args,*a,**kwargs)
            with patch.object(proposal,'ROOT',repo),patch.object(proposal,'git',side_effect=redirected_git),patch.object(proposal.subprocess,'run',side_effect=run):proposal.main()
            self.assertEqual(git('rev-parse','HEAD'),before);self.assertEqual((repo/'README.md').read_text(),'our UI\n')
            self.assertEqual(json.loads((repo/'docs/upstream-sync.json').read_text())['integrated_head'],base)
            branch='origin/maintenance/upstream-'+head[:12]
            report=git('show',branch+':docs/pending-upstream.md');self.assertIn('Manual conflict resolution required',report)
            self.assertIn('--draft',calls[-1]);self.assertNotIn('merge',calls[-1]);self.assertEqual(git('rev-parse','origin/main'),before)
if __name__=='__main__':unittest.main()
