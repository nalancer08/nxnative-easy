#!/usr/bin/env python3
"""Pinned, staged self-update for nxnative Easy; never edits an existing checkout."""
import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import urllib.request
import uuid
import zipfile

IDENTIFIER='com.nalancer08.nxnative.easy'
MAX_ARCHIVE=256*1024*1024
MAX_EXPANDED=2*1024*1024*1024


def emit(phase,progress=None,message=None):
    try:
        print(json.dumps(dict(phase=phase,progress=progress,message=message)),flush=True)
    except BrokenPipeError:
        pass


def manifest(path):
    value=json.loads(Path(path).read_text())
    if not re.fullmatch(r'\d+\.\d+(?:\.\d+)?',str(value.get('version',''))):
        raise ValueError('Invalid update version.')
    if type(value.get('build')) is not int or value['build']<1:
        raise ValueError('Invalid update build.')
    if type(value.get('minimumMacOSMajor')) is not int or value['minimumMacOSMajor']<1:
        raise ValueError('Invalid minimum macOS version.')
    return value


def extract(archive,destination,revision):
    expected='nxnative-easy-'+revision
    with zipfile.ZipFile(archive) as z:
        total=0;seen=set()
        for entry in z.infolist():
            path=PurePosixPath(entry.filename)
            mode=entry.external_attr>>16
            if path.is_absolute() or '..' in path.parts or '\\' in entry.filename or not path.parts or path.parts[0]!=expected:
                raise ValueError('Unsafe update archive path.')
            if stat.S_ISLNK(mode) or (stat.S_IFMT(mode) and not (stat.S_ISREG(mode) or stat.S_ISDIR(mode))):
                raise ValueError('Links and special files are not allowed in updates.')
            relative=PurePosixPath(*path.parts[1:])
            if '.git' in relative.parts or relative.name.lower() in {'prod.keys','title.keys'} or relative.suffix.lower() in {'.nsp','.xci','.nsz','.xcz','.ipa','.p12','.mobileprovision'}:
                raise ValueError('Unexpected game or credential file in update.')
            if entry.filename in seen:raise ValueError('Duplicate archive path.')
            seen.add(entry.filename);total+=entry.file_size
            if total>MAX_EXPANDED:raise ValueError('Update archive is too large.')
        if shutil.disk_usage(destination.parent).free<total+64*1024*1024:
            raise OSError('Not enough free disk space for the update.')
        for entry in z.infolist():
            parts=PurePosixPath(entry.filename).parts[1:]
            if not parts:continue
            target=destination.joinpath(*parts)
            if entry.is_dir():target.mkdir(parents=True,exist_ok=True);continue
            target.parent.mkdir(parents=True,exist_ok=True)
            with z.open(entry) as source,target.open('xb') as output:shutil.copyfileobj(source,output)
            target.chmod(0o644 | ((entry.external_attr>>16)&0o111))


def download(revision,path):
    request=urllib.request.Request('https://codeload.github.com/nalancer08/nxnative-easy/zip/'+revision,
                                   headers={'User-Agent':'nxnative-Easy-Updater'})
    emit('download')
    with urllib.request.urlopen(request,timeout=45) as response,path.open('wb') as output:
        total=int(response.headers.get('Content-Length') or 0)
        received=0
        while True:
            block=response.read(256*1024)
            if not block:break
            received+=len(block)
            if received>MAX_ARCHIVE:raise ValueError('Update download is too large.')
            output.write(block)
            emit('download',min(1,received/total) if total else None)


def validate_app(path,expected_build,expected_version):
    info=plistlib.loads((path/'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier')!=IDENTIFIER or str(info.get('CFBundleVersion'))!=str(expected_build):
        raise ValueError('The prepared app does not match the requested update.')
    if info.get('CFBundleShortVersionString')!=expected_version:raise ValueError('Unexpected app version.')
    if not (path/'Contents/MacOS/NxNativeEasy').is_file():raise ValueError('Missing update executable.')
    subprocess.run(['/usr/bin/codesign','--verify','--deep','--strict',str(path)],check=True,capture_output=True)


def release_revision(version):
    # /commits/<tag> includes patches and can exceed the metadata limit after a
    # large engine merge. Git refs/tag objects contain only the identity needed.
    if not isinstance(version,str) or not re.fullmatch(r'\d+\.\d+\.\d+',version):raise ValueError('Invalid release version.')
    obj=manifest_url('https://api.github.com/repos/nalancer08/nxnative-easy/git/ref/tags/v'+version).get('object',{})
    seen=set()
    for _ in range(5):
        if not isinstance(obj,dict):raise ValueError('Invalid release tag object.')
        sha=obj.get('sha','')
        if not isinstance(sha,str) or not re.fullmatch('[0-9a-f]{40}',sha):raise ValueError('Invalid release tag identity.')
        if obj.get('type')=='commit':return sha
        if obj.get('type')!='tag' or sha in seen:raise ValueError('Invalid release tag chain.')
        seen.add(sha)
        obj=manifest_url('https://api.github.com/repos/nalancer08/nxnative-easy/git/tags/'+sha).get('object',{})
    raise ValueError('Release tag chain is too deep.')


def replace_bundle(staged,target):
    backup=target.with_name('.'+target.name+'.previous-'+uuid.uuid4().hex[:10])
    os.replace(target,backup)
    try:os.replace(staged,target)
    except BaseException:
        os.replace(backup,target)
        raise
    return backup


def bundle_metadata(app):
    if app.is_symlink() or not app.is_dir():
        raise ValueError('Invalid app bundle.')
    info_path = app/'Contents/Info.plist'
    if info_path.resolve() != info_path or not info_path.is_file():
        raise ValueError('Invalid app metadata.')
    info = plistlib.loads(info_path.read_bytes())
    if info.get('CFBundleIdentifier') != IDENTIFIER:
        raise ValueError('Unexpected app identity.')
    build = str(info.get('CFBundleVersion', ''))
    version = info.get('CFBundleShortVersionString', '')
    if not re.fullmatch(r'[1-9][0-9]*', build) or not isinstance(version, str) or not re.fullmatch(r'\d+\.\d+(?:\.\d+)?', version):
        raise ValueError('Invalid app version.')
    return info, int(build), version


def file_hash(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''):
            digest.update(block)
    return digest.hexdigest()


def open_user_paths():
    result = subprocess.run(
        ['/usr/sbin/lsof', '-nP', '-a', '-u', str(os.getuid()), '-Fn'],
        check=True, capture_output=True, text=True, timeout=15,
    )
    return [line[1:] for line in result.stdout.splitlines() if line.startswith('n/')]


def path_in_use(path, opened):
    name = str(path)
    names = (name, '/System/Volumes/Data' + name)
    return any(item == prefix or item.startswith(prefix + '/') for item in opened for prefix in names)


def managed_bundle(info, cache):
    if info.get('NxNativeLocalModifications'):
        return False
    configured = info.get('NxNativeSource')
    if not configured:
        return True
    if not isinstance(configured, str):
        return False
    source = Path(configured)
    return source.parent == cache/'Sources' and bool(re.fullmatch(r'[a-f0-9]{40}-[a-f0-9]{8}', source.name))


def matches_source_seed(copied, seed, revision):
    """A cached tree may be modified by a developer. Match its signed seed."""
    if copied.resolve() != copied or not copied.is_dir() or copied.stat().st_uid != os.getuid():
        return False
    metadata = ('SOURCE_REVISION', 'SOURCE_INDEX.json')
    if any((copied/name).is_symlink() or not (copied/name).is_file() or not (seed/name).is_file() for name in metadata):
        return False
    if (seed/metadata[0]).read_text().strip() != revision:
        return False
    if any(file_hash(copied/name) != file_hash(seed/name) for name in metadata):
        return False
    index = json.loads((seed/metadata[1]).read_text())
    if not isinstance(index, dict) or not index:
        return False
    expected = set(index) | set(metadata)
    expected_dirs = {parent.as_posix() for name in expected for parent in PurePosixPath(name).parents}
    found = set()
    def fail_walk(error):
        raise error
    for parent, dirs, files in os.walk(copied, onerror=fail_walk):
        for name in dirs:
            path = Path(parent)/name
            if path.is_symlink() or path.relative_to(copied).as_posix() not in expected_dirs:
                return False
        for name in files:
            path = Path(parent)/name
            relative = path.relative_to(copied).as_posix()
            if relative not in expected or path.is_symlink() or not path.is_file():
                return False
            if relative in index and file_hash(path) != index[relative]:
                return False
            found.add(relative)
    return found == expected


def clean_installed_storage(target, cache):
    """Called on a successful launch, also after upgrades from older updaters."""
    info, build, version = bundle_metadata(target)
    install = target.stat()
    stamp = [build, version, install.st_dev, install.st_ino, install.st_ctime_ns]
    receipt = cache/('storage-'+hashlib.sha256(os.fsencode(target)).hexdigest()[:16]+'.json')
    if receipt.is_file() and not receipt.is_symlink():
        try:
            if json.loads(receipt.read_text()).get('installation') == stamp:
                return
        except (OSError, ValueError, AttributeError):
            pass
    validate_app(target, build, version)

    pattern = re.escape('.'+target.name+'.previous-') + r'[a-f0-9]{10}'
    backups = []
    for path in target.parent.iterdir():
        if not re.fullmatch(pattern, path.name):
            continue
        try:
            metadata, number, release = bundle_metadata(path)
            backups.append((path.stat().st_ctime_ns, path, metadata, number, release))
        except (OSError, ValueError, plistlib.InvalidFileException):
            continue
    # Match the rename performed by the updater, including legacy versions.
    backups.sort(key=lambda item: (item[0], item[3]), reverse=True)
    previous = None
    for _, path, metadata, number, release in backups:
        if number > build:
            continue
        try:
            validate_app(path, number, release)
            previous = path
            break
        except (OSError, ValueError, subprocess.SubprocessError):
            continue

    removed_bundles = 0
    removed_sources = 0
    deferred = False
    if previous is not None:
        opened = open_user_paths()
        obsolete = []
        protected = [info]
        source_root = cache.parent/'PortableSources'
        for _, path, metadata, number, release in backups:
            revision = metadata.get('NxNativeSourceRevision')
            source_open = (isinstance(revision, str) and re.fullmatch(r'[a-f0-9]{40}', revision)
                           and path_in_use(source_root/revision, opened))
            in_use = path_in_use(path, opened) or source_open
            if path != previous and number <= build and managed_bundle(metadata, cache) and in_use:
                deferred = True
            if (path == previous or number > build or path.stat().st_uid != os.getuid()
                    or not managed_bundle(metadata, cache) or in_use):
                protected.append(metadata)
                continue
            try:
                validate_app(path, number, release)
                obsolete.append((path, metadata))
            except (OSError, ValueError, subprocess.SubprocessError):
                protected.append(metadata)

        retained_revisions = {
            item['NxNativeSourceRevision'] for item in protected
            if isinstance(item.get('NxNativeSourceRevision'), str)
        }
        for path, metadata in obsolete:
            revision = metadata.get('NxNativeSourceRevision')
            if isinstance(revision, str) and re.fullmatch(r'[a-f0-9]{40}', revision) and revision not in retained_revisions:
                copied = source_root/revision
                seed = path/'Contents/Resources/Source'
                if not path_in_use(copied, opened) and matches_source_seed(copied, seed, revision):
                    shutil.rmtree(copied)
                    removed_sources += 1
            shutil.rmtree(path)
            removed_bundles += 1

    result = dict(installation=stamp, rollback=previous.name if previous else None,
                  removed_bundles=removed_bundles, removed_sources=removed_sources, deferred=deferred)
    emit('cleaned', message=json.dumps(result))
    if deferred:
        # Try again on a later launch after the other process has closed.
        return
    with tempfile.NamedTemporaryFile(dir=cache, prefix='.storage-', delete=False) as output:
        temporary = Path(output.name)
        output.write(json.dumps(result).encode())
    try:
        os.replace(temporary, receipt)
    finally:
        temporary.unlink(missing_ok=True)


@contextmanager
def update_lock(cache, target, wait=0):
    key = hashlib.sha256(os.fsencode(target)).hexdigest()[:16]
    path = cache/('update-'+key+'.lock')
    with os.fdopen(os.open(path, os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW, 0o600), 'a') as lock:
        deadline = time.monotonic() + wait
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX|fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise ValueError('Another update is already running.')
                time.sleep(0.2)
        yield


def portable_update(revision,build,target,cache):
    release=manifest_url('https://raw.githubusercontent.com/nalancer08/nxnative-easy/'+revision+'/desktop/release.json')
    if release['build']!=build:raise ValueError('Release metadata changed.')
    version=release['version']
    if not re.fullmatch(r'\d+\.\d+\.\d+',version):raise ValueError('Invalid release version.')
    base='https://github.com/nalancer08/nxnative-easy/releases/download/v'+version+'/'
    checks=urllib.request.urlopen(base+'SHA256SUMS',timeout=30).read(16385)
    if len(checks)>16384:raise ValueError('Invalid release checksums.')
    expected=next((line.split()[0] for line in checks.decode('ascii').splitlines() if line.split()[-1:] == ['nxnative-Easy-macOS-arm64.zip']),None)
    if expected is None or not re.fullmatch('[0-9a-f]{64}',expected):raise ValueError('Missing portable release checksum.')
    staging=Path(tempfile.mkdtemp(prefix='.nxnative-update-',dir=target.parent)).resolve()
    try:
        archive=staging/'release.zip';digest=hashlib.sha256();received=0
        emit('download')
        with urllib.request.urlopen(base+'nxnative-Easy-macOS-arm64.zip',timeout=90) as reader,archive.open('xb') as writer:
            while block:=reader.read(1024*1024):
                received+=len(block)
                if received>1024**3:raise ValueError('Portable release too large.')
                digest.update(block);writer.write(block)
        if digest.hexdigest()!=expected:raise ValueError('Portable release checksum mismatch.')
        emit('extract')
        with zipfile.ZipFile(archive) as packed:
            total=0;seen=set();links={}
            for entry in packed.infolist():
                name=entry.filename;parts=PurePosixPath(name).parts
                if not parts or parts[0] not in ('nxnative Easy.app','__MACOSX') or name.startswith('/') or '\\' in name or any(p in ('.','..') for p in parts):raise ValueError('Unsafe portable archive path.')
                folded=name.rstrip('/').casefold()
                if folded in seen:raise ValueError('Duplicate portable archive path.')
                seen.add(folded);total+=entry.file_size
                if total>4*1024**3:raise ValueError('Expanded portable release too large.')
                if stat.S_ISLNK(entry.external_attr>>16):
                    if entry.file_size>4096:raise ValueError('Invalid portable symlink.')
                    links[name]=packed.read(entry).decode('utf-8')
            for name,link in links.items():
                if link.startswith('/') or not (staging/Path(name).parent/link).resolve().is_relative_to(staging/'nxnative Easy.app'):raise ValueError('External portable symlink.')
                if any(other.startswith(name.rstrip('/')+'/') for other in packed.namelist()):raise ValueError('Archive writes through symlink.')
            if shutil.disk_usage(staging).free<total+128*1024**2:raise ValueError('Insufficient update space.')
        subprocess.run(['/usr/bin/ditto','-x','-k',str(archive),str(staging)],check=True,capture_output=True)
        archive.unlink();app=staging/'nxnative Easy.app';emit('verify');validate_app(app,build,version)
        info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
        if info.get('NxNativeSourceRevision')!=release_revision(version):raise ValueError('Portable release source identity mismatch.')
        return app,app/'Contents/Resources/Source'
    except BaseException:
        shutil.rmtree(staging,ignore_errors=True);raise


def manifest_url(url):
    request=urllib.request.Request(url,headers={'User-Agent':'nxnative-Easy-Updater'})
    with urllib.request.urlopen(request,timeout=30) as reader:data=reader.read(131073)
    if len(data)>131072:raise ValueError('Release response too large.')
    return json.loads(data)


def prepare(revision,build,target,cache):
    cache.mkdir(parents=True,exist_ok=True)
    if os.environ.get('NXE_PREFER_PORTABLE')=='1' or (target/'Contents/Resources/Tools/manifest.json').is_file():return portable_update(revision,build,target,cache)
    source=cache/'Sources'/(revision+'-'+uuid.uuid4().hex[:8])
    source.parent.mkdir(parents=True,exist_ok=True)
    staging=Path(tempfile.mkdtemp(prefix='.nxnative-update-',dir=target.parent)).resolve()
    try:
        with tempfile.TemporaryDirectory(prefix='download-',dir=cache) as temporary:
            archive=Path(temporary)/'source.zip'
            download(revision,archive)
            emit('extract')
            extract(archive,source,revision)
        release=manifest(source/'desktop/release.json')
        if release['build']!=build:raise ValueError('Release metadata changed; check for updates again.')
        (source/'SOURCE_REVISION').write_text(revision+'\n')
        emit('build')
        app=staging/'nxnative Easy.app'
        logs=cache/'Logs';logs.mkdir(exist_ok=True)
        log=logs/(revision+'-'+uuid.uuid4().hex[:8]+'.log')
        with log.open('w') as output:
            subprocess.run([sys.executable,str(source/'scripts/build_desktop_app.py'),'--output',str(app)],
                           stdout=output,stderr=subprocess.STDOUT,check=True)
        emit('verify')
        validate_app(app,build,release['version'])
        return app,source
    except BaseException:
        shutil.rmtree(staging,ignore_errors=True)
        shutil.rmtree(source,ignore_errors=True)
        raise


def open_app(target):
    subprocess.Popen(['/usr/bin/open',str(target)],stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL,start_new_session=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--revision')
    parser.add_argument('--build',type=int)
    parser.add_argument('--target',required=True,type=Path)
    parser.add_argument('--parent-pid',type=int)
    parser.add_argument('--cache',type=Path,default=Path.home()/'Library/Application Support/nxnative Easy/Updates')
    mode=parser.add_mutually_exclusive_group()
    mode.add_argument('--prepare-only',action='store_true')
    mode.add_argument('--cleanup-only',action='store_true')
    args=parser.parse_args()
    if not args.cleanup_only and (not re.fullmatch('[0-9a-f]{40}',args.revision or '') or not args.build or args.build<1):
        raise ValueError('Invalid update request.')
    target=args.target.expanduser().resolve(strict=True)
    if target.suffix!='.app' or plistlib.loads((target/'Contents/Info.plist').read_bytes()).get('CFBundleIdentifier')!=IDENTIFIER:
        raise ValueError('Only the running nxnative Easy app can be updated.')
    if not (args.prepare_only or args.cleanup_only) and (not args.parent_pid or args.parent_pid<=1):raise ValueError('Missing launcher process.')
    try:os.setsid()
    except PermissionError:pass
    args.cache=args.cache.expanduser().resolve()
    args.cache.mkdir(parents=True,exist_ok=True)
    # An older updater can still hold the lock as it launches the new app.
    with update_lock(args.cache,target,wait=10 if args.cleanup_only else 0):
        if args.cleanup_only:
            clean_installed_storage(target,args.cache)
        else:
            install_update(args,target)


def install_update(args,target):
    staged,source=prepare(args.revision,args.build,target,args.cache)
    if args.prepare_only:
        emit('prepared',1,str(staged));return
    emit('restart',1)
    try:
        deadline=time.monotonic()+30
        while True:
            try:os.kill(args.parent_pid,0)
            except ProcessLookupError:break
            if time.monotonic()>deadline:raise TimeoutError('The app did not close; the old version was preserved.')
            time.sleep(0.2)
        lease_root=Path.home()/'Library/Application Support/nxnative Easy'
        lease_root.mkdir(parents=True,exist_ok=True)
        with (lease_root/'refresh-jobs.json.lock').open('a') as installer_lease:
            try:fcntl.flock(installer_lease,fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError:raise ValueError('A background installation is active; retry the update later.')
            replace_bundle(staged,target)
        open_app(target)
    except BaseException as error:
        (args.cache/'last-error.json').write_text(json.dumps({'message':str(error)}))
        open_app(target)
        raise
    finally:
        shutil.rmtree(staged.parent,ignore_errors=True)


if __name__=='__main__':
    try:main()
    except Exception as error:
        emit('error',message=str(error));sys.exit(1)
