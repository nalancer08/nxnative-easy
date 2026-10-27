#!/usr/bin/env python3
"""Create a consistent, portable SQLite backup without changing the save API database."""
import argparse
import os
from pathlib import Path
import sqlite3
import tempfile
from contextlib import closing

ROOT=Path(__file__).resolve().parents[1]


def backup(source,destination):
    source=Path(source).expanduser().resolve(strict=True)
    destination=Path(destination).expanduser().absolute()
    parent=destination.parent.resolve(strict=True)
    destination=parent/destination.name
    if ROOT==source or ROOT in source.parents or ROOT==parent or ROOT in parent.parents:
        raise ValueError('Keep private databases and backups outside the source checkout.')
    if destination.exists() or destination.is_symlink():
        raise FileExistsError('The destination already exists; it was preserved.')
    with tempfile.TemporaryDirectory(prefix='.nxnative-save-backup-',dir=parent) as temporary:
        staged=Path(temporary)/'saves.sqlite3'
        # Read-only URI refuses a missing source. SQLite backup includes committed WAL
        # transactions; copying only saves.sqlite3 could silently lose those writes.
        with closing(sqlite3.connect(source.as_uri()+'?mode=ro',uri=True,timeout=15)) as origin:
            if len(origin.execute("SELECT name FROM sqlite_master WHERE type='table' AND name IN ('revisions','heads','shares')").fetchall())!=3:
                raise ValueError('Not a save API database.')
            with closing(sqlite3.connect(staged)) as target:
                origin.backup(target)
                if target.execute('PRAGMA integrity_check').fetchall()!=[('ok',)]:
                    raise ValueError('Backup integrity check failed.')
        os.chmod(staged,0o600)
        with staged.open('rb') as stream:os.fsync(stream.fileno())
        # Exclusive publication: never overwrite an existing backup, even in a race.
        os.link(staged,destination)
    return destination


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True,help='new private backup path outside the checkout; parent must exist')
    args=parser.parse_args()
    try:backup(args.source,args.output)
    except (OSError,ValueError,sqlite3.Error) as error:parser.exit(1,f'Backup failed: {error}\n')
    print('Backup verified. Keep it private: it contains save snapshots and sharing records.')


if __name__=='__main__':main()
