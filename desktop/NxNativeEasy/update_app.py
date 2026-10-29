#!/usr/bin/env python3
"""Pinned, staged self-update for nxnative Easy; never edits an existing checkout."""
import argparse
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


def replace_bundle(staged,target):
    backup=target.with_name('.'+target.name+'.previous-'+uuid.uuid4().hex[:10])
    os.replace(target,backup)
    try:os.replace(staged,target)
    except BaseException:
        os.replace(backup,target)
        raise
    return backup


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
        tag=manifest_url('https://api.github.com/repos/nalancer08/nxnative-easy/commits/v'+version)
        if info.get('NxNativeSourceRevision')!=tag['sha']:raise ValueError('Portable release source identity mismatch.')
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
    if (target/'Contents/Resources/Tools/manifest.json').is_file():return portable_update(revision,build,target,cache)
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
    parser.add_argument('--revision',required=True)
    parser.add_argument('--build',required=True,type=int)
    parser.add_argument('--target',required=True,type=Path)
    parser.add_argument('--parent-pid',type=int)
    parser.add_argument('--cache',type=Path,default=Path.home()/'Library/Application Support/nxnative Easy/Updates')
    parser.add_argument('--prepare-only',action='store_true')
    args=parser.parse_args()
    if not re.fullmatch('[0-9a-f]{40}',args.revision) or args.build<1:raise ValueError('Invalid update request.')
    target=args.target.expanduser().resolve(strict=True)
    if target.suffix!='.app' or plistlib.loads((target/'Contents/Info.plist').read_bytes()).get('CFBundleIdentifier')!=IDENTIFIER:
        raise ValueError('Only the running nxnative Easy app can be updated.')
    if not args.prepare_only and (not args.parent_pid or args.parent_pid<=1):raise ValueError('Missing launcher process.')
    try:os.setsid()
    except PermissionError:pass
    args.cache.mkdir(parents=True,exist_ok=True)
    lock=(args.cache/('update-'+hashlib.sha256(str(target).encode()).hexdigest()[:16]+'.lock')).open('a')
    try:fcntl.flock(lock,fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:raise ValueError('Another update is already running.')
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
