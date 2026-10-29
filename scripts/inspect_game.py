#!/usr/bin/env python3
"""Read CNMT/NACP metadata without extracting or compiling a game.

Builds only the metadata tool in the user's external tool cache when necessary.
Package/key contents and tool diagnostics are never forwarded to the UI.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
from typing import Any
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
EXTENSIONS = {'.nsp', '.xci', '.nsz', '.xcz'}


def summarize(value) -> dict[str, Any]:
    if value.get('schema') != 1 or not isinstance(value.get('packages'), list):
        raise ValueError('Invalid metadata response')
    packages = value['packages']
    errors = value.get('errors', [])
    bases = [p for p in packages if p['kind'] == 'base']
    ids = {p['title_id'] for p in packages if p['kind'] in ('base', 'update', 'dlc')}
    if errors and not bases:
        return dict(schema=1,status='keys_unreadable' if any(e.get('code')=='keys_unreadable' for e in errors) else 'metadata_unreadable',packages=packages,errors=errors)
    if len(ids) != 1 or not bases:
        return dict(schema=1, status='multiple_games' if len(ids) > 1 else 'base_missing', packages=packages, errors=errors)
    title_id = bases[0]['title_id']
    updates = sorted([p for p in packages if p['kind'] == 'update'], key=lambda p: p['version'], reverse=True)
    base = max(bases, key=lambda p: p['version'])
    selected = updates[0] if updates else base
    name = selected.get('name') or next((p.get('name') for p in bases if p.get('name')), None)
    return dict(schema=1, status='ready' if not errors else 'incomplete', title_id=title_id,
                name=name, display_version=selected.get('display_version'), version=selected['version'],
                selected_file=selected['file'], base_version=base.get('display_version'),
                updates=updates, dlc=[p for p in packages if p['kind'] == 'dlc'], packages=packages, errors=errors)


def inspect(folder, keys, cache, setup_tools=False):
    folder, keys = folder.resolve(), keys.resolve()
    if folder == REPO or REPO in folder.parents or REPO in keys.parents:
        return dict(schema=1, status='invalid_location')
    files = sorted(p for p in folder.iterdir() if p.suffix.lower() in EXTENSIONS and p.is_file())
    if not files:
        return dict(schema=1, status='base_missing')
    if any(p.resolve() == REPO or REPO in p.resolve().parents for p in files):
        return dict(schema=1, status='invalid_location')
    env = dict(os.environ)
    if not env.get('NXE_BUNDLED_TOOLS'):env['PATH'] = '/opt/homebrew/bin:/usr/local/bin:/usr/local/share/dotnet:' + env.get('PATH', '')
    env.update(DOTNET_CLI_TELEMETRY_OPTOUT='1', DOTNET_NOLOGO='1')
    dotnet = shutil.which('dotnet', path=env['PATH'])
    if setup_tools:
        brew = shutil.which('brew', path=env['PATH'])
        if not brew:
            return dict(schema=1, status='tools_missing')
        command = 'upgrade' if subprocess.run([brew, 'list', '--cask', '--versions', 'dotnet-sdk'], env=env, capture_output=True).returncode == 0 else 'install'
        result = subprocess.run([brew, command, '--cask', 'dotnet-sdk'], env=env, capture_output=True, timeout=900)
        if result.returncode:
            return dict(schema=1, status='tools_unavailable')
        dotnet = shutil.which('dotnet', path=env['PATH'])
    if not dotnet:
        return dict(schema=1, status='tools_missing')
    source = REPO / 'dm/tools/nx_extract'
    digest = hashlib.sha256(b''.join(p.read_bytes() for p in (source/'Program.cs', source/'nx_extract.csproj'))).hexdigest()
    tool = cache / digest / 'nx_extract.dll'
    if env.get('NXE_BUNDLED_TOOLS'):
        bundled=Path(env['NXE_BUNDLED_TOOLS'])
        metadata=json.loads((bundled/'manifest.json').read_text())
        if metadata.get('reader_source_sha256')==digest:tool=bundled/'nx_extract/nx_extract.dll'
    if not tool.is_file():
        cache.mkdir(parents=True, exist_ok=True)
        # Both the build output and MSBuild's intermediate files stay outside the checkout.
        with tempfile.TemporaryDirectory(prefix='metadata-', dir=cache) as temporary:
            work = Path(temporary)
            project = work/'source'
            project.mkdir()
            for name in ('Program.cs', 'nx_extract.csproj'):
                shutil.copy2(source/name, project/name)
            result = subprocess.run([dotnet, 'build', str(project), '-c', 'Release', '-o', str(work/'tool'), '-v', 'quiet', '-nologo'],
                                    env=env, capture_output=True, timeout=240)
            if result.returncode:
                return dict(schema=1, status='tools_unavailable')
            try:
                (work/'tool').rename(tool.parent)
            except FileExistsError:
                pass  # another read-only inspection populated the same tool cache
    signatures = {p.name: [p.stat().st_size, p.stat().st_mtime_ns] for p in files}
    result = subprocess.run([dotnet, str(tool), '--inspect', str(keys), *(str(p) for p in files)],
                            env=env, capture_output=True, timeout=180)
    if len(result.stdout) > 1048576:
        return dict(schema=1, status='metadata_unreadable')
    try:
        value = summarize(json.loads(result.stdout))
        if any([p.stat().st_size, p.stat().st_mtime_ns] != signatures[p.name] for p in files):
            return dict(schema=1, status='files_changed')
        value['sources'] = signatures
        return value
    except (ValueError, KeyError, TypeError):
        return dict(schema=1, status='metadata_unreadable')


def family_from_metadata(folder, value):
    """Use the exact inspected identities/versions, rejecting stale or ambiguous inputs."""
    if value.get('schema') != 1 or value.get('status') != 'ready' or value.get('errors'):
        raise ValueError('Game metadata is incomplete; identify the folder again.')
    folder = Path(folder).resolve()
    files = {p.name: p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in EXTENSIONS}
    signatures = {name: [p.stat().st_size, p.stat().st_mtime_ns] for name, p in files.items()}
    if signatures != value.get('sources'):
        raise ValueError('Game files changed after identification; identify the folder again.')
    application = int(value['title_id'], 16)
    family: dict[str, Any] = dict(base=None, updates=[], dlc=[])
    bases = []
    for package in value['packages']:
        name = package['file']
        if name not in files or int(package['title_id'], 16) != application:
            raise ValueError('Package metadata does not match the selected game.')
        path = files[name]
        version = package['version']
        if not isinstance(version, int) or not 0 <= version <= 0xFFFFFFFF:
            raise ValueError('Invalid package version.')
        if package['kind'] == 'base':
            bases.append((version, path))
        elif package['kind'] == 'update':
            family['updates'].append((version, path))
        elif package['kind'] == 'dlc':
            family['dlc'].append((int(package['content_id'], 16), version, path))
    if not bases:
        raise ValueError('No base game in inspected packages.')
    family['base'] = max(bases, key=lambda item: (item[0], item[1].suffix.lower() not in ('.nsz', '.xcz'), item[1].name))[1]
    return application, family


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    parser.add_argument('--keys', type=Path, required=True)
    parser.add_argument('--setup-tools', action='store_true')
    parser.add_argument('--cache', type=Path, default=Path.home()/'Library/Caches/nxnative Easy/metadata')
    args = parser.parse_args()
    try:
        value = inspect(args.folder, args.keys, args.cache, args.setup_tools)
    except (OSError, subprocess.SubprocessError):
        value = dict(schema=1, status='metadata_unreadable')
    print(json.dumps(value))


if __name__ == '__main__':
    main()
