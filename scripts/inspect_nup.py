"""Read-only NUP identification for Easy; no extraction, keys or filename guesses."""
from pathlib import Path
import pack_nup
from inspect_dump import REPO, inspect_dump


def inspect_nup(folder):
    folder=Path(folder).resolve()
    files=[p for p in folder.iterdir() if p.is_file() and p.suffix.lower()=='.nup']
    if not files:return None
    if folder==REPO or REPO in folder.parents:return dict(schema=1,status='invalid_location')
    if len(files)!=1 or files[0].is_symlink() or any(p.is_file() and p.suffix.lower() in {'.nsp','.xci','.nsz','.xcz'} for p in folder.iterdir()):
        return dict(schema=1,status='multiple_sources',input_kind='nup')
    path=files[0]
    def signature():
        s=path.stat();return [s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_ctime_ns]
    before=signature()
    with pack_nup.Nup(path) as n:
        if len(n.packages)>512:raise pack_nup.Error('Too many NUP packages')
        for k in n.packages:
            if k.meta_size>16<<20:raise pack_nup.Error('NUP metadata exceeds inspection limit')
            if k.exefs!=pack_nup.NO_DIR:
                for name,limit in [(b'main.npdm',1<<20),(b'main',256<<20)]:
                    i=n.child(k.exefs,name)
                    if i is not None and n.files[i][1]>limit:raise pack_nup.Error('NUP executable exceeds inspection limit')
        app,base,updates,dlc=pack_nup.scan(n);title=f'{app:016X}'
        profile=REPO/'dm/games'/title/'game.tsv'
        rows=[line.split('\t') for line in profile.read_text().splitlines()] if profile.is_file() else []
        name=next((r[1] for r in rows if len(r)>1 and r[0]=='name'),None)
        fallback=pack_nup.app_package(n).meta()
        def package(k,kind):
            meta={**fallback,**k.meta()};control=meta.get(pack_nup.T_NACP,b'')
            label=next((control[i:i+0x200].split(b'\0')[0].decode('utf-8',errors='replace') for i in range(0,min(len(control),0x3000),0x300) if control[i:i+0x200].split(b'\0')[0]),name)
            version=control[0x3060:0x3070].split(b'\0')[0].decode('utf-8',errors='replace') or None
            if k.exefs!=pack_nup.NO_DIR and (i:=n.child(k.exefs,b'main')) is not None:
                code=n.read(i)
                if len(code)<0x100 or code[:4]!=b'NSO0':raise pack_nup.Error('NUP has no valid main NSO')
            return dict(file=path.name,title_id=title,kind=kind,version=k.version,name=label,display_version=version)
        packages=([package(base,'base')] if base is not None else [])+[package(k,'update') for _,k in sorted(updates.items(),reverse=True)]
        selected=next((p for p in packages if p['kind']=='update'),packages[0])
        sources=dict(file=path.name,signature=before,toc_sha256=n.toc_sha.hex())
        if signature()!=before:return dict(schema=1,status='files_changed',input_kind='nup')
        return dict(schema=1,status='ready' if profile.is_file() else 'profile_missing',input_kind='nup',platform='switch2' if title.startswith('04') else 'switch',title_id=title,name=selected['name'],display_version=selected['display_version'],version=selected['version'],selected_file=path.name,base_version=next((p['display_version'] for p in packages if p['kind']=='base'),None),updates=[p for p in packages if p['kind']=='update'],dlc=[dict(file=path.name,title_id=title,kind='dlc',version=k.version,content_id=f'{tid:016X}') for tid,k in sorted(dlc.items())],packages=packages,errors=[],sources=sources)


def inspect_keyless(folder):
    dump=inspect_dump(folder)
    if dump is not None:
        if any(p.is_file() and p.suffix.lower()=='.nup' for p in Path(folder).iterdir()):return dict(schema=1,status='multiple_sources',input_kind='dump')
        return dump
    return inspect_nup(folder)


def validate_keyless(folder, manifest):
    fresh=inspect_keyless(folder)
    if fresh is None or fresh.get('status')!='ready' or fresh!=manifest:
        raise ValueError('Game input changed or has no supported profile; identify it again.')
    return fresh
