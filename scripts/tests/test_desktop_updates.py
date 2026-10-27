"""Update archive validation and transactional replacement, without altering installed apps."""
import importlib.util
import json
from pathlib import Path
import os
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
