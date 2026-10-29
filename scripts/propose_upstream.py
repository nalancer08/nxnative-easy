#!/usr/bin/env python3
"""Open/update one review branch for upstream main. Never merge or approve it."""
import json
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
BRANCH_PREFIX='maintenance/upstream-'


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()


def main():
    state=json.loads((ROOT/'docs/upstream-sync.json').read_text());base=state['integrated_head']
    git('fetch','https://github.com/seedds/nxnative.git','main');head=git('rev-parse','FETCH_HEAD')
    branch=BRANCH_PREFIX+head[:12]
    if head==base:print('Upstream unchanged');return
    current=subprocess.run(['gh','pr','list','--head',branch,'--state','open','--json','number,body'],cwd=ROOT,capture_output=True,text=True,check=True)
    existing=json.loads(current.stdout)
    if existing and head in existing[0]['body']:print('Existing proposal already covers this revision');return
    with tempfile.TemporaryDirectory(prefix='upstream-proposal-') as folder:
        candidate=Path(folder)/'candidate';git('worktree','add','--detach',str(candidate),'HEAD')
        try:
            def command(*args,check=True):return subprocess.run(args,cwd=candidate,text=True,capture_output=True,check=check)
            command('git','config','user.name','github-actions[bot]');command('git','config','user.email','41898282+github-actions[bot]@users.noreply.github.com')
            merge=command('git','merge','--no-edit',head,check=False)
            conflicts=command('git','diff','--name-only','--diff-filter=U').stdout.strip()
            if merge.returncode:
                command('git','merge','--abort')
                status='Manual conflict resolution required. No engine changes are staged in this proposal. Conflicts: '+conflicts.replace('\n',', ')
            else:
                catalog=command('python3',str(ROOT/'scripts/sync_game_catalog.py'),'--root',str(candidate),'--write','--upstream-ref',head,check=False)
                status='Candidate engine merge; requires catalog, fork, host/GPU, shader and device review.'
                if catalog.returncode:status+=' Catalog mapping needs manual resolution.'
            commits=git('log','--oneline',base+'..'+head)
            evidence=candidate/'docs/pending-upstream.md'
            evidence.write_text('# Pending upstream review\n\nPinned head: `'+head+'`.\n\n'+status+'\n\n```text\n'+commits+'\n```\n\nFollow docs/agents/07-upstream-maintenance.md before integrating. This workflow never advances integrated_head, bumps releases, signs, installs or merges the PR.\n')
            command('git','add','docs/pending-upstream.md','README.md','README-es.md','desktop/NxNativeEasy/game-artwork.json','desktop/NxNativeEasy/game-catalog.json')
            command('git','commit','-m','Propose upstream review through '+head[:12])
            command('git','push','origin','HEAD:refs/heads/'+branch,'--no-force')
            body=Path(folder)/'body.md';body.write_text('Review upstream `'+head+'` since `'+base+'`.\n\n'+status+'\n\nNo automatic merge or release. Follow the maintenance guide and preserve all Easy workflows, game identities and saves.')
            args=['gh','pr','edit',str(existing[0]['number'])] if existing else ['gh','pr','create','--draft','--base','main','--head',branch]
            command(*args,'--title','Review upstream '+head[:12],'--body-file',str(body))
        finally:git('worktree','remove','--force',str(candidate))


if __name__=='__main__':main()
