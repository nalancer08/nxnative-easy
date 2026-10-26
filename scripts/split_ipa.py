#!/usr/bin/env python3
"""Export RomFS and produce a verified unsigned lightweight nxnative IPA."""
import argparse
from pathlib import Path, PurePosixPath
import plistlib
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import unicodedata
import zipfile

CHUNK = 4 * 1024 * 1024
GIB = 1024 ** 3


def say(message):
    print(message, flush=True)


def size_text(value):
    return '{:.2f} GB ({:.2f} GiB)'.format(value / 1_000_000_000, value / GIB)


def choose_ipa():
    if sys.platform != 'darwin':
        raise ValueError('Provide the IPA path as an argument.')
    result = subprocess.run(
        ['/usr/bin/osascript', '-e',
         'POSIX path of (choose file with prompt "Select an nxnative IPA")'],
        capture_output=True, text=True, check=False)
    if result.returncode:
        raise ValueError('Selection cancelled; no files changed.')
    return Path(result.stdout.rstrip('\n'))


def validate_entries(entries):
    seen = set()
    files = set()
    for entry in entries:
        name = entry.filename
        path = PurePosixPath(name)
        pieces = name.rstrip('/').split('/')
        if (not name or path.is_absolute() or '\\' in name or '\x00' in name
                or any(part in ('', '.', '..') for part in pieces)):
            raise ValueError('Unsafe archive path.')
        folded = unicodedata.normalize('NFC', name.rstrip('/')).casefold()
        if folded in seen:
            raise ValueError('Duplicate or case-insensitive archive paths.')
        seen.add(folded)
        if not entry.is_dir():
            files.add(folded)
        if stat.S_ISLNK(entry.external_attr >> 16):
            raise ValueError('Symbolic links are not supported.')
        if entry.flag_bits & 1:
            raise ValueError('Encrypted archive entries are not supported.')
        if entry.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
            raise ValueError('Unsupported ZIP compression.')
        if path.name.casefold() in ('prod.keys', 'title.keys'):
            raise ValueError('Archive contains keys; refusing to process.')
    for name in seen:
        if any(str(parent) in files for parent in PurePosixPath(name).parents
               if str(parent) != '.'):
            raise ValueError('Archive path is both file and directory.')


def removed_signature(name):
    path = PurePosixPath(name)
    return '_CodeSignature' in path.parts or path.name == 'embedded.mobileprovision'


def new_zip_info(source, executable_path):
    result = zipfile.ZipInfo(source.filename, source.date_time)
    result.create_system = 3
    result.compress_type = source.compress_type
    result.file_size = source.file_size
    mode = (source.external_attr >> 16) & 0o777
    if source.is_dir():
        result.external_attr = ((stat.S_IFDIR | (mode or 0o755)) << 16) | 0x10
    else:
        mode = mode or (0o755 if source.filename == executable_path else 0o644)
        if source.filename == executable_path:
            mode |= 0o111
        result.external_attr = (stat.S_IFREG | mode) << 16
    return result


def split_ipa(ipa):
    ipa = ipa.expanduser().resolve(strict=True)
    if not ipa.is_file() or ipa.suffix.casefold() != '.ipa':
        raise ValueError('Select an .ipa file.')
    original_stat = ipa.stat()
    output = None
    with zipfile.ZipFile(ipa, 'r') as source:
        entries = source.infolist()
        validate_entries(entries)
        info_entries = [entry for entry in entries
                        if len(PurePosixPath(entry.filename).parts) == 3
                        and PurePosixPath(entry.filename).parts[0] == 'Payload'
                        and PurePosixPath(entry.filename).parts[1].endswith('.app')
                        and PurePosixPath(entry.filename).name == 'Info.plist']
        if len(info_entries) != 1 or info_entries[0].file_size > 1024 * 1024:
            raise ValueError('Expected exactly one valid main Info.plist.')
        info_entry = info_entries[0]
        info = plistlib.loads(source.read(info_entry))
        if not isinstance(info, dict):
            raise ValueError('Invalid Info.plist dictionary.')
        prefix = info_entry.filename[:-len('Info.plist')]
        names = {entry.filename for entry in entries}
        executable = info.get('CFBundleExecutable')
        if not isinstance(executable, str) or '/' in executable or '\\' in executable:
            raise ValueError('Invalid executable name.')
        executable_path = prefix + executable
        if executable_path not in names:
            raise ValueError('Missing executable.')
        for required in ('dm/', 'msl/'):
            if not any(entry.filename.startswith(prefix + required) and not entry.is_dir()
                       for entry in entries):
                raise ValueError('Missing nxnative resources: ' + required)
        romfs_prefix = prefix + 'romfs/'
        romfs_entries = [entry for entry in entries if entry.filename.startswith(romfs_prefix)]
        if not any(not entry.is_dir() for entry in romfs_entries):
            raise ValueError('No bundled RomFS found; this IPA may already be lightweight.')
        kept = [entry for entry in entries if not entry.filename.startswith(romfs_prefix)
                and not removed_signature(entry.filename)]
        if len(kept) > 65535:
            raise ValueError('Too many entries for a non-ZIP64 archive.')
        app_bytes = sum(entry.file_size for entry in kept)
        if app_bytes + len(kept) * 1024 + 1024 * 1024 >= zipfile.ZIP64_LIMIT:
            raise ValueError('App without RomFS is still too large for '
                             'non-ZIP64 packaging.')
        romfs_bytes = sum(entry.file_size for entry in romfs_entries)
        needed = romfs_bytes + app_bytes + 512 * 1024 * 1024
        free = shutil.disk_usage(ipa.parent).free
        say('Source IPA: ' + str(ipa))
        say('Source size: ' + size_text(original_stat.st_size))
        say('RomFS export size: ' + size_text(romfs_bytes))
        say('Remaining app data, uncompressed: ' + size_text(app_bytes))
        if free < needed:
            raise ValueError('Insufficient disk space; need approximately ' +
                             size_text(needed) + ' free beside the IPA.')
        info['UIFileSharingEnabled'] = True
        info['LSSupportsOpeningDocumentsInPlace'] = True
        new_plist = plistlib.dumps(info, fmt=plistlib.FMT_BINARY, sort_keys=False)
        try:
            output = Path(tempfile.mkdtemp(prefix=ipa.stem + '-light-', dir=str(ipa.parent)))
            romfs = output / 'romfs'
            romfs.mkdir()
            result_ipa = output / (ipa.stem + '-light.ipa')
            say('Preparing a separate output; original preserved: ' + str(output))
            last_progress = time.monotonic()
            completed = 0
            with zipfile.ZipFile(result_ipa, 'x', allowZip64=False) as target:
                for index, entry in enumerate(entries, 1):
                    if not entry.filename.startswith(romfs_prefix) and removed_signature(entry.filename):
                        continue
                    if entry.filename.startswith(romfs_prefix):
                        relative = entry.filename[len(romfs_prefix):]
                        if relative:
                            destination = romfs.joinpath(*PurePosixPath(relative).parts)
                            if entry.is_dir():
                                destination.mkdir(parents=True, exist_ok=True)
                            else:
                                destination.parent.mkdir(parents=True, exist_ok=True)
                                with source.open(entry) as reader, destination.open('xb') as writer:
                                    shutil.copyfileobj(reader, writer, CHUNK)
                                destination.chmod(0o644)
                    else:
                        target_info = new_zip_info(entry, executable_path)
                        if entry.filename == info_entry.filename:
                            target.writestr(target_info, new_plist)
                        elif entry.is_dir():
                            target.writestr(target_info, b'')
                        else:
                            with source.open(entry) as reader, target.open(target_info, 'w') as writer:
                                shutil.copyfileobj(reader, writer, CHUNK)
                    completed += entry.file_size
                    if time.monotonic() - last_progress >= 5:
                        say('Processed {}/{} entries; {}'.format(
                            index, len(entries), size_text(completed)))
                        last_progress = time.monotonic()
            current_stat = ipa.stat()
            if (current_stat.st_size, current_stat.st_mtime_ns) != (
                    original_stat.st_size, original_stat.st_mtime_ns):
                raise ValueError('Source changed during processing; retry with a stable copy.')
            say('Verifying lightweight IPA integrity...')
            with zipfile.ZipFile(result_ipa) as verify:
                bad = verify.testzip()
                if bad:
                    raise ValueError('Output CRC verification failed.')
                if any(entry.extract_version >= 45 for entry in verify.infolist()):
                    raise ValueError('Output still needs ZIP64 or an unsupported extension.')
            instructions = (
                'Install the lightweight IPA with Sideloadly using your personal Apple account.\n'
                'First installation: copy the complete romfs folder to the app Documents via Finder.\n'
                'Updates: install over the existing app with the same effective bundle ID and Apple account.\n'
                'Do not uninstall: this deletes saves and Documents. Reuse existing romfs only for identical game data.\n'
                'Unsigned package; signing and device testing are separate. Original IPA preserved.\n'
            )
            (output / 'INSTALL.txt').write_text(instructions, encoding='utf-8')
            say('\nDONE')
            say('IPA for Sideloadly: ' + str(result_ipa))
            say('Lightweight IPA size: ' + size_text(result_ipa.stat().st_size))
            say('Folder to copy with Finder: ' + str(romfs))
            say('Install the IPA, then copy romfs into app Documents if required.')
            return output
        except BaseException:
            if output is not None:
                shutil.rmtree(output, ignore_errors=True)
            raise


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('ipa', nargs='?', help='nxnative IPA; opens a file picker on macOS if omitted')
    args = parser.parse_args()
    try:
        split_ipa(Path(args.ipa) if args.ipa else choose_ipa())
        return 0
    except KeyboardInterrupt:
        say('\nCancelled. Source IPA preserved.')
        return 130
    except (OSError, ValueError, RuntimeError, zipfile.BadZipFile, zipfile.LargeZipFile,
            plistlib.InvalidFileException, subprocess.SubprocessError) as error:
        print('Failed: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
