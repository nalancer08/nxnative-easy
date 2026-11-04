#!/usr/bin/env python3
"""Print bounded, actionable Xcode diagnostics, including linker symbol details."""
from pathlib import Path
import re
import sys


def diagnostics(path: Path) -> str:
    with path.open('rb') as stream:
        stream.seek(max(0, path.stat().st_size - 2 * 1024 * 1024))
        lines = stream.read().decode('utf-8', errors='replace').splitlines()
    result: list[str] = []
    remaining = 0
    for line in lines:
        if line.startswith('Undefined symbols for architecture'):
            remaining = 50
        if remaining or re.search(r'(?:^|\s)(?:ld:|clang:)?\s*error:', line):
            result.append(line[:1500])
            remaining = max(0, remaining - 1)
        if len(result) >= 65:
            break
    return '\n'.join(result) or 'Xcode failed; see the complete build.log for details.'


if __name__ == '__main__':
    try:
        print(diagnostics(Path(sys.argv[1])))
    except (OSError, IndexError) as error:
        print(f'Could not read Xcode diagnostics: {error}', file=sys.stderr)
        raise SystemExit(1) from error
