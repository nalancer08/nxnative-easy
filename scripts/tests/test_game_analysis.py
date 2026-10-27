"""Analysis stays outside source, pins tools and never mutates original game code."""
import importlib.util
import json
import os
from pathlib import Path
import struct
import shlex
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import analyze_game


def nso():
    header=bytearray(0x100);header[:4]=b'NSO0'
    for i in range(3):struct.pack_into('<III',header,0x10+i*0x10,0x100+i*0x100,i*0x100,0x100)
    struct.pack_into('<III',header,0x60,0x100,0x100,0x100);header[0x40:0x60]=bytes(range(32))
    image=bytearray(0x300);struct.pack_into('<I',image,4,0x40);image[0x40:0x44]=b'MOD0'
    struct.pack_into('<iiiii',image,0x44,0xc0,0x2c0,0x2c0,0,0)
    return bytes(header+image)


class GameAnalysis(unittest.TestCase):
    def fixture(self,game,package='v1'):
        source=game/f'010093801237C000_build/extract/{package}/ExeFS/main'
        source.parent.mkdir(parents=True);source.write_bytes(nso())
        python=game/'nxnative-tools/venv/bin/python'
        python.parent.mkdir(parents=True,exist_ok=True)
        if not python.exists():
            python.write_text('#!/bin/sh\nexec '+shlex.quote(sys.executable)+' "$@"\n');python.chmod(0o700)
        return source,game/'nxnative-tools/analysis/run'

    @unittest.skipUnless(importlib.util.find_spec('lz4'),'NSO converter needs build dependency lz4')
    def test_actual_nso_to_elf_export_is_read_only(self):
        with tempfile.TemporaryDirectory() as temporary:
            game=Path(temporary);source,out=self.fixture(game);original=source.read_bytes()
            analyze_game.analyze(game,out)
            self.assertEqual(source.read_bytes(),original)
            self.assertEqual((out/'main.elf').read_bytes()[:4],b'\x7fELF')
            info=json.loads((out/'analysis.json').read_text())
            self.assertEqual(info['status'],'exported');self.assertFalse(info['automatically_ports_game'])
            self.assertEqual(info['main_build_id'],bytes(range(32)).hex())
            self.assertEqual(info['rea_version'],'6.8.0')
            with self.assertRaises(FileExistsError):analyze_game.analyze(game,out)

    def test_ambiguous_titles_and_outside_destination_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            game=Path(temporary);_,out=self.fixture(game)
            other=game/'0100000000000000_build/extract/v1/ExeFS/main';other.parent.mkdir(parents=True);other.write_bytes(nso())
            with self.assertRaisesRegex(ValueError,'exactly one'):analyze_game.prepared_module(game)
            with self.assertRaisesRegex(ValueError,'output must be'):analyze_game.analyze(game,game/'wrong')
            self.assertFalse(out.exists())

    def test_pinned_local_command_and_provider_failure_preserve_export(self):
        with tempfile.TemporaryDirectory() as temporary:
            game=Path(temporary);source,out=self.fixture(game)
            env=dict(os.environ)
            with patch.object(analyze_game.shutil,'which',return_value='/usr/local/bin/npm'):
                command=analyze_game.npm_command(out,env)
            self.assertIn('--package=node@24.22.1',command);self.assertIn('--package=rea-agents@6.8.0',command)
            self.assertNotIn('setup',command);self.assertNotIn('--global',command)
            def convert(*args,**kwargs):(out/'main.elf').write_bytes(b'\x7fELFfixture')
            class Failed:
                def __init__(self,*args,**kwargs):self.stderr=iter(['provider unavailable\n'])
                def __enter__(self):return self
                def __exit__(self,*args):pass
                def wait(self):return 1
            original=source.read_bytes()
            with patch.object(analyze_game.subprocess,'run',side_effect=convert),patch.object(analyze_game.subprocess,'Popen',Failed),patch.object(analyze_game,'npm_command',return_value=['npm','exec','rea']):
                with self.assertRaisesRegex(ValueError,'could not complete'):analyze_game.analyze(game,out,True,'ghidra')
            self.assertEqual(json.loads((out/'analysis.json').read_text())['status'],'failed')
            self.assertTrue((out/'main.elf').exists());self.assertEqual(source.read_bytes(),original)
