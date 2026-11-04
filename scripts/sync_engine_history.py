#!/usr/bin/env python3
"""Refresh the offline engine history after integrating runtime changes."""
from pathlib import Path
import argparse
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def history():
    rows = subprocess.check_output(['git', '-C', str(ROOT), 'log', '-100',
                                    '--format=%H\t%aI\t%s'], text=True).splitlines()
    entries = []
    for row in rows:
        sha, date, title = row.split('\t', 2)
        paths = subprocess.check_output(['git', '-C', str(ROOT), 'diff-tree',
                                        '--no-commit-id', '--name-only', '-r', sha],
                                       text=True).splitlines()
        if not any(path.startswith(('dm/host/', 'dm/gfx/', 'dm/ios/', 'dm/mac/',
                                    'dm/tools/', 'dm/games/')) and not path.endswith('.md')
                   and '/tests/' not in path for path in paths):
            continue
        entries.append(dict(revision=sha, date=date, title=title))
        if len(entries) == 24:
            break
    if not entries:
        raise ValueError('Full git history is required to refresh engine notes.')
    upstream = json.loads((ROOT / 'docs/upstream-sync.json').read_text())['integrated_head']
    return dict(schema=1, revision=entries[0]['revision'], upstream=upstream, entries=entries)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    destination = ROOT / 'desktop/engine-history.json'
    value = json.dumps(history(), indent=2) + '\n'
    if args.check:
        if destination.read_text() != value:
            raise SystemExit('Engine history is stale; run scripts/sync_engine_history.py')
    else:
        destination.write_text(value)
    print('Engine history is current.')


if __name__ == '__main__':
    main()
