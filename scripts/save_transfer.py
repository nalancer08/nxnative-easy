#!/usr/bin/env python3
"""Checked save interchange. Publishes new files only; never writes active saves.

One bounded JSON request on stdin, one JSON reply. Game content, console access,
signing credentials and cloud authentication are deliberately outside this tool.
The archive codec interoperates with dm/host/save_archive.c, not Nintendo's NAND.
"""
from __future__ import annotations

from dataclasses import dataclass
import ctypes
import errno
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import stat
import struct
import sys
import tempfile
import time
from typing import Any
import unicodedata
import uuid
import zipfile

MAX_BYTES = 256 << 20
MAX_ENTRIES = 8192
MAX_HEADER = 65536
GUEST = 'org.d2rmobile.guest-name'
HEX_ID = re.compile(r'^[0-9a-f]{64}$')
TITLE = re.compile(r'^(?:01|04)[0-9A-F]{14}$')
ROOTS = ('save', 'save_device')


def guest_name(path):
    """CPython exposes os.getxattr on Linux, but not on macOS."""
    try:
        if sys.platform == 'darwin':
            libc = ctypes.CDLL(None, use_errno=True)
            function = libc.getxattr
            function.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_void_p,
                                 ctypes.c_size_t, ctypes.c_uint32, ctypes.c_int]
            function.restype = ctypes.c_ssize_t
            buffer = ctypes.create_string_buffer(1024)
            size = function(os.fsencode(path), GUEST.encode(), buffer, len(buffer), 0, 1)
            if size < 0:
                raise OSError(ctypes.get_errno(), 'metadata read failed')
            return buffer.raw[:size]
        return os.getxattr(path, GUEST, follow_symlinks=False)
    except OSError as error:
        require(error.errno in (getattr(errno, 'ENOATTR', errno.ENODATA), errno.ENODATA,
                                errno.ENOTSUP), 'unreadable_metadata')
        return b''


class TransferError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise TransferError(message)


def safe_path(name):
    require(isinstance(name, str) and 0 < len(name.encode('utf-8')) < 2048,
            'invalid_path')
    require(not any(c in name for c in ('\\', '\x00', ':')), 'invalid_path')
    parts = name.split('/')
    require(all(p and p not in ('.', '..') and not p.endswith((' ', '.'))
                for p in parts), 'invalid_path')
    return parts


def save_name(name):
    parts = safe_path(name)
    require(not any(p.lower() in ('romfs', 'exefs', 'base', 'save.work', 'save.new',
                                  'save_device.work', 'save_device.new') for p in parts),
            'not_committed_save_data')
    require(Path(name).suffix.lower() not in ('.keys', '.nsp', '.xci', '.nsz', '.xcz',
                                              '.nca', '.nso', '.ipa', '.exe', '.dll'),
            'not_save_data')
    return parts


def read_file(path, limit=MAX_BYTES + MAX_HEADER + 160):
    path = Path(path)
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        before = os.fstat(stream.fileno())
        require(stat.S_ISREG(before.st_mode) and before.st_size <= limit,
                'invalid_or_large_file')
        data = stream.read(limit + 1)
        after = os.fstat(stream.fileno())
        require(len(data) == before.st_size and before.st_mtime_ns == after.st_mtime_ns
                and before.st_size == after.st_size, 'source_changed')
        return data


def dictionary(data):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, 'duplicate_metadata')
            result[key] = value
        return result
    require(len(data) <= MAX_HEADER, 'large_metadata')
    result = json.loads(data, object_pairs_hook=unique)
    require(isinstance(result, dict), 'invalid_metadata')
    return result


@dataclass(frozen=True)
class Entry:
    path: str
    data: bytes | None
    guest: bytes = b''
    modified: int = 0


def check_entries(entries):
    require(0 < len(entries) <= MAX_ENTRIES, 'empty_or_large_save')
    seen, total, files = {}, 0, 0
    for item in entries:
        parts = save_name(item.path)
        require(parts[0] in ROOTS and len(parts) > 1, 'invalid_save_root')
        require(item.path not in seen, 'duplicate_path')
        require(len(item.guest) <= 1023, 'invalid_guest_name')
        require(not parts[-1].startswith('.dm-case-') or item.guest, 'missing_guest_metadata')
        if item.guest:
            require(len(safe_path(item.guest.decode('utf-8'))) == 1, 'invalid_guest_name')
        for index in range(2, len(parts)):
            parent = '/'.join(parts[:index])
            require(parent in seen and seen[parent] is None, 'missing_parent')
        seen[item.path] = item.data
        if item.data is not None:
            total += len(item.data)
            files += 1
    require(files > 0 and total <= MAX_BYTES, 'empty_or_large_save')
    return files, total


def inner_archive(entries, title):
    check_entries(entries)
    digest, payload = hashlib.sha256(), bytearray()
    for item in entries:
        name = item.path.encode('utf-8')
        size = len(item.data) if item.data is not None else 0
        head = struct.pack('<BBHHHQq', 2 if item.data is not None else 1,
                           0, len(name), len(item.guest), 0, size, item.modified)
        content = item.data or b''
        digest.update(head[:16] + name + item.guest + content)
        payload.extend(head + name + item.guest + content)
    content_hash = digest.hexdigest()[:32]
    header = struct.pack('<8sII32sq24s64s', b'DMSYNC1\n', 1, len(entries),
                         content_hash.encode(), int(time.time()), title.encode(), b'Save transfer')
    return header + payload + b'DMSYNCE\n', content_hash


def decode_inner(data):
    require(152 <= len(data) <= MAX_BYTES + (MAX_ENTRIES * 3100), 'invalid_archive')
    stream = io.BytesIO(data)
    magic, version, count, wanted, _, raw_title, _ = struct.unpack('<8sII32sq24s64s', stream.read(144))
    title = raw_title.split(b'\0')[0].decode('ascii')
    require(magic == b'DMSYNC1\n' and version == 1 and TITLE.fullmatch(title)
            and 0 < count <= MAX_ENTRIES, 'invalid_archive')
    entries, digest = [], hashlib.sha256()
    for _ in range(count):
        head = stream.read(24)
        require(len(head) == 24, 'truncated_archive')
        kind, reserved, path_size, guest_size, reserved2, size, modified = struct.unpack('<BBHHHQq', head)
        require(kind in (1, 2) and not reserved and not reserved2 and 0 < path_size < 2048
                and guest_size <= 1023 and size <= MAX_BYTES and (kind == 2 or size == 0),
                'invalid_archive_entry')
        name, guest, content = stream.read(path_size), stream.read(guest_size), stream.read(size)
        require(len(name) == path_size and len(guest) == guest_size and len(content) == size,
                'truncated_archive')
        digest.update(head[:16] + name + guest + content)
        entries.append(Entry(name.decode('utf-8'), content if kind == 2 else None, guest, modified))
    require(stream.read() == b'DMSYNCE\n' and digest.hexdigest()[:32] == wanted.decode('ascii'),
            'checksum_mismatch')
    check_entries(entries)
    return title, entries, digest.hexdigest()[:32]


def read_revision(path, verify=True):
    path = Path(path)
    require(path.suffix == '.nxsave' and HEX_ID.fullmatch(path.stem), 'invalid_revision_name')
    data = read_file(path)
    require(len(data) > 8, 'invalid_revision')
    length = struct.unpack('<I', data[:4])[0]
    require(0 < length <= MAX_HEADER and len(data) > length + 4, 'invalid_revision')
    metadata = dictionary(data[4:4 + length])
    require(metadata.get('format') == 1 and TITLE.fullmatch(str(metadata.get('title', '')))
            and metadata.get('player') == 'default'
            and HEX_ID.fullmatch(str(metadata.get('compat', '')))
            and isinstance(metadata.get('parents'), list) and len(metadata['parents']) <= 1024
            and all(isinstance(p, str) and HEX_ID.fullmatch(p) and p != path.stem for p in metadata['parents'])
            and isinstance(metadata.get('device'), str) and len(metadata['device']) <= 200
            and (metadata.get('gameVersion') is None or isinstance(metadata['gameVersion'], str))
            and isinstance(metadata.get('date'), (float, int))
            and math.isfinite(metadata['date']) and 0 <= metadata['date'] <= 4102444800,
            'invalid_revision_metadata')
    entries = []
    if verify:
        require(hashlib.sha256(data).hexdigest() == path.stem, 'checksum_mismatch')
        title, entries, digest = decode_inner(data[4 + length:])
        require(title == metadata['title'] and digest == metadata.get('hash'), 'checksum_mismatch')
    return metadata, entries


def read_directory(path, kind):
    root = Path(path)
    require(root.is_dir() and not root.is_symlink(), 'invalid_folder')
    if any((root / name).is_dir() for name in ROOTS):
        kind = 'bundle'
    entries = []
    total = 0
    def visit(folder, prefix):
        nonlocal total
        for child in sorted(folder.iterdir(), key=lambda p: os.fsencode(p.name)):
            if child.name == '.DS_Store':
                continue
            require(not child.is_symlink(), 'symlink_refused')
            relative = prefix + '/' + child.name
            save_name(relative)
            guest = guest_name(child)
            require(not child.name.startswith('.dm-case-') or guest, 'missing_guest_metadata')
            if child.is_dir():
                entries.append(Entry(relative, None, guest))
                visit(child, relative)
            else:
                total += child.stat().st_size
                require(total <= MAX_BYTES, 'large_save')
                entries.append(Entry(relative, read_file(child, MAX_BYTES), guest, int(child.stat().st_mtime)))
            require(len(entries) <= MAX_ENTRIES, 'large_save')
    if kind == 'bundle':
        require(all(p.name in ROOTS or p.name in ('.DS_Store', 'nxnative-save-export.json')
                    for p in root.iterdir()), 'choose_save_folder')
        for name in ROOTS:
            if (root / name).exists():
                require((root / name).is_dir() and not (root / name).is_symlink(), 'invalid_save_root')
                visit(root / name, name)
    else:
        require(kind in ('account', 'device'), 'choose_save_kind')
        visit(root, 'save' if kind == 'account' else 'save_device')
    check_entries(entries)
    return entries


def read_zip(path, kind):
    # A ZIP is read in memory with bounded decompressed sizes, never extractall().
    with zipfile.ZipFile(io.BytesIO(read_file(path))) as archive:
        infos = archive.infolist()
        require(0 < len(infos) <= MAX_ENTRIES + 1, 'large_save')
        entries, names, total = [], set(), 0
        bundled = any(p.filename.startswith(('save/', 'save_device/')) for p in infos)
        for info in infos:
            name = info.filename.rstrip('/')
            require(name not in names, 'duplicate_path')
            names.add(name)
            require(not info.flag_bits & 1 and not stat.S_ISLNK(info.external_attr >> 16), 'invalid_zip_entry')
            if name in ('.DS_Store', 'nxnative-save-export.json'):
                require(info.file_size <= MAX_HEADER, 'large_metadata')
                continue
            save_name(name)
            require(info.file_size <= MAX_BYTES and (not info.is_dir() or info.file_size == 0), 'large_save')
            total += info.file_size
            require(total <= MAX_BYTES, 'large_save')
            prefix = '' if bundled else ('save/' if kind == 'account' else 'save_device/')
            require(bundled or kind in ('account', 'device'), 'choose_save_kind')
            entries.append(Entry(prefix + name, None if info.is_dir() else archive.read(info)))
    # ZIPs need not store explicit parent directories; rebuild them deterministically.
    found = {item.path: item for item in entries}
    for item in list(entries):
        parts = safe_path(item.path)
        if len(parts) == 1:
            require(item.data is None and parts[0] in ROOTS, 'invalid_save_root')
            found.pop(item.path, None)
        for index in range(2, len(parts)):
            parent = '/'.join(parts[:index])
            if parent not in found:
                found[parent] = Entry(parent, None)
    result = sorted(found.values(), key=lambda item: item.path.encode())
    check_entries(result)
    return result


def source(path, kind='account'):
    path = Path(path)
    if path.suffix == '.nxsave':
        metadata, entries = read_revision(path)
    elif path.is_dir():
        entries, metadata = read_directory(path, kind), {}
    else:
        require(path.suffix.lower() == '.zip', 'unsupported_save')
        entries, metadata = read_zip(path, kind), {}
    return metadata, entries


def compatibility(game):
    require(TITLE.fullmatch(str(game.get('title', ''))), 'choose_game')
    manifests = []
    if game.get('mac'):
        path = Path(game['mac']) / 'Contents/Resources/dm/save-compat.json'
        if path.exists():
            manifests.append(dictionary(read_file(path, MAX_HEADER)))
    if game.get('ipa'):
        with zipfile.ZipFile(game['ipa']) as archive:
            names = [n for n in archive.namelist() if re.fullmatch(r'Payload/[^/]+\.app/dm/save-compat\.json', n)]
            require(len(names) <= 1, 'invalid_compatibility')
            if names:
                require(archive.getinfo(names[0]).file_size <= MAX_HEADER, 'large_metadata')
                manifests.append(dictionary(archive.read(names[0])))
    require(manifests, 'rebuild_for_save_transfer')
    for manifest in manifests:
        identity = manifest.get('identity')
        unsigned = {key: value for key, value in manifest.items() if key != 'identity'}
        digest = hashlib.sha256(json.dumps(unsigned, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        require(manifest.get('format') == 1 and manifest.get('title') == game['title']
                and HEX_ID.fullmatch(str(identity)) and digest == identity, 'invalid_compatibility')
    require(all(x['identity'] == manifests[0]['identity'] for x in manifests), 'platform_content_mismatch')
    return manifests[0]


def writable_destination(path):
    """Copies belong outside source code and the runtime's active save tree."""
    root = Path(path)
    require(root.is_dir() and not root.is_symlink(), 'invalid_destination')
    resolved = root.resolve()
    protected = (Path(__file__).resolve().parents[1],
                 Path.home() / 'Library/Application Support/nxnative')
    require(not any(resolved == folder or folder in resolved.parents for folder in protected),
            'protected_destination')
    require(not any(part in ('save', 'save_device', 'save.work', 'save.new',
                             'save_device.work', 'save_device.new') for part in resolved.parts),
            'protected_destination')
    return root


def publish_new(path, data):
    """Hard-link publication never overwrites an existing backup/revision."""
    path = Path(path)
    require(path.parent.is_dir() and not path.parent.is_symlink(), 'invalid_destination')
    with tempfile.NamedTemporaryFile(prefix='.nxe-save-', dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        except BaseException:
            temporary.unlink(missing_ok=True)
            raise
    try:
        os.link(temporary, path, follow_symlinks=False)
    finally:
        temporary.unlink(missing_ok=True)


def inspect(path, kind='account'):
    metadata, entries = source(path, kind)
    files, size = check_entries(entries)
    return dict(title=metadata.get('title'), version=metadata.get('gameVersion'),
                device=metadata.get('device'), files=files, bytes=size,
                fingerprint=hashlib.sha256(inner_archive(entries, '0100000000000000')[0][144:]).hexdigest(),
                roots=[root for root in ROOTS if any(e.path.startswith(root + '/') for e in entries)])


def cloud_list(folder) -> dict[str, Any]:
    root = Path(folder) / 'nxnative-saves-v1'
    if not root.exists():
        return dict(revisions=[], pending=0, invalid=0)
    require(root.is_dir() and not root.is_symlink(), 'invalid_cloud_folder')
    result, pending, invalid = [], 0, 0
    directories = sorted(root.iterdir())
    require(len(directories) <= 1024, 'large_history')
    for directory in directories:
        if not TITLE.fullmatch(directory.name) or not directory.is_dir() or directory.is_symlink():
            continue
        paths = sorted(directory.iterdir())
        require(len(paths) <= 4096 and len(result) + len(paths) <= 8192, 'large_history')
        for path in paths:
            if path.name.endswith('.nxsave.icloud'):
                pending += 1
                continue
            if path.suffix != '.nxsave':
                continue
            try:
                # Listing reads only the header. A chosen revision is fully checked before use.
                require(HEX_ID.fullmatch(path.stem) and not path.is_symlink(), 'invalid_revision_name')
                fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
                with os.fdopen(fd, 'rb') as stream:
                    require(stat.S_ISREG(os.fstat(stream.fileno()).st_mode), 'invalid_revision')
                    prefix = stream.read(4)
                    require(len(prefix) == 4, 'invalid_revision')
                    length = struct.unpack('<I', prefix)[0]
                    require(0 < length <= MAX_HEADER, 'invalid_revision')
                    metadata = dictionary(stream.read(length))
                require(metadata.get('format') == 1 and metadata.get('title') == directory.name
                        and metadata.get('player') == 'default'
                        and isinstance(metadata.get('date'), (float, int))
                        and math.isfinite(metadata['date']) and 0 <= metadata['date'] <= 4102444800
                        and isinstance(metadata.get('device'), str), 'invalid_metadata')
                result.append(dict(id=path.stem, title=directory.name, path=str(path),
                                   date=metadata['date'], device=metadata['device'][:200],
                                   version=str(metadata.get('gameVersion', ''))[:80]))
            except (OSError, ValueError, struct.error, UnicodeError):
                invalid += 1
    return dict(revisions=sorted(result, key=lambda item: item['date'], reverse=True),
                pending=pending, invalid=invalid)


def import_cloud(request):
    require(request.get('confirmed_game') is True, 'confirm_game_and_version')
    manifest = compatibility(request['game'])
    metadata, entries = source(request['source'], request.get('kind', 'account'))
    preview = inspect(request['source'], request.get('kind', 'account'))
    require(preview['fingerprint'] == request.get('fingerprint'), 'source_changed')
    require(hashlib.sha256(inner_archive(entries, '0100000000000000')[0][144:]).hexdigest()
            == preview['fingerprint'], 'source_changed')
    if metadata:
        require(metadata['title'] == manifest['title'] and metadata['compat'] == manifest['identity'],
                'different_game_content')
    else:
        # Learn the engine's committed layout from a checked first save, not from
        # a console folder name. Device-only games use the primary root too.
        baseline_roots = set()
        for revision in cloud_list(request['cloud'])['revisions']:
            if revision['title'] != manifest['title']:
                continue
            baseline, saved = read_revision(revision['path'])
            if baseline['compat'] == manifest['identity']:
                baseline_roots.update(e.path.split('/')[0] for e in saved)
        require(baseline_roots, 'create_first_cloud_save')
        incoming_roots = {e.path.split('/')[0] for e in entries}
        if incoming_roots == {'save_device'} and baseline_roots == {'save'}:
            entries = [Entry('save/' + e.path.split('/', 1)[1], e.data, e.guest, e.modified) for e in entries]
            incoming_roots = {'save'}
        require(baseline_roots <= incoming_roots, 'incomplete_save_pair')
        require(baseline_roots == incoming_roots, 'wrong_save_layout')
    payload, content_hash = inner_archive(entries, manifest['title'])
    header = dict(format=1, title=manifest['title'], player='default', compat=manifest['identity'],
                  gameVersion=manifest['version'], parents=[], hash=content_hash,
                  device='Imported backup', date=time.time(), nonce=str(uuid.uuid4()),
                  origin='manual-save-import', compatibilityVerification='player-confirmed')
    data = json.dumps(header, sort_keys=True, separators=(',', ':')).encode()
    complete = struct.pack('<I', len(data)) + data + payload
    revision = hashlib.sha256(complete).hexdigest()
    root = writable_destination(request['cloud'])
    base = root / 'nxnative-saves-v1'
    base.mkdir(exist_ok=True)
    require(not base.is_symlink(), 'invalid_cloud_folder')
    destination = base / manifest['title']
    destination.mkdir(exist_ok=True)
    require(not destination.is_symlink(), 'invalid_cloud_folder')
    path = destination / (revision + '.nxsave')
    publish_new(path, complete)
    read_revision(path)
    return dict(path=str(path), revision=revision, files=preview['files'],
                status='published_new_branch', delivery='waiting_for_icloud')


def export_switch(request):
    metadata, entries = source(request['source'], request.get('kind', 'account'))
    require(metadata.get('title') == request.get('title'), 'different_game')
    require(request.get('confirmed_console_requirement') is True, 'console_restore_tool_required')
    preview = inspect(request['source'], request.get('kind', 'account'))
    require(preview['fingerprint'] == request.get('fingerprint'), 'source_changed')
    require(hashlib.sha256(inner_archive(entries, '0100000000000000')[0][144:]).hexdigest()
            == preview['fingerprint'], 'source_changed')
    root = writable_destination(request['destination'])
    # A new package is a sibling, not a replacement for any JKSV backup.
    name = 'Easy-' + metadata['title'] + '-' + time.strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:6]
    temporary = Path(tempfile.mkdtemp(prefix='.nxe-save-', dir=root))
    destination = root / name
    try:
        mappings, output_keys = {}, set()
        for item in entries:
            parts = safe_path(item.path)
            physical_parent = '/'.join(parts[:-1])
            logical_name = item.guest.decode() if item.guest else parts[-1]
            logical_parent = mappings.get(physical_parent, physical_parent)
            relative = logical_parent + '/' + logical_name
            mappings[item.path] = relative
            key = unicodedata.normalize('NFC', relative).casefold()
            require(key not in output_keys, 'case_collision_for_sd')
            output_keys.add(key)
            target = temporary / relative
            if item.data is None:
                target.mkdir(parents=True, exist_ok=False)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with target.open('xb') as stream:
                    stream.write(item.data)
                    stream.flush()
                    os.fsync(stream.fileno())
                require(hashlib.sha256(read_file(target)).digest() == hashlib.sha256(item.data).digest(), 'copy_failed')
        report = dict(format=1, title=metadata['title'], gameVersion=metadata.get('gameVersion'),
                      sourceRevision=Path(request['source']).stem, roots=preview['roots'],
                      status='backup_prepared_not_restored', files=preview['files'],
                      requirement='Restore each save root with a compatible console save manager. A stock console cannot load this folder from its SD card.')
        (temporary / 'transfer.json').write_text(json.dumps(report, indent=2) + '\n')
        (temporary / 'START HERE.txt').write_text(
            'Your original and cloud saves were kept. This folder is not installed on a console.\n'
            '1. Keep a fresh console backup before restoring anything.\n'
            '2. Use the same game, version, DLC and correct console user.\n'
            '3. The primary root is save/. Some games also have save_device/. A device-only game uses save/ too. Match the save type shown in your original console backup; never merge the roots.\n'
            '4. Copy only the contents of the matching root into a NEW backup made by your save manager, then restore it on the console.\n'
            'Switch 1 requires a compatible save manager. Switch 2 access depends on an independently configured compatible tool/session.\n'
            'An unmodified console does not import arbitrary SD saves. Nintendo Switch Online is not connected to Easy.\n')
        (temporary / 'EMPIEZA AQUI.txt').write_text(
            'Tu partida original y las copias de iCloud se conservan. Este respaldo no está instalado en una consola.\n'
            '1. Conserva primero un respaldo nuevo hecho en la consola.\n'
            '2. Comprueba el juego, versión, DLC, usuario y tipo de partida.\n'
            '3. save/ es la carpeta principal; algunos juegos también usan save_device/. Un juego con sólo datos compartidos también puede usar save/. Nunca mezcles las carpetas.\n'
            '4. Copia sólo los archivos de la carpeta correspondiente dentro de un NUEVO respaldo de tu gestor de partidas. Restaura ese respaldo desde la consola.\n'
            'Una Switch sin modificar no carga estas carpetas por ponerlas en la SD. Switch 1 necesita un gestor compatible. Switch 2 necesita una vía de acceso compatible configurada por separado. Easy no modifica la consola ni conecta con la nube de Nintendo.\n')
        require(not destination.exists(), 'destination_exists')
        os.rename(temporary, destination)
        return dict(path=str(destination), files=preview['files'], status='backup_prepared_not_restored')
    except BaseException:
        # Retain a failed partial on the chosen volume for inspection; never report success.
        raise


def local_backup(request):
    destination = Path(request['destination'])
    require(destination.suffix == ('.nxsave' if request.get('op') == 'backup_revision' else '.zip'), 'invalid_destination')
    writable_destination(destination.parent)
    require(not destination.exists(), 'destination_exists')
    if request.get('op') == 'backup_revision':
        preview = inspect(request['source'])
        require(preview['fingerprint'] == request.get('fingerprint'), 'source_changed')
        data = read_file(request['source'])
        require(hashlib.sha256(data).hexdigest() == Path(request['source']).stem, 'source_changed')
    else:
        require(request.get('confirmed_closed') is True, 'close_game_first')
        title = request.get('title')
        require(TITLE.fullmatch(str(title)), 'choose_game')
        root = Path.home() / 'Library/Application Support/nxnative' / title
        require(not root.is_symlink(), 'symlink_refused')
        def committed():
            result = []
            for name, kind in [('save', 'account'), ('save_device', 'device')]:
                if (root / name).exists():
                    result += read_directory(root / name, kind)
            check_entries(result)
            require(not any(item.guest for item in result), 'missing_guest_metadata')
            return result
        entries = committed()
        archive = io.BytesIO()
        with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as output:
            for entry in entries:
                output.writestr(entry.path + ('/' if entry.data is None else ''), entry.data or b'')
            output.writestr('nxnative-save-export.json', json.dumps(dict(format=1, title=title, origin='Mac committed backup')))
        require(inner_archive(entries, title)[0][144:] == inner_archive(committed(), title)[0][144:], 'source_changed')
        data = archive.getvalue()
    publish_new(destination, data)
    require(hashlib.sha256(read_file(destination)).digest() == hashlib.sha256(data).digest(), 'copy_failed')
    return dict(path=str(destination), status='local_backup_ready')


def dispatch(request):
    op = request.get('op')
    if op in ('backup_revision', 'backup_mac'):
        return local_backup(request)
    if op == 'list':
        return cloud_list(request['cloud'])
    if op == 'inspect':
        return inspect(request['source'], request.get('kind', 'account'))
    if op == 'compatibility':
        return compatibility(request['game'])
    if op == 'import':
        return import_cloud(request)
    if op == 'export':
        return export_switch(request)
    raise TransferError('unknown_operation')


if __name__ == '__main__':
    try:
        request_data = sys.stdin.buffer.read(MAX_HEADER + 1)
        result = dispatch(dictionary(request_data))
        print(json.dumps(dict(ok=True, result=result)))
    except (OSError, ValueError, KeyError, TypeError, struct.error, zipfile.BadZipFile, RuntimeError) as error:
        code = str(error) if isinstance(error, TransferError) else 'save_operation_failed'
        print(json.dumps(dict(ok=False, error=code)))
        sys.exit(1)
