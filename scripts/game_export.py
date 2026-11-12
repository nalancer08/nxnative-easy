"""Publish one verified, named export per platform without accumulating full IPAs."""
from contextlib import contextmanager, ExitStack
from pathlib import Path
import ctypes
import fcntl
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unicodedata
import uuid

MARKER = '.nxnative-export.json'
PREPARING = '.nxnative-preparing'


def safe_name(value):
    value = unicodedata.normalize('NFC', str(value))
    value = re.sub(r'[\x00-\x1f/\\:*?"<>|]', ' - ', value)
    value = ' '.join(value.split()).strip(' .')[:96].rstrip(' .')
    return value if value and value not in {'.', '..'} else 'Game'


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        while block := stream.read(8 * 1024 * 1024):
            h.update(block)
    return h.hexdigest()


def atomic_json(path, value):
    atomic_bytes(path, (json.dumps(value,indent=2)+'\n').encode())


def atomic_bytes(path, value):
    path = Path(path)
    temp = path.with_name('.' + path.name + '.' + uuid.uuid4().hex + '.tmp')
    try:
        with temp.open('xb') as stream:
            os.chmod(temp,stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600)
            stream.write(value)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
    finally:
        temp.unlink(missing_ok=True)


def manifest(folder):
    """Content hashes also detect user additions/edits before replacing an export."""
    result = {}
    for base, dirs, files in os.walk(folder, followlinks=False):
        for name in dirs + files:
            p = Path(base) / name
            if p.is_symlink():
                # Signed Mac apps may contain internal framework symlinks.
                if not p.resolve().is_relative_to(folder.resolve()):
                    raise ValueError('Export contains an external symbolic link.')
                result[str(p.relative_to(folder))] = {'link': os.readlink(p)}
            elif p.is_dir():
                result[str(p.relative_to(folder))] = {'directory': True}
        for name in files:
            p = Path(base) / name
            if (p.parent == Path(folder) and p.name in {MARKER, PREPARING}) or p.name == '.DS_Store' or p.is_symlink():
                continue
            if not p.is_file():
                raise ValueError('Export contains a special file.')
            result[str(p.relative_to(folder))] = {'bytes': p.stat().st_size, 'sha256': digest(p)}
    return result


def export_location(game, platform, info, parent=None, previous=None):
    game = Path(game).resolve(strict=True)
    previous = previous or {}
    parent = Path(parent or previous.get('export_parent') or game.parent / 'nxnative Games').expanduser().resolve()
    repo = Path(__file__).resolve().parents[1]
    if parent == repo or repo in parent.parents or not parent.is_absolute() or any((p/'.git').exists() for p in [parent,*parent.parents]):
        raise ValueError('Choose an export destination outside the source repository.')
    title = safe_name(info.get('CFBundleDisplayName') or info.get('CFBundleName') or game.name)
    # A renamed title should keep its existing managed destination by default.
    old = previous.get('export_folder')
    if old and Path(old).parent.parent == parent and not parent.is_symlink():
        folder = Path(old)
    else:
        folder = parent / title / ('Mac' if platform == 'mac' else 'iPhone - iPad')
    if folder.is_symlink() or any(p.is_symlink() for p in [folder.parent, parent]):
        raise ValueError('Choose a real export folder, not a symbolic link.')
    return folder, title, parent


@contextmanager
def staging(folder):
    folder = Path(folder)
    parent_existed = folder.parent.exists()
    folder.parent.mkdir(parents=True, exist_ok=True)
    path = Path(tempfile.mkdtemp(prefix='.' + folder.name + '-preparing-', dir=folder.parent))
    token = uuid.uuid4().hex
    (path / PREPARING).write_text(token)
    completed = False
    try:
        yield path
        completed = True
    finally:
        # After a successful swap, this path is the previous managed export.
        # If rollback itself failed, never delete that previous export here.
        owned_new = (path / PREPARING).is_file() and (path / PREPARING).read_text() == token
        if path.exists() and (completed or owned_new):
            shutil.rmtree(path)
        if not parent_existed:
            try:
                folder.parent.rmdir()
            except OSError:
                pass


def exchange(a, b):
    """macOS atomically swaps complete platform directories, including on APFS."""
    if sys.platform == 'darwin':
        lib = ctypes.CDLL(None, use_errno=True)
        call = lib.renamex_np
        call.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
        call.restype = ctypes.c_int
        if call(os.fsencode(a), os.fsencode(b), 0x00000002):  # SDK sys/stdio.h RENAME_SWAP
            error = ctypes.get_errno()
            raise OSError(error, os.strerror(error))
    else:
        # Tests on other hosts do not build/install games. Preserve rollback there too.
        backup = b.with_name('.' + b.name + '-previous-' + uuid.uuid4().hex)
        b.rename(backup)
        try:
            a.rename(b)
            backup.rename(a)
        except BaseException:
            if not b.exists():
                backup.rename(b)
            raise


def _clone_file(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if sys.platform == 'darwin' and subprocess.run(
            ['/bin/cp', '-cp', str(source), str(destination)], capture_output=True).returncode == 0:
        return
    shutil.copy2(source, destination)


def publish(game, platform, prepared, destination, info, record, *, jobs_path=None, relocations=None):
    """Caller holds the game's build lock. Retain only renewal-referenced old IPAs.

    The previous platform directory remains available for rollback until both
    metadata writes complete. An interrupted swap leaves a complete named export;
    source inputs, player saves and the other platform are never in the deletion set.
    """
    game, prepared, destination = map(Path, (game, prepared, destination))
    state_path = game / ('nxnative-' + platform + '.json')
    state_before = state_path.read_bytes() if state_path.exists() else None
    identity = {'schema': 1, 'source_folder': str(game.resolve()), 'platform': platform,
                'bundle_id': info['CFBundleIdentifier']}
    content = manifest(prepared)
    atomic_json(prepared / MARKER, dict(identity, files=content))
    personal = Path.home() / 'Library/Application Support/nxnative Easy'
    jobs_path = Path(jobs_path) if jobs_path is not None else personal / 'refresh-jobs.json'
    jobs_path.parent.mkdir(parents=True, exist_ok=True)
    promoted = False
    had_old = False
    jobs_before = None
    jobs_changed = False
    with ExitStack() as locks:
        def lock_file(path):
            return os.fdopen(os.open(path,os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW|os.O_CLOEXEC,0o600),'a')
        lease = locks.enter_context(lock_file(jobs_path.with_name(jobs_path.name + '.lock')))
        fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
        install = locks.enter_context(lock_file(jobs_path.parent / 'installer.lock'))
        fcntl.flock(install, fcntl.LOCK_EX | fcntl.LOCK_NB)
        # Serialize exports from separate source folders to the same destination.
        lock_id = hashlib.sha256(str(destination.resolve()).encode()).hexdigest()[:20]
        lease = locks.enter_context(lock_file(Path(tempfile.gettempdir()) / ('nxe-export-' + lock_id + '.lock')))
        fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
        had_old = destination.exists()
        if had_old:
            marker = destination / MARKER
            if destination.is_symlink() or not marker.is_file() or marker.is_symlink():
                raise ValueError('This destination already contains files. Choose another folder; nothing was replaced.')
            old = json.loads(marker.read_text())
            if any(old.get(k) != v for k, v in identity.items()):
                raise ValueError('This export belongs to another game. Choose another destination.')
            if manifest(destination) != old.get('files'):
                raise ValueError('Files were added or changed in the old export. Choose another destination to preserve them.')
            commands = subprocess.check_output(['ps', '-axo', 'comm='], text=True) if sys.platform == 'darwin' else ''
            if str(destination) + '/' in commands:
                raise ValueError('Close the running game before replacing its Mac export.')
        if jobs_path.exists():
            if jobs_path.is_symlink() or jobs_path.stat().st_size>1048576:
                raise ValueError('Invalid renewal metadata; previous files preserved.')
            jobs_before = jobs_path.read_bytes()
            jobs = json.loads(jobs_before)
            if not isinstance(jobs, list) or any(not isinstance(j, dict) for j in jobs):
                raise ValueError('Renewal records could not be read; previous export preserved.')
            for job in jobs:
                new = (relocations or {}).get(job.get('ipa'))
                if new is None:
                    continue
                new = Path(new)
                expected = job.get('sha256')
                actual = prepared / new.relative_to(destination) if new.is_relative_to(destination) else new
                if (not isinstance(expected,str) or not re.fullmatch('[0-9a-f]{64}',expected)
                        or actual.is_symlink() or digest(actual) != expected
                        or digest(Path(job['ipa'])) != expected):
                    raise ValueError('Relocation changed a renewal package; original paths retained.')
                job['ipa'] = str(new)
                jobs_changed = True
            if had_old:
                for job in jobs:
                    ipa = Path(job.get('ipa', '/missing'))
                    if not ipa.is_relative_to(destination):
                        continue
                    expected = job.get('sha256')
                    if not isinstance(expected, str) or not re.fullmatch('[0-9a-f]{64}', expected) or ipa.is_symlink() or digest(ipa) != expected:
                        raise ValueError('The saved renewal package changed; previous export preserved.')
                    archived = destination.parent / '.renewal' / expected / ipa.name
                    if not archived.exists():
                        temp=archived.with_name('.'+ipa.name+'.'+uuid.uuid4().hex)
                        try:
                            _clone_file(ipa,temp)
                            if digest(temp)!=expected:
                                raise ValueError('Renewal archive verification failed; previous export preserved.')
                            temp.replace(archived)
                        finally:
                            temp.unlink(missing_ok=True)
                    if archived.is_symlink() or digest(archived) != expected:
                        raise ValueError('Could not preserve the renewal package; previous export retained.')
                    # This is a verified relocation, never a change of package or identity.
                    job['ipa'] = str(archived)
                    jobs_changed = True
        try:
            if had_old:
                exchange(prepared, destination)
            else:
                prepared.rename(destination)
            promoted = True
            atomic_json(state_path, record)
            if jobs_changed:
                atomic_json(jobs_path, jobs)
        except BaseException:
            if promoted:
                if had_old:
                    exchange(prepared, destination)
                else:
                    destination.rename(prepared)
            if state_before is None:
                state_path.unlink(missing_ok=True)
            else:
                atomic_bytes(state_path, state_before)
            if jobs_changed and jobs_before is not None:
                atomic_bytes(jobs_path, jobs_before)
            raise
        (destination / PREPARING).unlink(missing_ok=True)
    return destination
