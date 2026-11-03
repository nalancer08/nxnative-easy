"""Real native save engine, synthetic saves and a local shared folder only.

Run on macOS: python3 -m unittest discover -s dm/host/tests -p test_cloud_saves.py
No iCloud, Keychain, real game files, signing or physical device is used.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import struct
import sys
import tempfile
import unittest

HOST = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HOST.parent / 'tools'))
import save_compat
import romfs_image


@unittest.skipUnless(sys.platform == 'darwin', 'Apple native save engine')
class CloudSaves(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix='nxe-cloud-engine-')
        cls.driver = Path(cls.build.name) / 'driver'
        subprocess.run(['clang', '-fobjc-arc', '-fobjc-arc-exceptions', '-fblocks', '-DNXE_CLOUD_TESTING',
                        '-Wno-deprecated-declarations', '-I', str(HOST),
                        str(HOST / 'tests/cloud_driver.m'), str(HOST / 'cloud_saves.m'),
                        str(HOST / 'save_archive.c'), '-framework', 'Foundation',
                        '-o', str(cls.driver)], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.build.cleanup()

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='nxe-fake-saves-')
        self.root = Path(self.tmp.name)
        self.cloud = self.root / 'shared'
        self.cloud.mkdir()
        self.devices = {}
        for name in ('phone', 'mac', 'ipad'):
            root = self.root / name
            root.mkdir()
            manifest = root / 'compat.json'
            manifest.write_text(json.dumps({'title': '010015100B514000', 'identity': 'a' * 64, 'version': '1.0'}))
            self.devices[name] = dict(os.environ, DM_SAVE=str(root / 'save'),
                                     NXE_SAVE_COMPAT=str(manifest), NXE_CLOUD_FOLDER=str(self.cloud))
            self.devices[name].pop('NXE_TEST_CLOUD_CRASH', None)
            self.devices[name].pop('NXE_TEST_CLOUD_FAIL', None)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, device, account, console=None):
        for name, data in [('save', account), ('save_device', console)]:
            if data is not None:
                folder = self.root / device / name
                folder.mkdir(exist_ok=True)
                (folder / 'progress.bin').write_bytes(data.encode())

    def contents(self, device):
        return tuple((self.root / device / name / 'progress.bin').read_bytes()
                     if (self.root / device / name / 'progress.bin').exists() else None
                     for name in ('save', 'save_device'))

    def run_command(self, device, command='check', argument='', *, crash=None, fail=None):
        env = dict(self.devices[device])
        if crash:
            env['NXE_TEST_CLOUD_CRASH'] = crash
        if fail:
            env['NXE_TEST_CLOUD_FAIL'] = fail
        p = subprocess.run([str(self.driver), command, argument], env=env,
                           capture_output=True, text=True, timeout=30)
        if crash:
            self.assertEqual(p.returncode, 86, p.stdout + p.stderr)
            return
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        return json.loads(p.stdout)

    def revisions(self):
        return list(self.cloud.rglob('*.nxsave'))

    def test_worker_flush_publishes_the_committed_pair_before_completion(self):
        self.write('phone', 'checkpoint account', 'checkpoint device')
        self.assertEqual(self.run_command('phone', 'flush')['status'], 'flushed')
        self.assertEqual(len(self.revisions()), 1)
        data = self.revisions()[0].read_bytes()
        length = struct.unpack('<I', data[:4])[0]
        self.assertEqual(json.loads(data[4:4 + length])['gameVersion'], '1.0')
        self.run_command('mac')
        self.assertEqual(self.contents('mac'), (b'checkpoint account', b'checkpoint device'))

    def test_disabled_flush_does_not_access_saves_or_create_history(self):
        self.devices['phone'].pop('NXE_CLOUD_FOLDER')
        self.write('phone', 'local only')
        self.assertEqual(self.run_command('phone', 'flush')['status'], 'flushed')
        self.assertFalse((self.root / 'phone/save.nxe-cloud').exists())
        self.assertEqual(self.revisions(), [])

    def test_bidirectional_continuity_with_both_folders(self):
        self.write('phone', 'phone one', 'console one')
        a = self.run_command('phone')
        self.assertEqual(a['status'], 'available')
        self.assertEqual(self.run_command('mac')['status'], 'available')
        self.assertEqual(self.contents('mac'), (b'phone one', b'console one'))
        self.write('mac', 'mac two', 'console two')
        self.run_command('mac')
        self.assertEqual(self.run_command('phone')['status'], 'available')
        self.assertEqual(self.contents('phone'), (b'mac two', b'console two'))
        self.assertGreater(len(list((self.root / 'phone/save.nxe-cloud/backups').glob('*.nxsave'))), 0)

    def test_initial_existing_saves_conflict_and_preserve_both(self):
        self.write('phone', 'phone branch', 'phone console')
        self.write('mac', 'mac branch', 'mac console')
        self.run_command('phone')
        reply = self.run_command('mac')
        self.assertEqual(reply['status'], 'conflict')
        self.assertEqual(len(reply['choices']), 2)
        self.assertEqual(self.contents('mac'), (b'mac branch', b'mac console'))
        self.assertEqual(len(self.revisions()), 2)
        old_ids = {p.stem for p in self.revisions()}
        remote = next(c for c in reply['choices'] if not c['local'])
        result = self.run_command('mac', 'resolve', remote['id'])
        self.assertEqual(result['status'], 'available', result)
        self.assertEqual(self.contents('mac'), (b'phone branch', b'phone console'))
        self.assertTrue(old_ids <= {p.stem for p in self.revisions()})
        self.assertEqual(len(result['history']), 3)
        self.assertEqual(self.run_command('phone')['status'], 'available')

    def test_simultaneous_offline_branches_ignore_clock_skew(self):
        self.write('phone', 'base', 'base console')
        self.run_command('phone')
        self.run_command('mac')
        self.devices['phone'].pop('NXE_CLOUD_FOLDER')
        self.devices['mac'].pop('NXE_CLOUD_FOLDER')
        self.write('phone', 'phone later', 'phone console')
        self.write('mac', 'mac later', 'mac console')
        os.utime(self.root / 'phone/save/progress.bin', (1, 1))
        os.utime(self.root / 'mac/save/progress.bin', (4000000000, 4000000000))
        self.run_command('phone')
        self.run_command('mac')
        for env in self.devices.values():
            env['NXE_CLOUD_FOLDER'] = str(self.cloud)
        self.run_command('phone')
        reply = self.run_command('mac')
        self.assertEqual(reply['status'], 'conflict')
        self.assertEqual(self.contents('mac'), (b'mac later', b'mac console'))
        self.assertEqual(self.contents('phone'), (b'phone later', b'phone console'))

    def test_restore_process_death_at_every_journal_boundary(self):
        for point in ('journal', 'moved-save', 'installed-save', 'moved-save_device', 'installed-save_device', 'state'):
            with self.subTest(point=point):
                self.write('phone', 'old', 'old device')
                self.run_command('phone')
                self.run_command('mac')
                self.write('mac', 'new ' + point, 'new device ' + point)
                self.run_command('mac')
                self.run_command('phone', crash=point)
                reply = self.run_command('phone')
                self.assertEqual(reply['status'], 'available', reply)
                self.assertEqual(self.contents('phone'), (('new ' + point).encode(), ('new device ' + point).encode()))
                self.assertFalse((self.root / 'phone/save.nxe-cloud/restore.json').exists())

    def test_failed_recovery_blocks_play_until_it_can_complete(self):
        self.write('phone', 'old', 'old device')
        self.run_command('phone')
        self.run_command('mac')
        self.write('mac', 'new', 'new device')
        self.run_command('mac')
        reply = self.run_command('phone', fail='installed-save')
        self.assertEqual(reply['status'], 'error')
        self.assertTrue(reply['blocksPlay'])
        reply = self.run_command('phone', 'local-play', fail='installed-save')
        self.assertTrue(reply['blocksPlay'])
        self.assertEqual(self.run_command('phone', 'local-play')['status'], 'local')
        self.assertEqual(self.contents('phone'), (b'new', b'new device'))

    def test_disk_full_on_snapshot_write_preserves_progress_and_remote(self):
        self.write('phone', 'cloud progress')
        self.run_command('phone')
        originals = {p.name: p.read_bytes() for p in self.revisions()}
        self.write('mac', 'local progress', 'local device')
        reply = self.run_command('mac', fail='snapshot-write')
        self.assertEqual(reply['status'], 'error')
        self.assertEqual(self.contents('mac'), (b'local progress', b'local device'))
        self.assertEqual(originals, {p.name: p.read_bytes() for p in self.revisions()})

    def test_corrupt_and_truncated_remote_do_not_replace_local(self):
        self.write('phone', 'source', 'source device')
        self.run_command('phone')
        source = self.revisions()[0]
        original = source.read_bytes()
        self.write('mac', 'keep me', 'keep console')
        for damaged in (original[:-1], original[:100] + b'broken' + original[106:]):
            source.write_bytes(damaged)
            reply = self.run_command('mac')
            self.assertEqual(reply['status'], 'error')
            self.assertEqual(self.contents('mac'), (b'keep me', b'keep console'))
        source.write_bytes(original)

    def test_version_mismatch_is_retained_but_never_restored(self):
        self.write('phone', 'version one')
        self.run_command('phone')
        manifest = self.root / 'mac/compat.json'
        manifest.write_text(json.dumps({'title': '010015100B514000', 'identity': 'b' * 64}))
        reply = self.run_command('mac')
        self.assertEqual(reply['status'], 'error')
        self.assertEqual(self.contents('mac'), (None, None))
        self.assertEqual(len(self.revisions()), 1)
        self.assertEqual(self.run_command('mac', 'local-play')['status'], 'local')

    def test_missing_parent_waits_without_restoring(self):
        self.write('phone', 'first')
        self.run_command('phone')
        first = self.revisions()[0]
        self.write('phone', 'second')
        self.run_command('phone')
        first.unlink()  # Simulates descendant delivery before its parent.
        reply = self.run_command('mac')
        self.assertEqual(reply['status'], 'error')
        self.assertEqual(self.contents('mac'), (None, None))

    def test_offline_and_sync_off_preserve_local_progress(self):
        self.write('phone', 'offline', 'device offline')
        self.cloud.rmdir()
        reply = self.run_command('phone')
        self.assertEqual(reply['status'], 'error')
        self.assertFalse(reply['blocksPlay'])
        self.assertEqual(self.contents('phone'), (b'offline', b'device offline'))
        self.assertEqual(self.run_command('phone', 'folder', '')['status'], 'local')

    def test_guest_names_and_empty_device_folder(self):
        self.write('phone', 'guest progress')
        p = self.root / 'phone/save/progress.bin'
        subprocess.run(['xattr', '-w', 'org.d2rmobile.guest-name', 'Progress.BIN', str(p)], check=True)
        self.run_command('phone')
        self.run_command('mac')
        q = self.root / 'mac/save/progress.bin'
        self.assertEqual(subprocess.check_output(['xattr', '-p', 'org.d2rmobile.guest-name', str(q)]).rstrip(b'\n'), b'Progress.BIN')
        self.assertEqual(self.contents('mac'), (b'guest progress', None))

    def test_symlink_is_refused_and_original_is_kept(self):
        self.write('phone', 'private')
        (self.root / 'phone/save/link').symlink_to(self.root / 'phone/compat.json')
        reply = self.run_command('phone')
        self.assertEqual(reply['status'], 'error')
        self.assertEqual(self.contents('phone'), (b'private', None))
        self.assertEqual(self.revisions(), [])

    def test_play_rechecks_then_running_session_never_imports(self):
        self.write('phone', 'first')
        self.run_command('phone')
        process = subprocess.Popen([str(self.driver), 'serve'], env=self.devices['mac'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        def send(command):
            process.stdin.write(command + '\n')
            process.stdin.flush()
            return json.loads(process.stdout.readline())
        try:
            self.assertEqual(send('check')['status'], 'available')
            self.write('phone', 'arrived while launcher open')
            self.run_command('phone')
            self.assertEqual(send('play')['status'], 'available')
            self.assertEqual(self.contents('mac'), (b'arrived while launcher open', None))
            self.write('phone', 'arrived during gameplay')
            self.run_command('phone')
            send('check')
            self.assertEqual(self.contents('mac'), (b'arrived while launcher open', None))
        finally:
            process.communicate(timeout=10)
        self.run_command('mac')
        self.assertEqual(self.contents('mac'), (b'arrived during gameplay', None))

    def test_new_conflict_at_play_requires_choice_before_start(self):
        self.write('phone', 'base')
        self.run_command('phone')
        process = subprocess.Popen([str(self.driver), 'serve'], env=self.devices['mac'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        def send(command):
            process.stdin.write(command + '\n')
            process.stdin.flush()
            return json.loads(process.stdout.readline())
        try:
            send('check')
            self.write('phone', 'phone branch')
            self.run_command('phone')
            self.write('mac', 'mac branch')
            result = send('play')
            self.assertEqual(result['status'], 'conflict')
            selected = next(c['id'] for c in result['choices'] if not c['local'])
            self.assertEqual(send('resolve ' + selected)['status'], 'available')
            self.assertEqual(self.contents('mac'), (b'phone branch', None))
        finally:
            process.communicate(timeout=10)

    def test_concurrent_publish_keeps_both_branches(self):
        self.write('phone', 'base')
        self.run_command('phone')
        self.run_command('mac')
        self.write('phone', 'concurrent phone')
        self.write('mac', 'concurrent mac')
        processes = [subprocess.Popen([str(self.driver), 'check'], env=self.devices[d], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for d in ('phone', 'mac')]
        for process in processes:
            stdout, stderr = process.communicate(timeout=30)
            self.assertEqual(process.returncode, 0, stderr)
            self.assertNotEqual(json.loads(stdout)['status'], 'error')
        reply = self.run_command('phone')
        self.assertEqual(reply['status'], 'conflict')
        self.assertEqual(len(reply['choices']), 2)
        self.assertEqual(self.contents('phone'), (b'concurrent phone', None))
        self.assertEqual(self.contents('mac'), (b'concurrent mac', None))

    def test_second_local_instance_cannot_use_same_save(self):
        self.write('phone', 'keep')
        env = dict(self.devices['phone'], NXE_TEST_HOLD_LEASE='1')
        process = subprocess.Popen([str(self.driver), 'local-play'], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            self.assertEqual(json.loads(process.stdout.readline())['status'], 'local')
            reply = self.run_command('phone', 'local-play')
            self.assertEqual(reply['status'], 'error')
            self.assertTrue(reply['blocksPlay'])
        finally:
            process.communicate(timeout=10)

    def test_path_traversal_payload_never_reaches_active_save(self):
        self.write('phone', 'safe')
        self.run_command('phone')
        revision = self.revisions()[0]
        data = revision.read_bytes()
        length = struct.unpack('<I', data[:4])[0]
        header, archive = data[:4 + length], bytearray(data[4 + length:])
        # One file: its entry header follows the fixed 144-byte archive header.
        old_length = struct.unpack_from('<H', archive, 146)[0]
        malicious = b'save/../../outside.bin'
        struct.pack_into('<H', archive, 146, len(malicious))
        archive[168:168 + old_length] = malicious
        damaged = header + archive
        revision.unlink()
        (revision.parent / (hashlib.sha256(damaged).hexdigest() + '.nxsave')).write_bytes(damaged)
        reply = self.run_command('mac')
        self.assertEqual(reply['status'], 'error')
        self.assertEqual(self.contents('mac'), (None, None))
        self.assertFalse((self.root / 'outside.bin').exists())

    def test_absent_and_empty_dlc_have_same_identity(self):
        root = self.root / 'content'
        root.mkdir()
        (root / 'game.bin').write_bytes(b'game')
        patched = self.root / 'patched'
        patched.mkdir()
        (patched / 'main.fixups.tsv').write_text('# BUILD_ID\t' + 'c' * 32 + '\n')
        dlc = self.root / 'empty-dlc'
        dlc.mkdir()
        first = save_compat.manifest('010015100B514000', '1.0', patched, root)
        second = save_compat.manifest('010015100B514000', '1.0', patched, root, dlc)
        self.assertEqual(first['identity'], second['identity'])
        (dlc / 'content.bin').write_bytes(b'add-on')
        self.assertNotEqual(first['identity'], save_compat.manifest('010015100B514000', '1.0', patched, root, dlc)['identity'])

    def test_directory_and_image_have_same_content_identity(self):
        root = self.root / 'romfs'
        root.mkdir()
        (root / 'data').mkdir()
        (root / 'data/game.bin').write_bytes(b'Synthetic RomFS')
        image = self.root / 'RomFS.img'
        romfs_image.pack(root, image)
        self.assertEqual(save_compat.content_identity(root), save_compat.content_identity(image))
        original = save_compat.content_identity(root)
        (root / 'data/game.bin').write_bytes(b'Changed game data')
        self.assertNotEqual(original, save_compat.content_identity(root))


if __name__ == '__main__':
    unittest.main()
