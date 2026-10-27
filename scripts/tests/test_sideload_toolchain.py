"""Pinned tool bootstrap handles spaces and rejects unsafe archives without network."""
import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import build_sideload_helper as builder

class SideloadToolchain(unittest.TestCase):
    def archive(self,unsafe=False):
        data=io.BytesIO()
        with tarfile.open(fileobj=data,mode='w:xz') as tar:
            for name,content in [('pkg/components',b'rustc\n'),('pkg/rustc/manifest.in',b'file:bin/rustc\n'),('pkg/rustc/bin/rustc',b'synthetic compiler'),*([('../escape',b'bad')] if unsafe else [])]:
                info=tarfile.TarInfo(name);info.size=len(content);info.mode=0o755;tar.addfile(info,io.BytesIO(content))
        return data.getvalue()
    def check(self,unsafe):
        with tempfile.TemporaryDirectory(prefix='native toolchain spaces ') as temporary:
            root=Path(temporary);source=root/'source';config=source/'native/sideload-helper/toolchain.json';config.parent.mkdir(parents=True)
            archive=self.archive(unsafe);config.write_text(json.dumps({'version':'test','components':[{'component':'rustc','url':'https://example.invalid/rust.tar.xz','sha256':hashlib.sha256(archive).hexdigest()}]}))
            with patch.object(builder,'ROOT',source),patch.object(builder.urllib.request,'urlopen',side_effect=lambda *args,**kwargs:io.BytesIO(archive)) as download:
                if unsafe:
                    with self.assertRaisesRegex(ValueError,'Unsafe'):builder.toolchain(root/'cache')
                    self.assertFalse((root/'cache/escape').exists())
                else:
                    prefix=builder.toolchain(root/'cache');self.assertEqual((prefix/'bin/rustc').read_bytes(),b'synthetic compiler')
                    self.assertEqual(builder.toolchain(root/'cache'),prefix);self.assertEqual(download.call_count,1)
    def test_component_manifest_install_with_spaces_and_reuse(self):self.check(False)
    def test_unsafe_archive_is_rejected(self):self.check(True)
