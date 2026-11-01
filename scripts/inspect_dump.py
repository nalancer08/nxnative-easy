"""Read a decrypted dump without packing it; preserve a checked source identity."""
import hashlib
import json
from pathlib import Path

from pack_dump import is_dump, scan

REPO = Path(__file__).resolve().parents[1]
EXTENSIONS = {'.nsp', '.xci', '.nsz', '.xcz'}


def source_identity(folder):
    """Bounded output for a large tree; never follow links into another folder."""
    digest = hashlib.sha256()
    count = 0
    for name in ('base', 'updates', 'dlc'):
        root = folder / name
        if root.is_symlink():
            raise ValueError('Dump input contains a symbolic link.')
        if not root.exists():
            continue
        for path in [root, *sorted(root.rglob('*'))]:
            if path.is_symlink() or not (path.is_file() or path.is_dir()):
                raise ValueError('Dump input contains a link or special file.')
            stat = path.stat()
            digest.update(json.dumps([path.relative_to(folder).as_posix(), path.is_dir(), stat.st_size,
                                      stat.st_mtime_ns], separators=(',', ':')).encode())
            if path.is_file():
                count += 1
                # Validate executable content even if somebody preserved size/time.
                if 'exefs' in path.relative_to(folder).parts:
                    with path.open('rb') as stream:
                        while chunk := stream.read(1024 * 1024):
                            digest.update(chunk)
    return {'digest': digest.hexdigest(), 'files': count}


def inspect_dump(folder):
    folder = Path(folder).resolve()
    if folder == REPO or REPO in folder.parents:
        return {'schema': 1, 'status': 'invalid_location'}
    if not is_dump(folder):
        return None
    if any(p.is_file() and p.suffix.lower() in EXTENSIONS for p in folder.iterdir()):
        return {'schema': 1, 'status': 'multiple_sources', 'input_kind': 'dump'}
    before = source_identity(folder)
    app, updates, dlc = scan(folder)
    title = f'{app:016X}'
    profile = REPO / 'dm/games' / title / 'game.tsv'
    rows = [line.split('\t') for line in profile.read_text().splitlines()] if profile.is_file() else []
    name = next((row[1] for row in rows if len(row) > 1 and row[0] == 'name'), None)

    def package(version, source, kind):
        code = source / 'exefs/main'
        npdm = source / 'exefs/main.npdm'
        if not code.is_file() or not npdm.is_file() or not (source / 'romfs').is_dir():
            raise ValueError('Dump has incomplete executable or RomFS folders.')
        from pack_dump import program_id
        if program_id(npdm) != app:
            raise ValueError('Dump contains mixed game identities.')
        with code.open('rb') as stream:
            header = stream.read(0x100)
        if len(header) != 0x100 or header[:4] != b'NSO0':
            raise ValueError('Dump has an invalid NSO header.')
        build = header[0x40:0x60].hex()
        display = next((row[2] for row in rows if len(row) > 2 and row[0] == 'build'
                        and any(token.startswith('main=') and build.startswith(token[5:].lower()) for token in row[3:])), None)
        if display == f'v{version}': display = None
        return dict(file=source.relative_to(folder).as_posix(), title_id=title, kind=kind,
                    version=version, name=name, display_version=display, build_id=build)

    base = package(0, folder / 'base', 'base')
    versions = [package(v, path, 'update') for v, path in sorted(updates.items(), reverse=True)]
    selected = versions[0] if versions else base
    sources = source_identity(folder)
    if before != sources:
        return {'schema': 1, 'status': 'files_changed', 'input_kind': 'dump'}
    return dict(schema=1, status='ready' if profile.is_file() else 'profile_missing', input_kind='dump',
                platform='switch2' if title.startswith('04') else 'switch', title_id=title,
                name=name, display_version=selected['display_version'], version=selected['version'],
                selected_file=selected['file'], base_version=base['display_version'], updates=versions,
                dlc=[dict(file=str(path.relative_to(folder)), title_id=title, kind='dlc', version=0,
                          content_id=f'{tid:016X}') for tid, path in sorted(dlc.items())],
                packages=[base, *versions], errors=[], sources=sources)


def validate_dump(folder, manifest):
    fresh = inspect_dump(folder)
    if fresh is None or fresh.get('status') != 'ready' or fresh != manifest:
        raise ValueError('Dump changed or has no supported profile; identify the folder again.')
    return fresh
