#!/usr/bin/env python3
"""Move an existing prepared game to a verified, named export without recompiling."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

from build_ios import build_lock, verify_ipa
from game_export import MARKER, digest, export_location, manifest, publish, staging, _clone_file


def clone_tree(source, destination):
    if source.is_symlink() or not source.is_dir() or destination.exists():
        raise ValueError('Invalid source or destination game data folder.')
    destination.parent.mkdir(parents=True,exist_ok=True)
    if sys.platform=='darwin':
        result=subprocess.run(['/bin/cp','-cRp',str(source),str(destination)],capture_output=True)
        if result.returncode==0:
            return
        if destination.exists():
            shutil.rmtree(destination)
    shutil.copytree(source,destination,symlinks=True)


def organize(game, platform, parent, *, jobs_path=None):
    game=Path(game).expanduser().resolve(strict=True)
    state_path=game/('nxnative-'+platform+'.json')
    old=json.loads(state_path.read_text())
    if old.get('schema',1)!=1:
        raise ValueError('Unsupported preparation record; files preserved.')
    jobs_path=Path(jobs_path) if jobs_path is not None else Path.home()/'Library/Application Support/nxnative Easy/refresh-jobs.json'
    with build_lock(game):
        source_data=None
        if platform=='ios':
            full=old.get('packaging')=='full'
            packages=list(Path(old['light_dir']).glob('*.ipa')) if not full and old.get('light_dir') else []
            path=old.get('full_ipa') if full else old.get('light_ipa') or (str(packages[0]) if len(packages)==1 else None)
            if not path:
                raise ValueError('No unique prepared IPA found; previous files preserved.')
            source=Path(path);info=verify_ipa(source)
            with zipfile.ZipFile(source) as archive:
                if archive.testzip() is not None:
                    raise ValueError('IPA integrity check failed; original preserved.')
            if info['CFBundleIdentifier']!=old.get('bundle_id'):
                raise ValueError('Package identity does not match its preparation.')
            if not full:
                source_data=Path(old.get('romfs_path') or Path(old['light_dir'])/'romfs')
        else:
            import plistlib
            source=Path(old['app_path'])
            info=plistlib.loads((source/'Contents/Info.plist').read_bytes())
            if not (source/'Contents/MacOS/dmhost').is_file():
                raise ValueError('Mac game executable is missing.')
            if info['CFBundleIdentifier']!=old.get('bundle_id',info['CFBundleIdentifier']):
                raise ValueError('Mac game identity changed; previous files preserved.')
        info.setdefault('CFBundleDisplayName',old.get('app_name') or game.name)
        destination,title,parent=export_location(game,platform,info,parent,old)
        if old.get('export_folder')==str(destination):
            return destination
        print(json.dumps({'ev':'stage','name':'Organize export','step':'Verifying and arranging the existing game','k':1,'n':1}),flush=True)
        source_hash=digest(source) if platform=='ios' else manifest(source)
        data_hash=manifest(source_data) if source_data is not None else None
        record=dict(old,export_folder=str(destination),export_parent=str(parent))
        if not record.get('prepared_at'):
            record['prepared_at']=datetime.fromtimestamp(source.stat().st_mtime,timezone.utc).isoformat(timespec='seconds')
            record['prepared_at_source']='legacy_package_mtime'
        relocations={}
        with staging(destination) as stage:
            if platform=='ios':
                name=title+'.ipa';_clone_file(source,stage/name)
                if digest(stage/name)!=source_hash:
                    raise ValueError('IPA copy failed verification; original preserved.')
                if source_data is not None:
                    clone_tree(source_data,stage/'Datos/romfs')
                    if manifest(stage/'Datos/romfs')!=data_hash:
                        raise ValueError('Game data copy failed verification; original preserved.')
                    record.update(light_dir=str(destination),light_ipa=str(destination/name),romfs_path=str(destination/'Datos/romfs'))
                else:
                    record.update(full_ipa=str(destination/name))
                relocations[str(source)]=str(destination/name)
            else:
                name=title+'.app';clone_tree(source,stage/name)
                if manifest(stage/name)!=source_hash:
                    raise ValueError('Mac app copy failed verification; original preserved.')
                record['app_path']=str(destination/name)
            publish(game,platform,stage,destination,info,record,jobs_path=jobs_path,relocations=relocations)
        # A move: remove only the exact source whose complete copy was verified.
        # Keep files outside the selected source folder (external/shared exports).
        # Old managed exports can be retired after this successful relocation.
        old_export=Path(old['export_folder']) if old.get('export_folder') else None
        if old_export and old_export!=destination and old_export.exists():
            marker=old_export/MARKER
            managed=json.loads(marker.read_text()) if marker.is_file() and not marker.is_symlink() else {}
            jobs=json.loads(jobs_path.read_text()) if jobs_path.exists() else []
            safe=(managed.get('source_folder')==str(game) and managed.get('platform')==platform
                  and manifest(old_export)==managed.get('files')
                  and not any(Path(j.get('ipa','/missing')).is_relative_to(old_export) for j in jobs))
            if safe:
                shutil.rmtree(old_export)
                old_export=None
        if source.is_relative_to(game) and not source.is_symlink():
            if platform=='ios' and digest(source)==source_hash:
                source.unlink()
            elif platform=='mac' and manifest(source)==source_hash:
                shutil.rmtree(source)
        if source_data is not None and source_data.is_relative_to(game) and not source_data.is_symlink() and manifest(source_data)==data_hash:
            shutil.rmtree(source_data)
        if old_export and old_export!=destination and old_export.exists():
            # Do not delete unrelated content or other platforms in its parent.
            print('Previous managed export retained for inspection:',old_export,flush=True)
        elif source.parent!=game and source.parent.is_relative_to(game):
            help_file=source.parent/'INSTALL.txt'
            if help_file.is_file() and help_file.read_text().startswith('Install the lightweight IPA with Sideloadly'):
                help_file.unlink()
            try:source.parent.rmdir()
            except OSError:pass
        print('Game export:',destination,flush=True)
        return destination


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('game',type=Path)
    parser.add_argument('--target',choices=['ios','mac'],required=True)
    parser.add_argument('--export-dir',type=Path,required=True)
    args=parser.parse_args()
    organize(args.game,args.target,args.export_dir)


if __name__=='__main__':
    try:main()
    except (OSError,ValueError,KeyError,subprocess.SubprocessError) as error:
        print('Export failed; previous files preserved:',error,file=sys.stderr)
        raise SystemExit(1)
