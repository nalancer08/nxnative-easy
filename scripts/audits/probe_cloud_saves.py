#!/usr/bin/env python3
"""Probe excluded upstream save code using synthetic files; never connect to iCloud.

Exit 1: a hazard reproduced. Exit 0: neither reproduced. Exit 2: inconclusive.
Requires macOS, clang and an already fetched, fully pinned upstream Git object.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upstream-ref', required=True, help='Full 40-character commit SHA; no fetch is performed')
    parser.add_argument('--output', required=True, type=Path, help='New output directory outside the checkout')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    if not re.fullmatch(r'[0-9a-fA-F]{40}', args.upstream_ref):
        parser.error('--upstream-ref must be a full commit SHA')
    if output == repo or repo in output.parents:
        parser.error('--output must be outside the checkout')
    if output.exists() or not output.parent.is_dir():
        parser.error('--output must be new and its parent must exist')
    if sys.platform != 'darwin' or not shutil.which('clang'):
        parser.error('This native fault probe requires macOS and clang')
    output.mkdir(mode=0o700)
    result = {'upstream_sha': args.upstream_ref.lower(), 'status': 'inconclusive', 'sources': {}}
    try:
        for name in ('save_sync.c', 'save_sync.h'):
            fetched = subprocess.run(
                ['git', 'show', f'{args.upstream_ref}:dm/host/{name}'],
                cwd=repo, capture_output=True, check=True, timeout=30)
            (output / name).write_bytes(fetched.stdout)
            result['sources'][name] = hashlib.sha256(fetched.stdout).hexdigest()
        shutil.copyfile(Path(__file__).with_name('cloud_save_probe.c'), output / 'probe.c')
        compiled = subprocess.run(
            ['clang', '-Wno-deprecated-declarations', str(output / 'probe.c'), '-o', str(output / 'probe')],
            capture_output=True, timeout=60)
        (output / 'compile.log').write_bytes(compiled.stdout + compiled.stderr)
        if compiled.returncode:
            raise RuntimeError('Compilation failed; see compile.log')
        ran = subprocess.run([str(output / 'probe'), str(output)], capture_output=True, timeout=20)
        (output / 'probe.log').write_bytes(ran.stdout + ran.stderr)
        if ran.returncode:
            raise RuntimeError(f'Fixture execution failed ({ran.returncode}); see probe.log')
        text = ran.stdout.decode('utf-8', errors='replace')
        mixed = re.search(r'Injected second-folder swap failure: rejected=([01]), mixed local save=([01])', text)
        replaced = re.search(r'Divergent older local upload: succeeded=([01]), replaced newer cloud=([01])', text)
        if not mixed or not replaced:
            raise RuntimeError('Expected probe observations are missing')
        result.update(
            status='observed',
            restore_rejected=bool(int(mixed[1])), mixed_local_save=bool(int(mixed[2])),
            upload_succeeded=bool(int(replaced[1])), older_local_replaced_newer_cloud=bool(int(replaced[2])))
        code = int(result['mixed_local_save'] or result['older_local_replaced_newer_cloud'])
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        result['error'] = str(error)
        code = 2
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    return code


if __name__ == '__main__':
    sys.exit(main())
