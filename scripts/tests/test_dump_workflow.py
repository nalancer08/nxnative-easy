"""Synthetic extracted-game preflight, source integrity and complete Mac output."""
import json
from pathlib import Path
import plistlib
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_mac
import inspect_dump
import inspect_game
import pack_dump

TITLE = '040074A01BF12000'


def fixture(root, title=TITLE, version=None):
    source = root / ('base' if version is None else f'updates/{version}')
    (source / 'exefs').mkdir(parents=True)
    (source / 'romfs').mkdir()
    npdm = bytearray(0xa0)
    npdm[:4] = b'META'
    struct.pack_into('<II', npdm, 0x70, 0x80, 0x20)
    npdm[0x80:0x84] = b'ACI0'
    struct.pack_into('<Q', npdm, 0x90, int(title, 16))
    (source / 'exefs/main.npdm').write_bytes(npdm)
    code = bytearray(0x100)
    code[:4] = b'NSO0'
    rows = (inspect_dump.REPO / 'dm/games' / TITLE / 'game.tsv').read_text().splitlines()
    build = next(token[5:] for line in rows if line.startswith('build\t') for token in line.split('\t')[3:] if token.startswith('main='))
    code[0x40:0x60] = bytes.fromhex(build.ljust(64, '0'))
    (source / 'exefs/main').write_bytes(code)
    (source / 'romfs/synthetic.dat').write_bytes(b'synthetic assets')
    return source


class DumpWorkflow(unittest.TestCase):
    def test_verified_package_bridge_accepts_new_scanner_arguments_and_rejects_another_title(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);package=root/'untagged.nsp';package.write_bytes(b'synthetic')
            title='010093801237C000'
            value=dict(schema=1,status='ready',errors=[],sources={package.name:[package.stat().st_size,package.stat().st_mtime_ns]},
                       title_id=title,packages=[dict(file=package.name,title_id=title,kind='base',version=0)])
            metadata=root/'checked.json';metadata.write_text(json.dumps(value))
            builder=build_mac.load_builder(metadata)
            app,family=builder.scan_nsps(root,object(),object(),int(title,16))
            self.assertEqual(app,int(title,16));self.assertEqual(family['base'],package.resolve())
            with self.assertRaisesRegex(ValueError,'differs'):
                builder.scan_nsps(root,object(),object(),int(title,16)+0x1000)

    def test_identifies_title_build_and_updates_without_keys_or_tool_setup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture(root)
            fixture(root, version=458752)
            with patch.object(inspect_game.subprocess, 'run', side_effect=AssertionError('No package reader needed')):
                result = inspect_game.inspect(root, None, root / 'unused-cache')
            assert result is not None
            self.assertEqual(result['status'], 'ready')
            self.assertEqual(result['name'], 'Donkey Kong Bananza')
            self.assertEqual(result['title_id'], TITLE)
            self.assertEqual(result['platform'], 'switch2')
            self.assertEqual(result['selected_file'], 'updates/458752')
            self.assertEqual(len(result['updates']), 1)
            self.assertIsNone(result['display_version'])
            self.assertFalse((root / 'unused-cache').exists())

    def test_unknown_title_is_not_advertised_as_supported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture(root, title='0400123412340000')
            result = inspect_dump.inspect_dump(root)
            assert result is not None
            self.assertEqual(result['status'], 'profile_missing')
            self.assertIsNone(result['name'])

    def test_asset_change_rejects_stale_preflight_without_replacing_record(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture(root)
            manifest = inspect_dump.inspect_dump(root)
            (root / 'base/romfs/synthetic.dat').write_bytes(b'changed')
            record = root / 'nxnative-mac.json'
            record.write_text('{"schema": 1, "app_path": "old"}')
            metadata = root / 'checked.json'
            metadata.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, 'changed'):
                build_mac.main([directory, '--package-metadata', str(metadata), '--dry-run'])
            self.assertEqual(json.loads(record.read_text())['app_path'], 'old')

    def test_mixed_updates_links_and_ambiguous_sources_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture(root)
            other = fixture(root, title='0400123412340000', version=1)
            with self.assertRaisesRegex(ValueError, 'mixed'):
                inspect_dump.inspect_dump(root)
            (other / 'exefs/main.npdm').write_bytes((root / 'base/exefs/main.npdm').read_bytes())
            link = root / 'base/romfs/link'
            link.symlink_to('/private/tmp')
            with self.assertRaisesRegex(ValueError, 'link'):
                inspect_dump.inspect_dump(root)
            link.unlink()
            (root / 'another.nsp').write_bytes(b'synthetic')
            ambiguous = inspect_dump.inspect_dump(root)
            assert ambiguous is not None
            self.assertEqual(ambiguous['status'], 'multiple_sources')

    def test_truncated_npdm_never_leaks_struct_errors(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'main.npdm'
            path.write_bytes(b'META')
            with self.assertRaises(pack_dump.Error):
                pack_dump.program_id(path)

    def test_mac_dump_build_needs_no_keys_and_keeps_bundle_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture(root)
            record = root / 'nxnative-mac.json'
            record.write_text(json.dumps(dict(schema=1, app_path='old', bundle_id='org.example.same', title_id=TITLE)))

            class Builder:
                def cli(self, args):
                    self_args = args
                    if '-k' in self_args:
                        raise AssertionError('An extracted dump must not request keys')
                    output = Path(args[args.index('-o') + 1])
                    (output / 'Contents/MacOS').mkdir(parents=True)
                    (output / 'Contents/Resources').mkdir()
                    (output / 'Contents/MacOS/dmhost').write_bytes(b'synthetic executable')
                    (output / 'Contents/Resources/romfs.img').write_bytes(b'synthetic image')
                    (output / 'Contents/Info.plist').write_bytes(plistlib.dumps(dict(
                        CFBundleIdentifier=args[args.index('--bundle-id') + 1], DMTitleID=TITLE,
                        CFBundleShortVersionString='1.0.0')))
                    return 0

            with patch.object(build_mac, 'load_builder', return_value=Builder()), \
                 patch.object(build_mac.platform, 'machine', return_value='arm64'), \
                 patch.object(build_mac, 'select_keys', side_effect=AssertionError('No key picker')):
                self.assertEqual(build_mac.main([directory]), 0)
            saved = json.loads(record.read_text())
            self.assertEqual(saved['bundle_id'], 'org.example.same')
            self.assertTrue((Path(saved['app_path']) / 'Contents/Resources/romfs.img').is_file())
            self.assertEqual((root / 'base/romfs/synthetic.dat').read_bytes(), b'synthetic assets')


if __name__ == '__main__':
    unittest.main()
