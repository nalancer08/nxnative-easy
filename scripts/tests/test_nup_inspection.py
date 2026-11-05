"""NUP identification and stale-input refusal use synthetic containers only."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import build_mac

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
import inspect_nup
spec=importlib.util.spec_from_file_location('nup_fixture',ROOT/'dm/tools/tests/test_nsp_nup.py')
assert spec is not None and spec.loader is not None
fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)


@unittest.skipIf(fixture.zstd is None,'NUP zstd codec required')
class NupInspection(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.path=self.root/'arbitrary-name.nup'
        self.code=b'NSO0'+bytes(252)
        self.write()

    def write(self):
        fixture.write_nup(self.path,[(0,fixture.TID,0,fixture.version(main=self.code),fixture.META)])

    def test_identifies_real_metadata_without_keys_or_extraction(self):
        value=inspect_nup.inspect_keyless(self.root)
        assert value is not None
        self.assertEqual((value['status'],value['input_kind'],value['name']),('ready','nup','Test Game'))
        self.assertEqual(value['title_id'],f'{fixture.TID:016X}')
        self.assertEqual(value['display_version'],'1.2.3')
        self.assertEqual(list(self.root.iterdir()),[self.path])
        self.assertEqual(inspect_nup.validate_keyless(self.root,value),value)

    def test_changed_input_and_mixed_sources_are_refused(self):
        value=inspect_nup.inspect_keyless(self.root)
        assert value is not None
        self.code=b'NSO0'+bytes([1])*252;self.write()
        with self.assertRaises(ValueError):inspect_nup.validate_keyless(self.root,value)
        (self.root/'other.nsp').write_bytes(b'package')
        mixed=inspect_nup.inspect_keyless(self.root)
        assert mixed is not None
        self.assertEqual(mixed['status'],'multiple_sources')

    def test_damaged_container_never_becomes_ready(self):
        data=bytearray(self.path.read_bytes());data[0x85]^=1;self.path.write_bytes(data)
        with self.assertRaises(inspect_nup.pack_nup.Error):inspect_nup.inspect_keyless(self.root)

    def test_mac_wrapper_skips_keys_and_keeps_builder_failure(self):
        class Builder:
            def cli(self, command):
                self.command=command
                return 7
        builder=Builder()
        with patch.object(build_mac,'load_builder',return_value=builder) as load, \
             patch.object(build_mac.platform,'machine',return_value='arm64'), \
             patch.object(build_mac.sys,'platform','darwin'), \
             patch.object(build_mac,'select_keys',side_effect=AssertionError('NUP needs no key picker')):
            self.assertEqual(build_mac.main([str(self.root)]),7)
        load.assert_called_once_with(None)
        self.assertNotIn('-k',builder.command)
        self.assertFalse((self.root/'nxnative-mac.json').exists())
