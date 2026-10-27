#!/usr/bin/env python3
"""Build from this checkout and export an unsigned lightweight IPA in one command."""
import argparse
from contextlib import contextmanager
import hashlib
import tempfile
import fcntl
from datetime import datetime
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import zipfile

REPO = Path(__file__).resolve().parents[1]


@contextmanager
def build_lock():
    # Separate game folders still share the checkout's generated source files.
    digest = hashlib.sha256(str(REPO).encode()).hexdigest()[:20]
    with open(Path(tempfile.gettempdir()) / ('nxnative-ios-'+digest+'.lock'),'a') as lock:
        try:
            fcntl.flock(lock,fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise ValueError('Another build is using this checkout; wait for it to finish.') from error
        try:
            yield
        finally:
            fcntl.flock(lock,fcntl.LOCK_UN)


def load_builder(package_metadata=None):
    spec = importlib.util.spec_from_file_location('nxnative_builder', REPO / 'scripts/build_ipa_from_nsp.py')
    assert spec is not None and spec.loader is not None
    builder = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = builder
    spec.loader.exec_module(builder)
    # Preserve the venv executable path: resolving its symlink selects global Python.
    builder.TOOL_PATHS.insert(0, str(Path(sys.executable).parent))
    if package_metadata is not None:
        metadata_spec = importlib.util.spec_from_file_location('nxnative_inspection', REPO/'scripts/inspect_game.py')
        metadata = importlib.util.module_from_spec(metadata_spec)
        metadata_spec.loader.exec_module(metadata)
        value = json.loads(Path(package_metadata).read_text())
        builder.scan_nsps = lambda folder: metadata.family_from_metadata(folder, value)
    return builder


def verify_ipa(path):
    from split_ipa import validate_entries, removed_signature
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        validate_entries(entries)
        if any(removed_signature(e.filename) for e in entries):
            raise ValueError('Expected an unsigned IPA, but signing resources were found.')
        roots = [e.filename for e in entries if e.filename.startswith('Payload/')
                 and len(e.filename.split('/')) == 3 and e.filename.endswith('.app/Info.plist')]
        if len(roots) != 1:
            raise ValueError('Expected a single app Info.plist.')
        info = plistlib.loads(archive.read(roots[0]))
        executable = info.get('CFBundleExecutable')
        prefix = roots[0][:-len('Info.plist')]
        if not isinstance(executable, str) or '/' in executable or '\\' in executable or prefix+executable not in archive.namelist():
            raise ValueError('Missing or invalid app executable.')
        return info


def choose_keys_folder():
    result=subprocess.run(['/usr/bin/osascript','-e',
        'POSIX path of (choose folder with prompt "Select your own folder containing prod.keys")'],
        capture_output=True,text=True,check=True)
    return Path(result.stdout.rstrip('\n'))


def select_keys(args):
    # Never silently discover keys next to a game or in a bundled/default location.
    folder=args.keys_folder
    if args.keys is not None:
        keys=args.keys.expanduser()
    else:
        folder=folder if folder is not None else choose_keys_folder()
        keys=folder.expanduser()/'prod.keys'
    resolved=keys.resolve()
    if REPO==resolved or REPO in resolved.parents:
        raise ValueError('Select your own keys outside the source repository.')
    if not resolved.is_file() or not resolved.stat().st_size:
        raise ValueError('The selected folder must contain your own readable prod.keys.')
    return resolved


def parser():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('game_dir', nargs='?', type=Path, help='folder containing one game and its updates')
    keys=p.add_mutually_exclusive_group()
    keys.add_argument('--keys-folder',type=Path,help='explicit external folder containing your own prod.keys')
    keys.add_argument('-k','--keys',type=Path,help='explicit path to your own prod.keys (legacy CLI option)')
    p.add_argument('-l', '--language', help='first build defaults to es-419; later builds retain identity settings')
    p.add_argument('--bundle-id', help='use the SAME effective identifier when updating an installed app')
    p.add_argument('--app-name')
    p.add_argument('--package-metadata',type=Path,help='verified preflight metadata; changed inputs are rejected')
    p.add_argument('--package', help='explicit game update, such as v327680')
    p.add_argument('--gpu', help='pipeline archive target; first build defaults to none')
    p.add_argument('--show-fps', action=argparse.BooleanOptionalAction, default=None, help='retain FPS display choice across builds')
    p.add_argument('--app-only', action='store_true', help='rebuild app from existing valid caches, without keys or re-extraction')
    p.add_argument('--full-only', action='store_true', help='keep full IPA without exporting RomFS')
    p.add_argument('--dry-run', action='store_true', help='show configuration without keys, builds or dependency installation')
    return p


def main(argv=None):
    args = parser().parse_args(argv)
    if args.game_dir is None:
        if sys.platform != 'darwin':
            raise ValueError('Provide a game folder.')
        result = subprocess.run(['/usr/bin/osascript', '-e',
            'POSIX path of (choose folder with prompt "Select the folder containing one game")'],
            capture_output=True, text=True, check=True)
        args.game_dir = Path(result.stdout.rstrip('\n'))
    game = args.game_dir.expanduser().resolve(strict=True)
    if not game.is_dir():
        raise ValueError('Game folder is not a directory.')
    # Keep game data and credentials out of the source checkout.
    if game == REPO or REPO in game.parents:
        raise ValueError('Keep game folders outside the source repository.')
    packages = [p for p in game.iterdir() if p.is_file() and p.suffix.lower() in {'.nsp','.xci','.nsz','.xcz'}]
    if not packages:
        raise ValueError('No NSP/XCI/NSZ/XCZ files directly in this game folder.')
    previous = None
    if args.app_only:
        archives = sorted(game.glob('*.ipa'),key=lambda p:p.stat().st_mtime,reverse=True)
        if archives: previous = verify_ipa(archives[0])
    state_path = game / 'nxnative-ios.json'
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    if not isinstance(state, dict) or state.get('schema',1) != 1:
        raise ValueError('Unsupported nxnative-ios.json; preserve it and check its format.')
    if not state and previous:
        state = {'bundle_id':previous['CFBundleIdentifier'],'app_name':previous.get('CFBundleDisplayName'),
                 'language':previous.get('DMLanguage','es-419'),'gpu':'none'}
    settings = {}
    for key, default in [('language','es-419'),('gpu','none'),('bundle_id',None),('app_name',None)]:
        value = getattr(args,key) if getattr(args,key) is not None else state.get(key,default)
        if value is not None and (not isinstance(value,str) or not value.strip()):
            raise ValueError('Invalid saved setting: '+key)
        settings[key] = value
    settings['show_fps'] = args.show_fps if args.show_fps is not None else state.get('show_fps',str((previous or {}).get('DMShowFPS','YES')).lower() in {'yes','1','true'})
    if not isinstance(settings['show_fps'],bool): raise ValueError('Invalid saved show_fps setting.')
    old_id = state.get('bundle_id')
    if old_id and settings['bundle_id'] != old_id:
        raise ValueError('Bundle ID differs from the previous build. Use a separate game folder for a separate app.')
    output = game / ('nxnative-ios-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f') + '-unsigned.ipa')
    command = [str(game), '--platform','ios','--team-id','0000000000',
               '--gpu',settings['gpu'],'-l',settings['language'],'--progress',os.environ.get('NXE_PROGRESS','lines'),'-o',str(output)]
    for key in ['bundle_id','app_name']:
        if settings[key]: command += ['--'+key.replace('_','-'), settings[key]]
    command += ['--show-fps' if settings['show_fps'] else '--no-show-fps']
    if args.package: command += ['--package',args.package]
    revision = subprocess.run(['git','-C',str(REPO),'rev-parse','HEAD'],capture_output=True,text=True).stdout.strip() or 'downloaded-source'
    print('Source checkout:',REPO,flush=True)
    print('Source revision:',revision,flush=True)
    print('Output:',output,flush=True)
    print('Settings:',json.dumps(settings),flush=True)
    if args.dry_run:
        print('Dry run: no build, no key access, no data changes.')
        return 0
    if sys.platform != 'darwin': raise ValueError('Builds require macOS and Xcode.')
    with build_lock():
        if args.app_only:
            works = [p for p in game.glob('*_build') if re.fullmatch(r'[0-9a-fA-F]{16}_build',p.name)]
            if len(works)!=1: raise ValueError('App-only needs exactly one existing title build directory.')
            work=works[0]; title=work.name[:-6]
            versions=[p for p in work.glob('patched_v*') if p.is_dir() and re.fullmatch(r'patched_v[0-9]+',p.name)]
            package=args.package or ('v'+str(max(int(p.name[9:]) for p in versions)) if versions else None)
            if not package or not re.fullmatch(r'v[0-9]+',package): raise ValueError('No valid cached package found.')
            env=dict(os.environ, GAME=title, W=str(work/'ipa'), PATCHED=str(work/('patched_'+package)),
                     ROMFS=str(work/'extract'/package/'RomFS'), MSL_IOS=str(work/'shader/ios'),
                     FONT_PY=sys.executable, DM_TEAM_ID='0000000000',DM_PSO_GPUS=settings['gpu'],
                     DM_LANG=settings['language'],DM_SHOW_FPS='1' if settings['show_fps'] else '0',
                     PATH=os.pathsep.join([str(Path(sys.executable).parent),'/opt/homebrew/bin',os.environ.get('PATH','')]))
            derived=work/'profile'/title
            if derived.is_dir(): env['DM_GAMES_DIR']=str(derived.parent)
            else: env.pop('DM_GAMES_DIR',None)
            for setting,variable in [('bundle_id','DM_BUNDLE_ID'),('app_name','DM_DISPLAY_NAME')]:
                if settings[setting]: env[variable]=settings[setting]
            subprocess.run(['bash',str(REPO/'dm/ios/tools/build_ipa.sh'),str(output)],cwd=REPO,env=env,check=True)
        else:
            keys = select_keys(args)
            if any(p.suffix.lower() in {'.nsz','.xcz'} for p in packages):
                subprocess.run([sys.executable,'-m','pip','install','nsz'],check=True)
            builder = load_builder(args.package_metadata) if args.package_metadata else load_builder()
            code = builder.cli(command + ['-k',str(keys)])
            if code: return code
        info = verify_ipa(output)
        actual_id = info['CFBundleIdentifier']
        if old_id and actual_id != old_id: raise ValueError('Built bundle ID changed unexpectedly; do not install.')
        settings['bundle_id'] = actual_id
        from split_ipa import split_ipa
        if os.environ.get('NXE_PROGRESS')=='json' and not args.full_only:
            print(json.dumps({'ev':'stage','name':'Export lightweight IPA','step':'Separating game data','k':0,'n':0}),flush=True)
        light_dir = None if args.full_only else split_ipa(output)
        record = dict(schema=1, **settings, version=info.get('CFBundleShortVersionString'),
                      source_revision=revision, packaging="full" if args.full_only else "split", full_ipa=str(output), light_dir=str(light_dir) if light_dir else None)
        temp = state_path.with_suffix('.json.tmp')
        temp.write_text(json.dumps(record,indent=2)+'\n'); temp.replace(state_path)
        print('Build complete. Install over the existing app using the same personal account and effective bundle ID.')
        print('The game is not installed or signed by this script. Keep the existing app Documents and saves.')
        return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130) from None
    except (OSError,ValueError,subprocess.SubprocessError,zipfile.BadZipFile) as error:
        print('Error:',error,file=sys.stderr)
        raise SystemExit(1) from error
