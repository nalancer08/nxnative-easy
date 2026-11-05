#!/usr/bin/env python3
"""Refresh stable, first-parent engine numbers and offline source-build lookup."""
from pathlib import Path
import argparse
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ENGINE_PATHS = ('dm/host/', 'dm/gfx/', 'dm/ios/', 'dm/mac/', 'dm/tools/', 'dm/games/', 'dm/third_party/')


def history(root=ROOT):
    def git(*args):
        return subprocess.check_output(['git', '-C', str(root), *args], text=True)
    if git('rev-parse', '--is-shallow-repository').strip() != 'false':
        raise ValueError('Full git history is required; fetch the missing history first.')
    log = git('log', '--first-parent', '--reverse', '--diff-merges=first-parent',
              '--format=%x1e%H%x09%aI%x09%s', '--name-only', 'HEAD')
    policy = json.loads((root / 'desktop/engine-versioning.json').read_text())
    base = policy['base_revision']
    overrides = policy.get('overrides', {})
    def parsed(version):
        if not isinstance(version, str) or not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', version):
            raise ValueError('Engine versions must have three numeric components.')
        return tuple(int(part) for part in version.split('.'))
    parsed(policy['base_version'])
    entries, sources, versions = [], {}, {}
    number, version = 0, None
    for record in log.split('\x1e')[1:]:
        lines = record.splitlines()
        sha, date, title = lines[0].split('\t', 2)
        if any(path.startswith(ENGINE_PATHS) and not path.endswith('.md') and '/tests/' not in path
               for path in lines[1:]):
            number += 1
            if sha == base:
                version = policy['base_version']
            elif version is not None:
                major, minor, patch = parsed(version)
                version = f'{major}.{minor}.{patch + 1}'
            if sha in overrides:
                if version is None or parsed(overrides[sha]) < parsed(version):
                    raise ValueError('An engine version override must advance the version.')
                version = overrides[sha]
            if version is not None:
                versions[str(number)] = version
            entries.append(dict(number=number, version=version, revision=sha, date=date, title=title))
        if number:
            sources[sha] = number
    if not entries or version is None:
        raise ValueError('Full history including the engine version baseline is required.')
    upstream = json.loads((root / 'docs/upstream-sync.json').read_text())['integrated_head']
    return dict(schema=2, number=number, version=version, versions=versions, revision=entries[-1]['revision'], upstream=upstream,
                entries=list(reversed(entries[-24:])), sources=sources)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    destination = ROOT / 'desktop/engine-history.json'
    value = json.dumps(history(), indent=2) + '\n'
    if args.check:
        saved = json.loads(destination.read_text())
        current = json.loads(value)
        keys = ('schema', 'number', 'version', 'versions', 'revision', 'upstream', 'entries')
        if any(saved.get(key) != current[key] for key in keys) or not all(
                current['sources'].get(sha) == number for sha, number in saved.get('sources', {}).items()):
            raise SystemExit('Engine history is stale; run scripts/sync_engine_history.py')
    else:
        destination.write_text(value)
    print('Engine history is current.')


if __name__ == '__main__':
    main()
