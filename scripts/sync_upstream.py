#!/usr/bin/env python3
"""Review upstream or test selected commits in a separate checkout; never merge the active branch."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
POLICY=ROOT/'docs/upstream-sync.json'


def git(root,*args):
    return subprocess.check_output(['git','-C',str(root),*args],text=True).strip()


def areas(files):
    groups=[]
    for label,prefixes in [('graphics',('dm/gfx/',)),('runtime/saves/input',('dm/host/','dm/ios/Dm','dm/ios/Game')),
                           ('game profiles',('dm/games/',)),('build tooling',('scripts/','dm/mac/','dm/ios/tools/','dm/tools/'))]:
        if any(f.startswith(prefixes) for f in files):groups.append(label)
    return groups or ['documentation/tests/CI']


def commits(root,base,head,integrated):
    result=[]
    for line in git(root,'log','--reverse','--format=%H\t%s',base+'..'+head).splitlines():
        sha,title=line.split('\t',1)
        files=git(root,'diff-tree','--root','--no-commit-id','--name-only','-r',sha).splitlines()
        result.append(dict(sha=sha,title=title,areas=areas(files),files=files,
                           status='integrated' if sha in integrated else 'needs review'))
    return result


def stage(root,destination,head,selected,integrated):
    # Resolve and validate every request before creating or cherry-picking anything.
    if git(root,'status','--porcelain'):raise ValueError('Commit or stash local edits before staging; nothing was changed.')
    resolved=[]
    for revision in selected:
        if revision.startswith('-'):raise ValueError('Expected an upstream commit SHA.')
        sha=git(root,'rev-parse','--verify',revision+'^{commit}')
        if sha in integrated:raise ValueError('This upstream commit is already recorded as integrated: '+sha)
        if subprocess.run(['git','-C',str(root),'merge-base','--is-ancestor',sha,head]).returncode:
            raise ValueError('Requested commit is not in the pinned upstream history: '+sha)
        if sha in resolved:raise ValueError('Duplicate commit: '+sha)
        resolved.append(sha)
    git(root,'worktree','add','--detach',str(destination),'HEAD')
    # On conflict leave the candidate and Git's conflict state for inspection. The active checkout is untouched.
    subprocess.run(['git','-C',str(destination),'cherry-pick','-x',*resolved],check=True)


def build_python():
    candidates=[Path(sys.executable),ROOT.parent/'venv/bin/python',
                Path.home()/'Library/Application Support/nxnative Easy/Tools/nxnative-tools/venv/bin/python']
    for python in candidates:
        if python.is_file() and subprocess.run([str(python),'-c','import capstone, lz4, fontTools'],
                                               stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0:
            return str(python)
    raise ValueError('Build-test packages are missing. Run START-HERE.command once, then retry this command.')


def validate(candidate,output,python):
    env=__import__('os').environ.copy();env.setdefault('DM_GAME','010015100B514000')
    logs=output/'checks';logs.mkdir()
    suites=['scripts/tests','dm/tools/tests','dm/ios/tests','dm/gfx/tests']
    for suite in suites:
        for test in sorted((candidate/suite).glob('test_*.py')):
            relative=test.relative_to(candidate)
            with (logs/str(relative).replace('/','_')).with_suffix('.log').open('w') as log:
                subprocess.run([python,'-m','unittest',str(relative)],cwd=candidate,env=env,
                               stdout=log,stderr=subprocess.STDOUT,check=True)
    # Passing synthetic checks is not gameplay validation or permission to publish a release.


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',required=True,type=Path,help='new directory outside this checkout')
    parser.add_argument('--stage',nargs='+',metavar='SHA',help='explicitly reviewed commits, in dependency order; stage and run synthetic checks')
    args=parser.parse_args(argv)
    output=args.output.expanduser().resolve()
    if output==ROOT or ROOT in output.parents or output.exists():parser.error('Choose a new folder outside the source checkout.')
    policy=json.loads(POLICY.read_text())
    remote=git(ROOT,'remote','get-url','upstream').removesuffix('.git')
    if remote not in ('https://github.com/seedds/nxnative','git@github.com:seedds/nxnative'):
        parser.error('The upstream remote does not point to seedds/nxnative; no files changed.')
    git(ROOT,'fetch','upstream','main')
    head=git(ROOT,'rev-parse','FETCH_HEAD')
    integrated={item['upstream_sha'] for item in policy['integrated']}
    rows=commits(ROOT,policy['baseline'],head,integrated)
    output.mkdir(parents=True)
    report=dict(reviewed_at=datetime.now(timezone.utc).isoformat(),upstream_head=head,baseline=policy['baseline'],
                local_head=git(ROOT,'rev-parse','HEAD'),commits=rows,candidate_status='not staged')
    report_path=output/'report.json'
    def save():report_path.write_text(json.dumps(report,indent=2)+'\n')
    save()
    lines=['# Upstream review','','Pinned upstream: `'+head+'`. No active branch or game files changed.','',
           '| Commit | Status | Areas | Change |','|---|---|---|---|']
    for row in rows:
        title=row['title'].replace('|','/').replace('\n',' ')
        lines.append(f"| `{row['sha'][:12]}` | {row['status']} | {', '.join(row['areas'])} | {title} |")
    (output/'report.md').write_text('\n'.join(lines)+'\n')
    print('Review:',output/'report.md',flush=True)
    if args.stage:
        report['requested_commits']=args.stage;report['candidate_status']='staging';save()
        try:
            python=build_python()
            stage(ROOT,output/'candidate',head,args.stage,integrated)
            report['candidate_status']='checking';save()
            validate(output/'candidate',output)
            report['candidate_status']='synthetic checks passed; gameplay and release review still required';save()
        except Exception:
            report['candidate_status']='failed; inspect candidate and checks, active checkout preserved';save();raise
        print('Candidate:',output/'candidate')
        print('Inspect changes, compile affected targets and test games before integration.')
    else:
        print('To evaluate selected commits, run again with a new --output folder and --stage SHA [SHA ...].')
    return 0


if __name__=='__main__':
    try:sys.exit(main())
    except (ValueError,OSError,subprocess.SubprocessError) as error:
        print('Error:',error,file=sys.stderr);sys.exit(1)
