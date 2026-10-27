"""A failed launcher rebuild must not damage a previous installation."""
import importlib.util
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('desktop_builder',ROOT/'scripts/build_desktop_app.py')
assert spec is not None and spec.loader is not None
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)

class DesktopInstall(unittest.TestCase):
    def old_app(self,root,identifier='com.nalancer08.nxnative.easy'):
        app=root/'Easy.app';(app/'Contents').mkdir(parents=True)
        (app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':identifier}))
        (app/'marker').write_text('previous')
        return app

    def test_failed_compile_preserves_installed_app(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);app=self.old_app(root)
            with patch.object(sys,'argv',['builder','--output',str(app)]),patch.object(builder,'build_bundle',side_effect=subprocess.CalledProcessError(1,'swiftc')):
                with self.assertRaises(subprocess.CalledProcessError):builder.main()
            self.assertEqual((app/'marker').read_text(),'previous')
            self.assertEqual(list(root.glob('.nxnative-build-*')),[])

    def test_success_keeps_backup_and_failed_swap_rolls_back(self):
        for fail in (False,True):
            with self.subTest(fail=fail),tempfile.TemporaryDirectory() as temporary:
                root=Path(temporary);app=self.old_app(root);staged=root/'New.app';staged.mkdir()
                (staged/'marker').write_text('new')
                replace=builder.os.replace
                def swap(source,destination,fail=fail,staged=staged,replace=replace):
                    if fail and source==staged:raise OSError('simulated swap failure')
                    return replace(source,destination)
                with patch.object(builder.os,'replace',side_effect=swap):
                    if fail:
                        with self.assertRaises(OSError):builder.install_bundle(staged,app)
                    else:builder.install_bundle(staged,app)
                self.assertEqual((app/'marker').read_text(),'previous' if fail else 'new')
                if not fail:self.assertEqual((next(root.glob('.Easy.app.previous-*'))/'marker').read_text(),'previous')

    def test_other_app_is_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);app=self.old_app(root,'another.app');staged=root/'New.app';staged.mkdir()
            with self.assertRaises(ValueError):builder.install_bundle(staged,app)
            self.assertEqual((app/'marker').read_text(),'previous')
