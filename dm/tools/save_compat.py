#!/usr/bin/env python3
"""Platform-independent identity of a packed game's save-compatible content.

Hash logical RomFS/DLC bytes, original NSO build IDs and display version, never
rewritten binaries or shader output (those intentionally differ by platform).
No stat-only reuse: equal sizes/dates do not establish equal game content.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import romfs
from romfs_image import guest


def content_identity(root):
    root = romfs.Path(root)
    digest = hashlib.sha256()

    def visit(folder, prefix):
        children = [(guest(folder, p.name) if p.name.startswith('.dm-case-') else p.name, p) for p in folder.iterdir() if p.name != '.DS_Store']
        for name, p in sorted(children, key=lambda item: os.fsencode(item[0])):
            if p.is_symlink():
                raise ValueError('Save continuity cannot identify linked game content')
            relative = prefix + '/' + name
            if p.is_dir():
                digest.update(b'D' + os.fsencode(relative) + b'\0')
                visit(p, relative)
            elif p.is_file():
                h = hashlib.sha256()
                with p.open('rb') as stream:
                    for chunk in iter(lambda: stream.read(4 << 20), b''):
                        h.update(chunk)
                digest.update(b'F' + os.fsencode(relative) + b'\0' + h.digest())
            else:
                raise ValueError('Unknown game content entry')
    visit(root, '')
    return digest.hexdigest()


def manifest(title, version, patched, romfs_root, aoc=None, programs=()):
    modules = {}
    for p in sorted(Path(patched).glob('*.fixups.tsv')):
        match = re.search(r'^# BUILD_ID\s+([0-9a-fA-F]{32,64})\s*$', p.read_text(), re.M)
        if not match:
            raise ValueError(f'Missing original build ID: {p.name}')
        modules[p.name.split('.fixups.tsv')[0]] = match[1].lower()
    if not modules or not re.fullmatch(r'[0-9a-fA-F]{16}', title) or not version:
        raise ValueError('Missing game identity for save continuity')
    content = {'format': 1, 'title': title.upper(), 'version': version,
               'modules': modules, 'romfs': content_identity(romfs_root),
               'dlc': content_identity(aoc) if aoc and Path(aoc).is_dir() and any(p.name != '.DS_Store' for p in Path(aoc).iterdir()) else None}
    if programs:
        children=[];seen=set()
        for index, code, files in sorted(programs, key=lambda row:int(row[0])):
            index=int(index)
            if index in seen or not 1 <= index <= 15 or int(title,16) & 15:
                raise ValueError('Invalid program index for save continuity')
            seen.add(index)
            children.append({'index':index,'content':manifest(f'{int(title,16)+index:016X}',version,code,files)})
        content['programs']=children
    content['identity'] = hashlib.sha256(json.dumps(content, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return content


def program_inputs(path, title):
    programs=[]
    for row in Path(path).read_text().splitlines():
        if not row.strip() or row.startswith('#'):continue
        fields=row.split('\t')
        if len(fields)!=6:raise ValueError('Invalid multi-program input table')
        index,profile,patched,files,_,_=fields
        if int(profile,16)!=int(title,16)+int(index):raise ValueError('Mixed application programs')
        if int(index):programs.append((int(index),patched,files))
    return programs


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('title', 'version', 'patched', 'romfs', 'output'):
        p.add_argument('--' + name, required=True)
    p.add_argument('--aoc')
    p.add_argument('--programs', help='build_ipa.sh multi-program input table')
    a = p.parse_args()
    programs=program_inputs(a.programs,a.title) if a.programs else ()
    Path(a.output).write_text(json.dumps(manifest(a.title, a.version, a.patched, a.romfs, a.aoc, programs), sort_keys=True) + '\n')
