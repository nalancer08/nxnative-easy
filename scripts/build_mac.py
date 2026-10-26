#!/usr/bin/env python3
"""Prepare a self-contained Mac game app from the user's own files."""
import argparse
from datetime import datetime
import json
from pathlib import Path
import platform
import sys
from build_ios import REPO, build_lock, load_builder, select_keys


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('game_dir',type=Path)
    parser.add_argument('--keys-folder',type=Path,required=True)
    parser.add_argument('--dry-run',action='store_true')
    args=parser.parse_args(argv)
    game=args.game_dir.expanduser().resolve(strict=True)
    if not game.is_dir() or game==REPO or REPO in game.parents:
        raise ValueError('Keep game folders outside the source repository.')
    packages=[p for p in game.iterdir() if p.is_file() and p.suffix.lower() in {'.nsp','.xci','.nsz','.xcz'}]
    if not packages: raise ValueError('No NSP/XCI/NSZ/XCZ files directly in this game folder.')
    output=game/('nxnative-mac-'+datetime.now().strftime('%Y%m%d-%H%M%S-%f')+'.app')
    command=[str(game),'--platform','mac-app','--mac-sign','-','--team-id','0000000000',
             '--progress','lines','-o',str(output)]
    if args.dry_run:
        print('Mac command:',command)
        return 0
    if sys.platform!='darwin' or platform.machine()!='arm64':
        raise ValueError('Mac games require an Apple silicon Mac.')
    args.keys=None
    keys=select_keys(args)
    with build_lock():
        if any(p.suffix.lower() in {'.nsz','.xcz'} for p in packages):
            import subprocess
            subprocess.run([sys.executable,'-m','pip','install','nsz'],check=True)
        code=load_builder().cli(command+['-k',str(keys)])
        if code: return code
        if not (output/'Contents/MacOS/dmhost').is_file():
            raise ValueError('Build finished without a Mac game app.')
        record={'schema':1,'app_path':str(output)}
        state=game/'nxnative-mac.json'
        temporary=state.with_suffix('.json.tmp')
        temporary.write_text(json.dumps(record,indent=2)+'\n')
        temporary.replace(state)
    print('Mac app:',output,flush=True)
    return 0

if __name__=='__main__':
    try: sys.exit(main())
    except (ValueError,OSError) as error:
        print('Error:',error,file=sys.stderr);sys.exit(1)
