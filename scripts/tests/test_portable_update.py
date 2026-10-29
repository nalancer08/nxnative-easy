"""Portable updates use checksummed archives and retain the installed app on failure."""
import hashlib
import importlib.util
import io
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch
import zipfile
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('portable_update',ROOT/'desktop/NxNativeEasy/update_app.py')
assert spec and spec.loader
update=importlib.util.module_from_spec(spec);spec.loader.exec_module(update)
REV='a'*40
class PortableUpdate(unittest.TestCase):
    def archive(self,extra=None):
        stream=io.BytesIO()
        with zipfile.ZipFile(stream,'w') as out:
            out.writestr('nxnative Easy.app/Contents/Info.plist',plistlib.dumps({'NxNativeSourceRevision':REV}))
            out.writestr('nxnative Easy.app/Contents/Resources/Source/SOURCE_REVISION',REV)
            if extra:out.writestr(extra,b'bad')
        return stream.getvalue()
    def prepare(self,root,payload,checksum=None):
        target=root/'Installed.app';target.mkdir();(target/'sentinel').write_bytes(b'previous app')
        def metadata(url):return {'sha':REV} if '/commits/' in url else {'version':'1.19.0','build':32}
        def download(url,**_):
            return io.BytesIO(((checksum or hashlib.sha256(payload).hexdigest())+'  nxnative-Easy-macOS-arm64.zip\n').encode() if url.endswith('SHA256SUMS') else payload)
        with patch.object(update,'manifest_url',side_effect=metadata),patch.object(update.urllib.request,'urlopen',side_effect=download),patch.object(update,'validate_app'):
            return update.portable_update(REV,32,target,root)
    def test_valid_release_stages_and_preserves_current_app(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);app,_=self.prepare(root,self.archive())
            self.assertTrue((app/'Contents/Info.plist').is_file())
            self.assertEqual((root/'Installed.app/sentinel').read_bytes(),b'previous app')
    def test_wrong_checksum_and_traversal_preserve_current_app(self):
        for payload,checksum in [(self.archive(),'0'*64),(self.archive('../escape'),None)]:
            with self.subTest(checksum=checksum),tempfile.TemporaryDirectory() as temp:
                root=Path(temp)
                with self.assertRaises(ValueError):self.prepare(root,payload,checksum)
                self.assertEqual((root/'Installed.app/sentinel').read_bytes(),b'previous app')
                self.assertEqual(list(root.glob('.nxnative-update-*')),[])
if __name__=='__main__':unittest.main()
