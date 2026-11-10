"""A cached portable runtime must gain newly required codecs without editing the installed app."""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('bundle_dependencies',ROOT/'scripts/bundle_tools.py')
assert spec and spec.loader
bundle=importlib.util.module_from_spec(spec);spec.loader.exec_module(bundle)


class PortableDependencies(unittest.TestCase):
    def test_retiring_staged_sdk_preserves_installed_and_symlink_targets(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);staged=root/'staged';staged.mkdir();installed=root/'installed';installed.mkdir()
            (installed/'sdk').write_text('keep');(staged/'dotnet').symlink_to(installed,target_is_directory=True)
            (staged/'nuget').mkdir();(staged/'nuget/cache').write_text('staged cache')
            (staged/'python').mkdir();bundle.retire_managed_runtime(staged)
            self.assertEqual((installed/'sdk').read_text(),'keep')
            self.assertFalse((staged/'dotnet').exists());self.assertFalse((staged/'nuget').exists())
            self.assertTrue((staged/'python').is_dir())

    def test_old_cached_bundle_installs_current_requirements_in_staged_copy(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);staged=root/'StagedTools';staged.mkdir()
            previous=root/'InstalledTools';previous.mkdir();(previous/'sentinel').write_text('old runtime')
            (staged/'manifest.json').write_text(json.dumps({'python':{'sha256':bundle.PYTHON_SHA}}))
            with patch.object(bundle.subprocess,'run') as install,patch.object(bundle,'build_reader',return_value='reader'),\
                    patch.object(bundle,'copy_notices'),patch.object(bundle,'dependency_sources',return_value={'zbic':{}}),\
                    patch.object(bundle,'run',return_value='10.0.403 [/staged/sdk]'):
                bundle.bundle(staged,root/'cache')
            args=install.call_args.args[0]
            self.assertEqual(args[0],str(staged/'python/bin/python3'))
            self.assertEqual(args[-1],str(ROOT/'desktop/portable-requirements.txt'))
            self.assertIn('zbic==1.0.1.post1',(ROOT/'desktop/portable-requirements.txt').read_text())
            self.assertEqual(json.loads((staged/'manifest.json').read_text())['python_requirements_sha256'],
                             hashlib.sha256((ROOT/'desktop/portable-requirements.txt').read_bytes()).hexdigest())
            self.assertEqual((previous/'sentinel').read_text(),'old runtime')

    def test_failed_dependency_install_does_not_publish_refreshed_manifest(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);staged=root/'StagedTools';staged.mkdir()
            old=json.dumps({'python':{'sha256':bundle.PYTHON_SHA}});(staged/'manifest.json').write_text(old)
            with patch.object(bundle.subprocess,'run',side_effect=subprocess.CalledProcessError(1,['pip'])):
                with self.assertRaises(subprocess.CalledProcessError):bundle.bundle(staged,root/'cache')
            self.assertEqual((staged/'manifest.json').read_text(),old)

    def test_corrupt_corresponding_source_is_not_shipped(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);cache=root/'cache';cache.mkdir();staged=root/'Tools';staged.mkdir()
            (cache/'zbic-1.0.1.post1.tar.gz').write_bytes(b'wrong source')
            with self.assertRaisesRegex(ValueError,'checksum'):bundle.dependency_sources(staged,cache)
            self.assertFalse((staged/'Licenses/zbic-1.0.1.post1.tar.gz').exists())

    def test_exact_corresponding_source_is_included(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);cache=root/'cache';cache.mkdir();staged=root/'Tools';staged.mkdir()
            payload=b'synthetic source archive';(cache/'zbic-1.0.1.post1.tar.gz').write_bytes(payload)
            with patch.object(bundle,'ZBIC_SOURCE_SHA',hashlib.sha256(payload).hexdigest()):
                result=bundle.dependency_sources(staged,cache)
            self.assertEqual((staged/'Licenses/zbic-1.0.1.post1.tar.gz').read_bytes(),payload)
            self.assertEqual(result['zbic']['version'],'1.0.1.post1')


if __name__=='__main__':unittest.main()
