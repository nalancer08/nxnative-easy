#!/usr/bin/env python3
"""Compile the native ARM64 sideload helper with a pinned isolated Rust toolchain."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import urllib.request

ROOT=Path(__file__).resolve().parents[1]


def toolchain(cache):
    cache=cache.expanduser().resolve()
    if cache==ROOT or ROOT in cache.parents:raise ValueError('Keep native tools outside the source checkout.')
    settings=json.loads((ROOT/'native/sideload-helper/toolchain.json').read_text())
    prefix=cache/('rust-'+settings['version']);marker=prefix/'ready.json'
    if marker.is_file() and json.loads(marker.read_text())==settings:return prefix
    cache.mkdir(parents=True,exist_ok=True)
    for item in settings['components']:
        archive=cache/Path(item['url']).name
        if not archive.is_file() or hashlib.sha256(archive.read_bytes()).hexdigest()!=item['sha256']:
            print('Downloading pinned Rust component: '+item['component'],flush=True)
            temporary=archive.with_suffix('.download')
            with urllib.request.urlopen(item['url'],timeout=120) as response,temporary.open('wb') as output:shutil.copyfileobj(response,output)
            if hashlib.sha256(temporary.read_bytes()).hexdigest()!=item['sha256']:raise ValueError('Rust component checksum mismatch.')
            temporary.replace(archive)
        unpack=cache/(item['component']+'-unpacked')
        if unpack.exists():shutil.rmtree(unpack)
        unpack.mkdir()
        with tarfile.open(archive) as source:
            for member in source.getmembers():
                destination=(unpack/member.name).resolve()
                if not destination.is_relative_to(unpack.resolve()) or member.isdev():raise ValueError('Unsafe toolchain archive member.')
                if member.issym() or member.islnk():
                    target=(destination.parent/member.linkname if member.issym() else unpack/member.linkname).resolve()
                    if not target.is_relative_to(unpack.resolve()):raise ValueError('Unsafe toolchain archive link.')
            if hasattr(tarfile,'data_filter'):source.extractall(unpack,filter='data')
            else:source.extractall(unpack)  # Validated pinned archive; system Python 3.9 has no filters.
        package=next(unpack.glob('*/components')).parent
        # Rust's shell installer splits prefixes containing spaces. Copy its official
        # component manifests directly; the macOS toolchain is relocatable.
        for component in (package/'components').read_text().splitlines():
            directory=package/component
            for row in (directory/'manifest.in').read_text().splitlines():
                kind,relative=row.split(':',1);source=directory/relative;destination=prefix/relative
                if not destination.resolve().is_relative_to(prefix.resolve()):raise ValueError('Invalid toolchain component path.')
                destination.parent.mkdir(parents=True,exist_ok=True)
                if kind=='file':
                    if source.is_symlink() and destination.is_symlink():destination.unlink()
                    shutil.copy2(source,destination,follow_symlinks=False)
                elif kind=='dir':shutil.copytree(source,destination,dirs_exist_ok=True,symlinks=True)
                else:raise ValueError('Unknown Rust component manifest entry.')
        shutil.rmtree(unpack)
    marker.write_text(json.dumps(settings,indent=2)+'\n');return prefix


def build(output,cache):
    output=output.expanduser().resolve();cache=cache.expanduser().resolve()
    if cache==ROOT or ROOT in cache.parents or output==ROOT or ROOT in output.parents:raise ValueError('Keep helper binaries and toolchains outside source.')
    prefix=toolchain(cache);env=dict(os.environ,CARGO_HOME=str(cache/'cargo'),CARGO_TARGET_DIR=str(cache/'target'))
    env['PATH']=str(prefix/'bin')+os.pathsep+env.get('PATH','')
    env.setdefault('CARGO_BUILD_JOBS','2')
    target=json.loads((ROOT/'native/sideload-helper/toolchain.json').read_text())['target']
    subprocess.run([str(prefix/'bin/cargo'),'build','--release','--locked','--target',target,'--manifest-path',str(ROOT/'native/sideload-helper/Cargo.toml')],env=env,check=True)
    output.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(cache/'target'/target/'release/nxnative-sideload',output)
    metadata=subprocess.run([str(prefix/'bin/cargo'),'metadata','--locked','--format-version','1','--manifest-path',str(ROOT/'native/sideload-helper/Cargo.toml')],env=env,capture_output=True,text=True,check=True)
    notices=output.parent/'sideload-licenses';notices.mkdir(exist_ok=True)
    packages=[]
    for package in json.loads(metadata.stdout)['packages']:
        directory=Path(package['manifest_path']).parent;name=package['name']+'-'+package['version'];notice_directory=notices/name
        notice_directory.mkdir(exist_ok=True)
        for pattern in ('LICENSE*','COPYING*','NOTICE*'):
            for path in directory.glob(pattern):
                if path.is_file():shutil.copy2(path,notice_directory/path.name)
        packages.append({'name':package['name'],'version':package['version'],'license':package.get('license'),'repository':package.get('repository'),'source_archive':'https://crates.io/api/v1/crates/'+package['name']+'/'+package['version']+'/download' if package.get('source') else 'See native/sideload-helper in the nxnative Easy source repository.'})
    (notices/'packages.json').write_text(json.dumps(packages,indent=2)+'\n')
    subprocess.run(['codesign','--force','--sign','-','--timestamp=none',str(output)],check=True)
    return output


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache',type=Path,required=True)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--toolchain-only',action='store_true')
    args=parser.parse_args()
    if args.toolchain_only:print(toolchain(args.cache.expanduser().resolve()))
    elif args.output:print(build(args.output,args.cache))
    else:parser.error('--output is required')

if __name__=='__main__':main()
