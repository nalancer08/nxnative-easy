"""Synthetic console/cloud interchange. No account, game or physical device."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('save_transfer', ROOT / 'scripts/save_transfer.py')
assert spec is not None and spec.loader is not None
transfer = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = transfer
spec.loader.exec_module(transfer)
TITLE = '010093801237C000'


class SaveTransfer(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='nxe-transfer-fixture-')
        self.root = Path(self.temporary.name)
        self.cloud = self.root / 'cloud'
        self.cloud.mkdir()
        self.backup = self.root / 'console-backup'
        self.backup.mkdir()
        (self.backup / 'progress.bin').write_bytes(b'console progress')
        self.app = self.root / 'Game.app'
        folder = self.app / 'Contents/Resources/dm'
        folder.mkdir(parents=True)
        self.manifest = dict(format=1, title=TITLE, version='2.1.0', modules={'main': 'a'*32},
                             romfs='b'*64, dlc=None)
        self.manifest['identity'] = hashlib.sha256(json.dumps(self.manifest, sort_keys=True,
                                                            separators=(',', ':')).encode()).hexdigest()
        (folder / 'save-compat.json').write_text(json.dumps(self.manifest))
        self.game = dict(title=TITLE, mac=str(self.app))

    def tearDown(self):
        self.temporary.cleanup()

    def seed_baseline(self, roots=('save',)):
        if list(self.cloud.rglob('*.nxsave')):
            return
        payload, digest = transfer.inner_archive([transfer.Entry(root+'/initial.bin', b'first game save') for root in roots], TITLE)
        metadata = dict(format=1, title=TITLE, player='default', compat=self.manifest['identity'],
                        gameVersion='2.1.0', parents=[], hash=digest, device='first setup', date=1)
        header = json.dumps(metadata).encode()
        import struct
        data = struct.pack('<I', len(header)) + header + payload
        folder = self.cloud / 'nxnative-saves-v1' / TITLE
        folder.mkdir(parents=True)
        (folder / (hashlib.sha256(data).hexdigest()+'.nxsave')).write_bytes(data)

    def request(self, **updates):
        value = dict(source=str(self.backup), cloud=str(self.cloud), kind='account',
                     game=self.game, confirmed_game=True,
                     fingerprint=transfer.inspect(self.backup)['fingerprint'])
        value.update(updates)
        return value

    def revision(self):
        self.seed_baseline()
        return Path(transfer.import_cloud(self.request())['path'])

    def test_import_publishes_a_new_branch_without_replacing_any_save(self):
        first = self.revision()
        before = first.read_bytes()
        (self.backup / 'progress.bin').write_bytes(b'later console progress')
        second = self.revision()
        self.assertNotEqual(first, second)
        self.assertEqual(first.read_bytes(), before)
        self.assertEqual((self.backup / 'progress.bin').read_bytes(), b'later console progress')
        meta, entries = transfer.read_revision(second)
        self.assertEqual(meta['parents'], [])
        self.assertEqual(meta['compat'], self.manifest['identity'])
        self.assertEqual(entries[0].data, b'later console progress')

    def test_round_trip_cloud_to_console_keeps_exact_account_and_device_bytes(self):
        bundle = self.root / 'pair'
        for name in ['save', 'save_device']:
            (bundle / name).mkdir(parents=True)
            (bundle / name / 'progress.bin').write_bytes(name.encode())
        preview = transfer.inspect(bundle, 'bundle')
        self.seed_baseline(('save', 'save_device'))
        revision = Path(transfer.import_cloud(self.request(source=str(bundle), kind='bundle',
                                                         fingerprint=preview['fingerprint']))['path'])
        destination = self.root / 'SD'
        destination.mkdir()
        (destination / 'my-old-backup').mkdir()
        preview = transfer.inspect(revision)
        result = transfer.export_switch(dict(source=str(revision), title=TITLE,
                                             fingerprint=preview['fingerprint'], destination=str(destination),
                                             confirmed_console_requirement=True))
        exported = Path(result['path'])
        self.assertEqual(result['status'], 'backup_prepared_not_restored')
        for name in ['save', 'save_device']:
            self.assertEqual((exported / name / 'progress.bin').read_bytes(), name.encode())
        self.assertTrue((destination / 'my-old-backup').is_dir())
        self.assertTrue(revision.exists())

    def test_destinations_cannot_write_source_code_or_active_save_roots(self):
        for folder in [ROOT, self.root / 'save', self.root / 'save_device.work']:
            folder.mkdir(exist_ok=True)
            with self.assertRaisesRegex(transfer.TransferError, 'protected_destination'):
                transfer.writable_destination(folder)
        self.assertEqual(transfer.writable_destination(self.cloud), self.cloud)

    def test_fifo_and_zip_alias_without_guest_metadata_are_refused(self):
        fifo = self.backup / 'progress-pipe'
        os.mkfifo(fifo)
        with self.assertRaisesRegex(transfer.TransferError, 'invalid_or_large_file'):
            transfer.read_file(fifo)
        archive = self.root / 'missing-metadata.zip'
        with zipfile.ZipFile(archive, 'w') as output:
            output.writestr('save/.dm-case-123', b'progress')
        with self.assertRaisesRegex(transfer.TransferError, 'missing_guest_metadata'):
            transfer.inspect(archive)

    def test_local_cloud_copy_is_checked_and_never_replaces_a_backup(self):
        revision = self.revision()
        destination = self.root / 'Local.nxsave'
        request = dict(op='backup_revision', source=str(revision), destination=str(destination),
                       fingerprint=transfer.inspect(revision)['fingerprint'])
        transfer.local_backup(request)
        self.assertEqual(destination.read_bytes(), revision.read_bytes())
        with self.assertRaisesRegex(transfer.TransferError, 'destination_exists'):
            transfer.local_backup(request)
        self.assertTrue(revision.exists())

    def test_mac_backup_reads_only_committed_roots_and_keeps_both(self):
        from unittest.mock import patch
        root = self.root / 'Library/Application Support/nxnative' / TITLE
        for name in ['save', 'save_device', 'save.work']:
            (root / name).mkdir(parents=True)
            (root / name / 'progress').write_bytes(name.encode())
        destination = self.root / 'Mac.zip'
        with patch.object(transfer.Path, 'home', return_value=self.root):
            transfer.local_backup(dict(op='backup_mac', title=TITLE, destination=str(destination), confirmed_closed=True))
        with zipfile.ZipFile(destination) as archive:
            self.assertEqual(archive.read('save/progress'), b'save')
            self.assertEqual(archive.read('save_device/progress'), b'save_device')
            self.assertFalse(any('save.work' in name for name in archive.namelist()))
        self.assertEqual((root/'save.work/progress').read_bytes(), b'save.work')

    def test_modified_source_refuses_before_publishing(self):
        request = self.request()
        (self.backup / 'progress.bin').write_bytes(b'changed')
        with self.assertRaisesRegex(transfer.TransferError, 'source_changed'):
            transfer.import_cloud(request)
        self.assertEqual(list(self.cloud.iterdir()), [])

    def test_confirmation_is_required(self):
        with self.assertRaisesRegex(transfer.TransferError, 'confirm_game'):
            transfer.import_cloud(self.request(confirmed_game=False))
        self.assertEqual(list(self.cloud.iterdir()), [])

    def test_raw_import_needs_a_first_checked_cloud_save(self):
        with self.assertRaisesRegex(transfer.TransferError, 'create_first_cloud_save'):
            transfer.import_cloud(self.request())
        self.assertEqual(list(self.cloud.iterdir()), [])

    def test_missing_game_manifest_blocks_import(self):
        with self.assertRaisesRegex(transfer.TransferError, 'rebuild_for_save_transfer'):
            transfer.import_cloud(self.request(game=dict(title=TITLE)))

    def test_game_manifest_identity_cannot_be_forged_by_editing_only_the_title(self):
        path = self.app / 'Contents/Resources/dm/save-compat.json'
        self.manifest['version'] = 'newer'
        path.write_text(json.dumps(self.manifest))
        with self.assertRaisesRegex(transfer.TransferError, 'invalid_compatibility'):
            transfer.import_cloud(self.request())

    def test_different_platform_content_blocks_import(self):
        ipa = self.root / 'Game.ipa'
        other = dict(self.manifest, version='2.2.0')
        other.pop('identity')
        other['identity'] = hashlib.sha256(json.dumps(other, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        with zipfile.ZipFile(ipa, 'w') as archive:
            archive.writestr('Payload/Game.app/dm/save-compat.json', json.dumps(other))
        with self.assertRaisesRegex(transfer.TransferError, 'platform_content_mismatch'):
            transfer.compatibility(dict(self.game, ipa=str(ipa)))

    def test_an_ipa_manifest_alone_is_sufficient(self):
        ipa = self.root / 'Game.ipa'
        with zipfile.ZipFile(ipa, 'w') as archive:
            archive.writestr('Payload/Game.app/dm/save-compat.json', json.dumps(self.manifest))
        self.assertEqual(transfer.compatibility(dict(title=TITLE, ipa=str(ipa))), self.manifest)

    def test_symlinks_and_game_or_key_inputs_are_refused(self):
        secret = self.root / 'original.keys'
        secret.write_bytes(b'fake key - not a real console key')
        (self.backup / 'linked').symlink_to(secret)
        with self.assertRaisesRegex(transfer.TransferError, 'symlink'):
            transfer.inspect(self.backup)
        (self.backup / 'linked').unlink()
        (self.backup / 'prod.keys').write_bytes(b'fake')
        with self.assertRaisesRegex(transfer.TransferError, 'not_save_data'):
            transfer.inspect(self.backup)
        self.assertEqual(secret.read_bytes(), b'fake key - not a real console key')

    def test_working_save_and_romfs_are_not_accepted(self):
        (self.backup / 'save.work').mkdir()
        with self.assertRaisesRegex(transfer.TransferError, 'not_committed'):
            transfer.inspect(self.backup)

    def test_raw_zip_does_not_require_parent_directory_records(self):
        path = self.root / 'JKSV.zip'
        with zipfile.ZipFile(path, 'w') as archive:
            archive.writestr('slot/nested/progress.bin', b'raw Switch save')
        entries = transfer.source(path)[1]
        self.assertEqual([e.path for e in entries], ['save/slot', 'save/slot/nested', 'save/slot/nested/progress.bin'])

    def test_zip_traversal_duplicate_symlink_and_non_save_data_refused(self):
        for name in ['../escape.bin', '/absolute.bin', 'save/../escape.bin', 'base/game.nsp']:
            path = self.root / 'bad.zip'
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr(name, b'no')
            with self.assertRaises(transfer.TransferError):
                transfer.source(path)
        path = self.root / 'link.zip'
        with zipfile.ZipFile(path, 'w') as archive:
            info = zipfile.ZipInfo('link');info.create_system=3;info.external_attr=0o120777 << 16
            archive.writestr(info, '../../outside')
        with self.assertRaisesRegex(transfer.TransferError, 'invalid_zip_entry'):
            transfer.source(path)

    def test_archive_detects_damage_and_trailing_bytes(self):
        revision = self.revision()
        data = revision.read_bytes()
        revision.write_bytes(data[:-1] + b'X')
        with self.assertRaisesRegex(transfer.TransferError, 'checksum_mismatch'):
            transfer.read_revision(revision)
        archive = transfer.inner_archive([transfer.Entry('save/a', b'x')], TITLE)[0]
        with self.assertRaisesRegex(transfer.TransferError, 'checksum_mismatch'):
            transfer.decode_inner(archive + b'extra')

    def test_empty_and_oversize_saves_are_refused(self):
        (self.backup / 'progress.bin').unlink()
        with self.assertRaisesRegex(transfer.TransferError, 'empty_or_large'):
            transfer.inspect(self.backup)
        with (self.backup / 'large').open('wb') as stream:
            stream.truncate(transfer.MAX_BYTES + 1)
        with self.assertRaisesRegex(transfer.TransferError, 'large_save'):
            transfer.inspect(self.backup)

    def test_list_shows_all_branches_and_counts_bad_or_pending_files(self):
        self.revision();self.revision()
        folder = self.cloud / 'nxnative-saves-v1' / TITLE
        (folder / ('0'*64+'.nxsave')).write_bytes(b'incomplete')
        (folder / ('.'+'f'*64+'.nxsave.icloud')).write_bytes(b'')
        result = transfer.cloud_list(self.cloud)
        self.assertEqual(len(result['revisions']), 3)
        self.assertEqual((result['invalid'], result['pending']), (1, 1))

    def test_publish_new_never_overwrites(self):
        path = self.cloud / 'existing'
        path.write_bytes(b'original')
        with self.assertRaises(FileExistsError):
            transfer.publish_new(path, b'replacement')
        self.assertEqual(path.read_bytes(), b'original')

    def test_sd_case_collisions_refused_without_renaming_progress(self):
        (self.backup / 'slot').write_bytes(b'lower')
        # Carry both logical names through the engine's physical alias metadata.
        alias = self.backup / '.dm-case-1'
        alias.write_bytes(b'upper')
        if sys.platform == 'darwin':
            subprocess.run(['xattr', '-w', transfer.GUEST, 'SLOT', str(alias)], check=True)
        elif sys.platform.startswith('linux'):
            alias.unlink()
            (self.backup / 'SLOT').write_bytes(b'upper')
        else:
            self.skipTest('xattrs required')
        revision = self.revision()
        destination = self.root / 'SD';destination.mkdir()
        with self.assertRaisesRegex(transfer.TransferError, 'case_collision_for_sd'):
            transfer.export_switch(dict(source=str(revision), title=TITLE,
                                        fingerprint=transfer.inspect(revision)['fingerprint'],
                                        destination=str(destination), confirmed_console_requirement=True))
        self.assertTrue(revision.exists())
        self.assertFalse(any(p.name.startswith('Easy-') for p in destination.iterdir()))

    def test_cli_errors_do_not_echo_sensitive_paths_or_file_contents(self):
        request = dict(op='inspect', source=str(self.root / 'secret-private-name.keys'))
        run = subprocess.run([sys.executable, str(ROOT / 'scripts/save_transfer.py')],
                             input=json.dumps(request), capture_output=True, text=True, check=False)
        self.assertNotEqual(run.returncode, 0)
        self.assertNotIn('secret-private-name', run.stdout + run.stderr)
        self.assertFalse(json.loads(run.stdout)['ok'])


@unittest.skipUnless(sys.platform == 'darwin', 'native Apple archive interoperability')
class NativeSaveTransfer(unittest.TestCase):
    root: Path
    cloud: Path
    manifest: dict
    backup: Path
    game: dict
    app: Path
    setUp = SaveTransfer.setUp
    tearDown = SaveTransfer.tearDown
    request = SaveTransfer.request
    revision = SaveTransfer.revision
    seed_baseline = SaveTransfer.seed_baseline
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix='nxe-transfer-native-')
        cls.driver = Path(cls.build.name) / 'cloud-driver'
        host = ROOT / 'dm/host'
        subprocess.run(['clang', '-fobjc-arc', '-fobjc-arc-exceptions', '-fblocks',
                        '-DNXE_CLOUD_TESTING', '-Wno-deprecated-declarations', '-I', str(host),
                        str(host / 'tests/cloud_driver.m'), str(host / 'cloud_saves.m'),
                        str(host / 'save_archive.c'), '-framework', 'Foundation', '-o', str(cls.driver)], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.build.cleanup()

    def command(self, device, command='check', argument=''):
        folder = self.root / device
        folder.mkdir(exist_ok=True)
        manifest = folder / 'compat.json'
        manifest.write_text(json.dumps(self.manifest))
        env = dict(os.environ, DM_SAVE=str(folder / 'save'), NXE_SAVE_COMPAT=str(manifest),
                   NXE_CLOUD_FOLDER=str(self.cloud))
        run = subprocess.run([str(self.driver), command, argument], env=env,
                             capture_output=True, text=True, timeout=30, check=True)
        return json.loads(run.stdout)

    def test_console_import_is_read_by_the_actual_native_mac_and_ios_engine(self):
        revision = self.revision()
        self.assertEqual(self.command('mac')['status'], 'conflict')
        self.command('mac', 'resolve', revision.stem)
        for device in ['mac', 'phone', 'ipad']:
            self.assertEqual(self.command(device)['status'], 'available')
            self.assertEqual((self.root / device / 'save/progress.bin').read_bytes(), b'console progress')
        self.assertTrue(revision.exists())

    def test_native_iphone_snapshot_exports_to_an_exact_console_backup(self):
        folder = self.root / 'phone/save';folder.mkdir(parents=True)
        (folder / 'progress.bin').write_bytes(b'phone progress')
        self.assertEqual(self.command('phone')['status'], 'available')
        revision = next(self.cloud.rglob('*.nxsave'))
        meta, entries = transfer.read_revision(revision)
        self.assertEqual(meta['title'], TITLE)
        self.assertEqual(entries[0].data, b'phone progress')
        destination = self.root / 'SD';destination.mkdir()
        result = transfer.export_switch(dict(source=str(revision), title=TITLE,
                                             fingerprint=transfer.inspect(revision)['fingerprint'],
                                             destination=str(destination), confirmed_console_requirement=True))
        self.assertEqual((Path(result['path']) / 'save/progress.bin').read_bytes(), b'phone progress')

    def test_account_only_import_cannot_discard_a_native_device_save(self):
        for name in ['save', 'save_device']:
            folder = self.root / 'phone' / name
            folder.mkdir(parents=True)
            (folder / 'progress.bin').write_bytes(name.encode())
        self.command('phone')
        before = {p.name:p.read_bytes() for p in self.cloud.rglob('*.nxsave')}
        with self.assertRaisesRegex(transfer.TransferError, 'incomplete_save_pair'):
            transfer.import_cloud(self.request())
        self.assertEqual({p.name:p.read_bytes() for p in self.cloud.rglob('*.nxsave')}, before)
        self.assertEqual((self.root / 'phone/save_device/progress.bin').read_bytes(), b'save_device')

    def test_existing_native_progress_conflicts_and_both_versions_remain(self):
        folder = self.root / 'phone/save';folder.mkdir(parents=True)
        (folder / 'progress.bin').write_bytes(b'original phone')
        self.command('phone')
        imported = self.revision()
        response = self.command('phone')
        self.assertEqual(response['status'], 'conflict')
        self.assertEqual((folder / 'progress.bin').read_bytes(), b'original phone')
        self.assertEqual(len(list(self.cloud.rglob('*.nxsave'))), 2)
        self.command('phone', 'resolve', imported.stem)
        self.assertEqual((folder / 'progress.bin').read_bytes(), b'console progress')
        self.assertGreaterEqual(len(list(self.cloud.rglob('*.nxsave'))), 3)
