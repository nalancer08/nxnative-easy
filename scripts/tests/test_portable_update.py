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
        def metadata(url):return {'object':{'type':'commit','sha':REV}} if '/git/' in url else {'version':'1.19.0','build':32}
        def download(url,**_):
            return io.BytesIO(((checksum or hashlib.sha256(payload).hexdigest())+'  nxnative-Easy-macOS-arm64.zip\n').encode() if url.endswith('SHA256SUMS') else payload)
        with patch.object(update,'manifest_url',side_effect=metadata),patch.object(update.urllib.request,'urlopen',side_effect=download),patch.object(update,'validate_app'):
            return update.portable_update(REV,32,target,root)
    def test_valid_release_stages_and_preserves_current_app(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);app,_=self.prepare(root,self.archive())
            self.assertTrue((app/'Contents/Info.plist').is_file())
            self.assertEqual((root/'Installed.app/sentinel').read_bytes(),b'previous app')
    def test_annotated_tag_resolves_without_downloading_a_commit_patch(self):
        calls=[]
        def metadata(url):
            calls.append(url)
            if '/git/ref/tags/' in url:return {'object':{'type':'tag','sha':'b'*40}}
            if '/git/tags/' in url:return {'object':{'type':'commit','sha':REV}}
            raise AssertionError('The updater must not fetch the full commit/diff')
        with patch.object(update,'manifest_url',side_effect=metadata):
            self.assertEqual(update.release_revision('1.21.0'),REV)
        self.assertEqual(len(calls),2)
    def test_tag_cycle_wrong_object_and_invalid_versions_are_rejected(self):
        for obj in [{'type':'tag','sha':'b'*40},{'type':'tree','sha':REV},{'type':'commit','sha':'bad'},[]]:
            with self.subTest(obj=obj),patch.object(update,'manifest_url',return_value={'object':obj}):
                with self.assertRaises(ValueError):update.release_revision('1.21.0')
        with patch.object(update,'manifest_url',side_effect=AssertionError('No network for an invalid version')):
            with self.assertRaises(ValueError):update.release_revision('../main')
    def test_wrong_checksum_and_traversal_preserve_current_app(self):
        for payload,checksum in [(self.archive(),'0'*64),(self.archive('../escape'),None)]:
            with self.subTest(checksum=checksum),tempfile.TemporaryDirectory() as temp:
                root=Path(temp)
                with self.assertRaises(ValueError):self.prepare(root,payload,checksum)
                self.assertEqual((root/'Installed.app/sentinel').read_bytes(),b'previous app')
                self.assertEqual(list(root.glob('.nxnative-update-*')),[])
if __name__=='__main__':unittest.main()
