#!/usr/bin/env python3
"""Build a relocatable ARM64 tool bundle, without games, keys, accounts or user preferences."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import tarfile
import urllib.request

PYTHON_URL='https://github.com/astral-sh/python-build-standalone/releases/download/20261026/cpython-3.13.18%2B20261026-aarch64-apple-darwin-install_only_stripped.tar.gz'
PYTHON_SHA='8392b6ea51d94391befb2c31ebe75463f045d0b69dfcf5e1bb3234e1f5fa3405'


def run(*args):return subprocess.check_output(args,text=True).strip()


def build_reader(destination,cache):
    repo=Path(__file__).resolve().parents[1]
    reader=repo/'dm/tools/nx_extract'
    reader_hash=hashlib.sha256(b''.join((reader/name).read_bytes() for name in ('Program.cs','nx_extract.csproj'))).hexdigest()
    with tempfile.TemporaryDirectory(prefix='portable-reader-',dir=cache) as temp:
        project=Path(temp)/'source';project.mkdir()
        for name in ('Program.cs','nx_extract.csproj'):shutil.copy2(reader/name,project/name)
        subprocess.run([str(destination/'dotnet/dotnet'),'build',str(project),'-c','Release','-o',str(destination/'nx_extract'),'--packages',str(destination/'nuget'),'-p:NuGetAudit=false'],check=True)
    return reader_hash


def bundle(destination,cache):
    cache.mkdir(parents=True,exist_ok=True)
    if destination.exists():
        manifest=json.loads((destination/'manifest.json').read_text())
        if manifest['python']['sha256']!=PYTHON_SHA:raise ValueError('Wrong cached runtime')
        manifest['reader_source_sha256']=build_reader(destination,cache)
        manifest['dotnet_sdks']=[line.split(' [')[0] for line in run(str(destination/'dotnet/dotnet'),'--list-sdks').splitlines()]
        (destination/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
        return
    destination.mkdir(parents=True)
    archive=cache/'python-3.13.18-arm64.tar.gz'
    if not archive.exists():
        temporary=archive.with_suffix('.download')
        with urllib.request.urlopen(PYTHON_URL,timeout=90) as reader,temporary.open('wb') as writer:shutil.copyfileobj(reader,writer)
        temporary.replace(archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=PYTHON_SHA:raise ValueError('Python runtime checksum mismatch')
    with tarfile.open(archive) as source:source.extractall(destination,filter='data')
    python=destination/'python/bin/python3'
    subprocess.run([str(python),'-m','pip','install','--disable-pip-version-check','--only-binary=:all:','-r',str(Path(__file__).resolve().parents[1]/'desktop/portable-requirements.txt')],check=True)
    bin_dir=destination/'bin';lib_dir=destination/'lib';licenses=destination/'Licenses'
    for folder in (bin_dir,lib_dir,licenses):folder.mkdir()
    sources={};copied={}
    def copy_macho(source,output):
        source=source.resolve()
        if output.name in copied:
            if copied[output.name]!=source:raise ValueError('Conflicting tool library names')
            return
        copied[output.name]=source;shutil.copy2(source,output)
        listing=run('otool','-l',str(source));rpaths=re.findall(r'cmd LC_RPATH\n.*?path (.*?) \(offset',listing,re.S)
        for line in run('otool','-L',str(source)).splitlines()[1:]:
            dep=line.strip().split(' (')[0]
            if dep.startswith(('/usr/lib/','/System/Library/')):continue
            if dep.startswith('@rpath/'):
                name=dep.removeprefix('@rpath/');roots=[source.parent,Path('/opt/homebrew/lib')]+[Path(p.replace('@loader_path',str(source.parent)).replace('@executable_path',str(source.parent))) for p in rpaths]
                found=next((root/name for root in roots if (root/name).is_file()),None)
            else:found=Path(dep.replace('@loader_path',str(source.parent)))
            if found is None or not found.is_file():raise ValueError('Unresolved portable tool dependency: '+dep)
            target=lib_dir/found.name;copy_macho(found,target)
            subprocess.run(['install_name_tool','-change',dep,'@loader_path/../lib/'+target.name,str(output)],check=True)
        if output.suffix=='.dylib':subprocess.run(['install_name_tool','-id','@rpath/'+output.name,str(output)],check=True)
        subprocess.run(['codesign','--force','--sign','-','--timestamp=none',str(output)],check=True)
    for name,formula in [('xcodegen','xcodegen'),('zstd','zstd'),('glslangValidator','glslang')]:
        source=shutil.which(name)
        if source is None:raise ValueError('Release builder requires '+name)
        copy_macho(Path(source),bin_dir/name)
        prefix=Path(run('brew','--prefix',formula));sources[name]={'formula':formula,'version':run('brew','list','--versions',formula)}
        if (prefix/'sbom.spdx.json').is_file():shutil.copy2(prefix/'sbom.spdx.json',licenses/(formula+'-sbom.spdx.json'))
        for file in prefix.glob('*'):
            if file.is_file() and file.name.upper().startswith(('LICENSE','COPYING','NOTICE')):shutil.copy2(file,licenses/(formula+'-'+file.name))
    dotnet=Path(run('which','dotnet')).resolve().parent
    shutil.copytree(dotnet,destination/'dotnet',symlinks=True)
    subprocess.run([str(destination/'dotnet/dotnet'),'--list-sdks'],check=True)
    for source in (Path('/opt/homebrew/opt/xz'),Path('/opt/homebrew/opt/lz4'),Path('/opt/homebrew/opt/spirv-tools')):
        if (source/'sbom.spdx.json').is_file():shutil.copy2(source/'sbom.spdx.json',licenses/(source.name+'-sbom.spdx.json'))
        for file in source.glob('*'):
            if file.is_file() and file.name.upper().startswith(('LICENSE','COPYING','NOTICE')):shutil.copy2(file,licenses/(source.name+'-'+file.name))
    reader_hash=build_reader(destination,cache)
    manifest={'reader_source_sha256':reader_hash,'schema':1,'architecture':'arm64','python':{'source':PYTHON_URL,'sha256':PYTHON_SHA},'tools':sources,'dotnet_sdks':[line.split(' [')[0] for line in run(str(destination/'dotnet/dotnet'),'--list-sdks').splitlines()]}
    (destination/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
