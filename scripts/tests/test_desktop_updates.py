"""Update archive validation and transactional replacement, without altering installed apps."""
import importlib.util
import json
from pathlib import Path
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('desktop_update',ROOT/'desktop/NxNativeEasy/update_app.py')
assert spec is not None and spec.loader is not None
update=importlib.util.module_from_spec(spec);spec.loader.exec_module(update)
REVISION='a'*40
PREFIX='nxnative-easy-'+REVISION+'/'

class DesktopUpdate(unittest.TestCase):
    def test_rejects_unsafe_and_credential_archive_before_extracting(self):
        for name in ['../escape','/absolute',PREFIX+'../escape',PREFIX+'prod.keys',PREFIX+'game.nsp']:
            with self.subTest(name=name),tempfile.TemporaryDirectory() as tmp:
                root=Path(tmp);archive=root/'test.zip'
                with zipfile.ZipFile(archive,'w') as z:z.writestr(name,b'synthetic')
                with self.assertRaises(ValueError):update.extract(archive,root/'source',REVISION)
                self.assertFalse((root/'source').exists())

    def test_rejects_symlinks_and_wrong_revision(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);archive=root/'test.zip'
            info=zipfile.ZipInfo(PREFIX+'link');info.external_attr=0o120777<<16
            with zipfile.ZipFile(archive,'w') as z:z.writestr(info,'outside')
            with self.assertRaises(ValueError):update.extract(archive,root/'source',REVISION)
            with zipfile.ZipFile(archive,'w') as z:z.writestr('wrong-root/file','synthetic')
            with self.assertRaises(ValueError):update.extract(archive,root/'source',REVISION)

    def test_extracts_regular_sources_and_executable_permissions(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);archive=root/'test.zip'
            info=zipfile.ZipInfo(PREFIX+'scripts/setup.sh');info.external_attr=0o100755<<16
            with zipfile.ZipFile(archive,'w') as z:z.writestr(info,'#!/bin/bash\n')
            update.extract(archive,root/'source',REVISION)
            self.assertTrue(os.access(root/'source/scripts/setup.sh',os.X_OK))

    def test_replacement_preserves_old_app_and_unrelated_data(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);old=root/'Current.app';new=root/'New.app';old.mkdir();new.mkdir()
            (old/'marker').write_text('old');(new/'marker').write_text('new')
            (root/'save').write_text('keep')
            backup=update.replace_bundle(new,old)
            self.assertEqual((old/'marker').read_text(),'new')
            self.assertEqual((backup/'marker').read_text(),'old')
            self.assertEqual((root/'save').read_text(),'keep')

    def test_install_failure_rolls_back_old_app(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);old=root/'Current.app';new=root/'New.app';old.mkdir();new.mkdir()
            (old/'marker').write_text('old');(new/'marker').write_text('new')
            real_replace=os.replace
            def replace(source,destination):
                if source==new:raise OSError('synthetic installation failure')
                return real_replace(source,destination)
            with patch.object(update.os,'replace',side_effect=replace):
                with self.assertRaises(OSError):update.replace_bundle(new,old)
            self.assertEqual((old/'marker').read_text(),'old')

    def test_invalid_release_metadata_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'release.json'
            for value in [{'version':'invalid','build':5},{'version':'1.4','build':True},{'version':'1.4','build':-1}]:
                path.write_text(json.dumps(value))
                with self.assertRaises(ValueError):update.manifest(path)

class ReleaseMetadata(unittest.TestCase):
    @unittest.skipUnless(__import__('sys').platform=='darwin','requires Swift Foundation')
    def test_version_selection(self):
        import subprocess
        with tempfile.TemporaryDirectory() as tmp:
            executable=Path(tmp)/'release'
            subprocess.run(['xcrun','swiftc','-parse-as-library',str(ROOT/'desktop/NxNativeEasy/UpdateRelease.swift'),
                            str(ROOT/'desktop/NxNativeEasy/tests/update_release_check.swift'),'-o',str(executable)],check=True)
            subprocess.run([str(executable)],check=True)


class InstalledStorageCleanup(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.cache = self.root/'Support/Updates'
        self.cache.mkdir(parents=True)
        self.sources = self.cache.parent/'PortableSources'
        self.app = self.root/'Easy.app'

    def app_bundle(self, path, build, revision, **metadata):
        contents = path/'Contents'
        seed = contents/'Resources/Source'
        (seed/'scripts').mkdir(parents=True)
        (seed/'scripts/prepare_ios.sh').write_text('#!/bin/bash\n')
        (seed/'SOURCE_REVISION').write_text(revision+'\n')
        entries = ['SOURCE_REVISION', 'scripts/prepare_ios.sh']
        index = {name: update.file_hash(seed/name) for name in entries}
        (seed/'SOURCE_INDEX.json').write_text(json.dumps(index))
        info = dict(CFBundleIdentifier=update.IDENTIFIER, CFBundleVersion=str(build),
                    CFBundleShortVersionString=f'1.0.{build}', NxNativeSourceRevision=revision)
        info.update(metadata)
        (contents/'Info.plist').write_bytes(plistlib.dumps(info))
        return seed

    def previous(self, number):
        return self.root/f'.Easy.app.previous-{number:010x}'

    def run_cleanup(self, opened=()):
        with patch.object(update,'validate_app'), patch.object(update,'open_user_paths',return_value=opened), patch.object(update,'emit'):
            update.clean_installed_storage(self.app,self.cache)

    def test_legacy_update_first_launch_prunes_obsolete_bundle_and_pristine_source(self):
        old_seed = self.app_bundle(self.previous(1),1,'a'*40)
        old_cache = self.sources/('a'*40)
        shutil.copytree(old_seed,old_cache)
        previous_seed = self.app_bundle(self.app,2,'b'*40)
        previous_cache = self.sources/('b'*40)
        shutil.copytree(previous_seed,previous_cache)
        staged = self.root/'Staged.app'
        self.app_bundle(staged,3,'c'*40)
        # The installed legacy updater only performed the swap.
        rollback = update.replace_bundle(staged,self.app)
        save = self.cache.parent/'library.json'
        save.write_text('keep')
        with patch.object(sys,'argv',['update_app.py','--cleanup-only','--target',str(self.app),'--cache',str(self.cache)]), \
             patch.object(update.os,'setsid'), patch.object(update,'validate_app'), \
             patch.object(update,'open_user_paths',return_value=[]), patch.object(update,'emit'):
            update.main()
        self.assertFalse(self.previous(1).exists())
        self.assertFalse(old_cache.exists())
        self.assertTrue(rollback.is_dir())
        self.assertTrue(previous_cache.is_dir())
        self.assertEqual(save.read_text(),'keep')
        self.assertEqual(len(list(self.cache.glob('storage-*.json'))),1)

    def test_foreign_and_locally_modified_files_are_preserved(self):
        clean_seed = self.app_bundle(self.previous(1),1,'a'*40)
        edited = self.sources/('a'*40)
        shutil.copytree(clean_seed,edited)
        (edited/'scripts/prepare_ios.sh').write_text('local change')
        self.app_bundle(self.previous(2),2,'b'*40,NxNativeLocalModifications=True)
        self.app_bundle(self.previous(3),3,'c'*40,CFBundleIdentifier='different.app')
        self.previous(4).symlink_to(self.previous(3),target_is_directory=True)
        self.app_bundle(self.previous(5),5,'d'*40)
        self.app_bundle(self.app,6,'e'*40)
        self.run_cleanup()
        self.assertEqual((edited/'scripts/prepare_ios.sh').read_text(),'local change')
        self.assertFalse(self.previous(1).exists())
        for n in (2,3,4,5):
            self.assertTrue(self.previous(n).exists())

    def test_live_old_source_defers_cleanup_until_next_launch(self):
        seed = self.app_bundle(self.previous(1),1,'a'*40)
        copied = self.sources/('a'*40)
        shutil.copytree(seed,copied)
        self.app_bundle(self.previous(2),2,'b'*40)
        self.app_bundle(self.app,3,'c'*40)
        self.run_cleanup([str(copied/'scripts/prepare_ios.sh')])
        self.assertTrue(self.previous(1).exists())
        self.assertTrue(copied.exists())
        self.assertFalse(list(self.cache.glob('storage-*.json')))
        self.run_cleanup()
        self.assertFalse(copied.exists())
        self.assertFalse(self.previous(1).exists())

    def test_unverified_new_install_does_not_delete_backups(self):
        self.app_bundle(self.previous(1),1,'a'*40)
        self.app_bundle(self.previous(2),2,'b'*40)
        self.app_bundle(self.app,3,'c'*40)
        with patch.object(update,'validate_app',side_effect=subprocess.CalledProcessError(1,'codesign')):
            with self.assertRaises(subprocess.CalledProcessError):
                update.clean_installed_storage(self.app,self.cache)
        self.assertTrue(self.previous(1).exists())
        self.assertTrue(self.previous(2).exists())
