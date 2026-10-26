#!/usr/bin/env python3
"""Archive every open upstream PR and changes since a base revision, without applying them."""
import argparse
import concurrent.futures
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess


def gh(*args):
    return subprocess.run(['gh',*args],capture_output=True,text=True,check=True).stdout


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base',default='ecbeae164c0b419d1ba1031248fe1402050a3eb0')
    parser.add_argument('--repo',default='seedds/nxnative')
    parser.add_argument('--output',type=Path,required=True,help='new folder outside the source checkout')
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[1]
    output=args.output.expanduser().resolve()
    if output==root or root in output.parents: parser.error('Keep review archives outside the source checkout.')
    output.mkdir(parents=True,exist_ok=False)
    # Freeze the comparison to a SHA before fetching any diffs.
    head=json.loads(gh('api',f'repos/{args.repo}/commits/main'))['sha']
    comparison=json.loads(gh('api',f'repos/{args.repo}/compare/{args.base}...{head}'))
    (output/'comparison.json').write_text(json.dumps(comparison,indent=2)+'\n')
    prs=json.loads(gh('pr','list','--repo',args.repo,'--state','open','--limit','1000',
                     '--json','number,title,headRefOid,isDraft,url'))
    if len(prs)==1000: raise RuntimeError('PR listing hit its limit; paginate before treating this review as complete.')
    def fetch(pr):
        n=pr['number']; data=json.loads(gh('api',f'repos/{args.repo}/pulls/{n}'))
        pages=json.loads(gh('api','--paginate','--slurp',f'repos/{args.repo}/pulls/{n}/files?per_page=100'))
        files=[f for page in pages for f in page]
        if len(files)!=data['changed_files']: raise RuntimeError(f'Incomplete file list for PR #{n}')
        checks=json.loads(gh('api',f'repos/{args.repo}/commits/{data["head"]["sha"]}/check-runs?per_page=100'))
        data['review_files']=files; data['review_checks']=checks
        (output/f'{n}.json').write_text(json.dumps(data,indent=2)+'\n')
        # Freeze diff to the recorded head through compare, rather than a moving PR head.
        diff=gh('api','-H','Accept: application/vnd.github.diff',
                f'repos/{args.repo}/compare/{data["base"]["sha"]}...{data["head"]["sha"]}')
        (output/f'{n}.diff').write_text(diff)
        return {'number':n,'title':data['title'],'head':data['head']['sha'],
                'draft':data['draft'],'files':len(files),'url':data['html_url']}
    results=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for result in pool.map(fetch,prs):
            results.append(result); print(f'Archived PR #{result["number"]}: {result["title"]}',flush=True)
    snapshot={'reviewed_at':datetime.now(timezone.utc).isoformat(),'repo':args.repo,'base':args.base,
              'upstream_head':head,'open_prs':results,'scope':'Static source archive; not approval, merge, device testing or proof of CI success.'}
    (output/'snapshot.json').write_text(json.dumps(snapshot,indent=2)+'\n')
    print('Complete. No PR applied, no source updated. Snapshot:',output/'snapshot.json')


if __name__=='__main__':
    main()
