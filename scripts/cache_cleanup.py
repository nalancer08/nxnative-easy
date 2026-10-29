#!/usr/bin/env python3
"""Preview and explicitly delete only regenerable caches; originals/outputs/saves are protected."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
from build_ios import build_lock

PROTECTED={'.nsp','.xci','.nsz','.xcz','.ipa','.img','.keys','.zip','.app'}


def inventory(path):
    rows=[]
    def walk(folder):
        for entry in sorted(os.scandir(folder),key=lambda item:item.name):
            p=Path(entry.path);s=entry.stat(follow_symlinks=False)
            if stat.S_ISLNK(s.st_mode) or p.suffix.lower() in PROTECTED or p.name.lower() in {'save','save_device','partidas','romfs','exefs'}:
                raise ValueError('Protected or linked content in cache; nothing removed.')
            if not (stat.S_ISREG(s.st_mode) or stat.S_ISDIR(s.st_mode)):
                raise ValueError('Special files are not disposable caches.')
            rows.append((str(p.relative_to(path)),s.st_ino,s.st_size,s.st_mtime_ns,s.st_mode))
            if stat.S_ISDIR(s.st_mode):walk(p)
    root=path.lstat()
    if not stat.S_ISDIR(root.st_mode):raise ValueError('Cache is not a real directory.')
    walk(path)
    digest=hashlib.sha256(json.dumps([(root.st_ino,root.st_mtime_ns),*rows]).encode()).hexdigest()
    return digest,sum(row[2] for row in rows if stat.S_ISREG(row[4]))


def candidates(folder):
    folder=folder.expanduser().resolve(strict=True)
    result=[]
    for build in sorted(folder.iterdir()):
        if not re.fullmatch('[0-9A-Fa-f]{16}_build',build.name) or build.is_symlink() or not build.is_dir():continue
        for suffix in ('shader/cache','tmp'):
            path=build/suffix
            if not path.exists():continue
            if any(p.is_symlink() for p in [build,build/'shader',path]):continue
            try:digest,size=inventory(path)
            except (OSError,ValueError):continue
            result.append(dict(path=str(path.relative_to(folder)),digest=digest,bytes=size,inode=path.lstat().st_ino,device=path.lstat().st_dev))
    return result


def remove_tree(fd):
    # Never follow links; operate relative to held directory descriptors.
    for name in os.listdir(fd):
        if Path(name).suffix.lower() in PROTECTED or name.lower() in {'save','save_device','romfs','exefs','partidas'}:raise ValueError('Protected content appeared; stopped.')
        s=os.stat(name,dir_fd=fd,follow_symlinks=False)
        if stat.S_ISDIR(s.st_mode):
            child=os.open(name,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd)
            try:remove_tree(child)
            finally:os.close(child)
            os.rmdir(name,dir_fd=fd)
        elif stat.S_ISREG(s.st_mode):os.unlink(name,dir_fd=fd)
        else:raise ValueError('Cache changed during cleanup; stopped.')


def delete(folder,selected):
    folder=folder.resolve(strict=True)
    with build_lock(folder):
        current={item['path']:item for item in candidates(folder)}
        if not selected or len({item['path'] for item in selected})!=len(selected):raise ValueError('Select distinct cache entries.')
        for item in selected:
            if current.get(item['path'])!=item:raise ValueError('Caches changed; review again before deleting.')
        freed=0
        root=os.open(folder,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
        try:
            for item in selected:
                parts=Path(item['path']).parts;parent=os.dup(root)
                try:
                    for part in parts[:-1]:
                        child=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=parent);os.close(parent);parent=child
                    fd=os.open(parts[-1],os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=parent)
                    if (os.fstat(fd).st_ino,os.fstat(fd).st_dev)!=(item['inode'],item['device']):
                        os.close(fd);raise ValueError('Cache was replaced; stopped.')
                    try:remove_tree(fd)
                    finally:os.close(fd)
                    os.rmdir(parts[-1],dir_fd=parent);freed+=item['bytes']
                finally:os.close(parent)
        finally:os.close(root)
        return freed


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('folder',type=Path);parser.add_argument('--delete',type=Path,help='explicitly selected preview entries, JSON')
    args=parser.parse_args()
    if args.delete:
        selected=json.loads(args.delete.read_text());print(json.dumps({'freed':delete(args.folder,selected)}))
    else:print(json.dumps({'candidates':candidates(args.folder)}))


if __name__=='__main__':
    try:main()
    except (OSError,ValueError,KeyError,TypeError) as error:
        print(json.dumps({'error':str(error)}));sys.exit(1)
