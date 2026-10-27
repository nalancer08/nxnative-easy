#!/usr/bin/env python3
"""Prepare a self-contained Mac game app from the user's own files."""
import argparse
from datetime import datetime
import json
import os
import plistlib
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
    state=game/'nxnative-mac.json'
    previous=json.loads(state.read_text()) if state.exists() else {}
    if not isinstance(previous,dict) or previous.get('schema',1)!=1:raise ValueError('Unsupported nxnative-mac.json; previous record was preserved.')
    old_info={}
    if isinstance(previous.get('app_path'),str):
        info_path=Path(previous['app_path'])/'Contents/Info.plist'
        if info_path.is_file():old_info=plistlib.loads(info_path.read_bytes())
    if not isinstance(old_info,dict):raise ValueError('Invalid previous Mac app metadata; preserved without changes.')
    old_id=previous.get('bundle_id') or old_info.get('CFBundleIdentifier')
    if old_id is not None and (not isinstance(old_id,str) or not old_id.strip()):raise ValueError('Invalid previous Mac bundle identity.')
    old_title=previous.get('title_id') or old_info.get('DMTitleID')
    output=game/('nxnative-mac-'+datetime.now().strftime('%Y%m%d-%H%M%S-%f')+'.app')
    command=[str(game),'--platform','mac-app','--mac-sign','-','--team-id','0000000000',
             '--progress',os.environ.get('NXE_PROGRESS','lines'),'-o',str(output)]
    if old_id:command+=['--bundle-id',old_id]
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
        romfs=output/'Contents/Resources/romfs'
        if not (output/'Contents/MacOS/dmhost').is_file() or not romfs.is_dir() or romfs.is_symlink():
            raise ValueError('Build finished without a complete Mac game app (embedded game data required).')
        info=plistlib.loads((output/'Contents/Info.plist').read_bytes())
        if old_id and info.get('CFBundleIdentifier')!=old_id:raise ValueError('Mac bundle identity changed; previous app record was preserved.')
        if old_title and info.get('DMTitleID')!=old_title:raise ValueError('Mac Title ID changed; use a separate folder for another game.')
        record={'schema':1,'app_path':str(output),'bundle_id':info.get('CFBundleIdentifier'),
                'title_id':info.get('DMTitleID'),'version':info.get('CFBundleShortVersionString')}
        temporary=state.with_suffix('.json.tmp')
        temporary.write_text(json.dumps(record,indent=2)+'\n')
        temporary.replace(state)
    print('Mac app:',output,flush=True)
    return 0

if __name__=='__main__':
    try: sys.exit(main())
    except (ValueError,OSError) as error:
        print('Error:',error,file=sys.stderr);sys.exit(1)
