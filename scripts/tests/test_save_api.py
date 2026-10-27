"""Cloud API regression fixtures are synthetic; no real game/save/account is used."""
from contextlib import closing
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import secrets
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'dm/cloud'))
import save_api as api

TITLE='010093801237C000'


def snapshot(content=b'synthetic save',path='account/progress.bin'):
    record=dict(path=path,kind='file',size=len(content),sha256=hashlib.sha256(content).hexdigest())
    metadata=dict(schema=1,title_id=TITLE,build_id='a'*64,game_version='2.1.0',entries=[record])
    stream=io.BytesIO()
    with zipfile.ZipFile(stream,'w',zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('manifest.json',json.dumps(metadata));archive.writestr(path,content)
    return stream.getvalue()


class SaveStore(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.store=api.SaveStore(Path(self.temp.name)/'saves.sqlite3');self.payload=snapshot()

    def test_conflicts_keep_history_and_accounts_are_isolated(self):
        first=self.store.put('alice',TITLE,'default',self.payload,'')
        second=self.store.put('alice',TITLE,'default',snapshot(b'new progress'),first)
        for expected in ('',first):
            with self.assertRaises(api.APIError) as failure:self.store.put('alice',TITLE,'default',self.payload,expected)
            self.assertEqual(failure.exception.status,412)
        self.assertEqual(self.store.get('alice',TITLE,'default')['id'],second)
        self.assertEqual(self.store.get('alice',TITLE,'default',first)['payload'],self.payload)
        self.assertEqual(self.store.list('bob',TITLE),[])
        self.assertEqual({r['revision'] for r in self.store.history('alice',TITLE,'default')},{first,second})
        self.assertEqual(self.store.history('bob',TITLE,'default'),[])
        with self.assertRaises(api.APIError):self.store.get('bob',TITLE,'default',first)

    def test_precondition_quota_and_title_checks_preserve_existing_data(self):
        first=self.store.put('alice',TITLE,'default',self.payload,'')
        with self.assertRaises(api.APIError) as failure:self.store.put('alice',TITLE,'default',self.payload,None)
        self.assertEqual(failure.exception.status,428)
        with patch.object(api,'MAX_ACCOUNT',len(self.payload)):
            with self.assertRaises(api.APIError):self.store.put('alice',TITLE,'default',self.payload,first)
        with self.assertRaises(api.APIError):self.store.put('alice','0100000000000000','default',self.payload,'')
        self.assertEqual(self.store.get('alice',TITLE,'default')['id'],first)

    def test_sharing_is_expiring_revocable_and_copies_one_immutable_version(self):
        first=self.store.put('alice',TITLE,'default',self.payload,'')
        share=self.store.share('alice',TITLE,'default',first,60)
        self.store.put('alice',TITLE,'default',snapshot(b'newer save'),first)
        copied=self.store.copy_share('bob',share['token'],TITLE,'from-alice','')
        self.assertEqual(self.store.get('bob',TITLE,'from-alice',copied)['payload'],self.payload)
        with self.assertRaises(api.APIError):self.store.revoke('bob',share['id'])
        with patch.object(api.time,'time',return_value=time.time()+61):
            with self.assertRaises(api.APIError):self.store.copy_share('bob',share['token'],TITLE,'expired','')
        self.store.revoke('alice',share['id'])
        with self.assertRaises(api.APIError):self.store.copy_share('bob',share['token'],TITLE,'revoked','')
        self.assertEqual(self.store.get('bob',TITLE,'from-alice',copied)['payload'],self.payload)

    def test_bad_archives_and_paths_are_rejected(self):
        for path in ('../outside','account/../outside','account/prod.keys','account/game.nsp','romfs/game.bin','account/link/../../outside','account\\bad.bin'):
            with self.subTest(path=path),self.assertRaises(api.APIError):api.save_manifest(snapshot(path=path))
        with self.assertRaises(api.APIError):api.save_manifest(b'not a zip')
        with self.assertRaises(api.APIError):self.store.put('alice',TITLE,'../outside',self.payload,'')
        # The JSON's hash does not authenticate different compressed bytes.
        raw=io.BytesIO(self.payload);out=io.BytesIO()
        with zipfile.ZipFile(raw) as source,zipfile.ZipFile(out,'w') as target:
            for entry in source.infolist():
                content=source.read(entry)
                if entry.filename=='account/progress.bin':content=b'changed save'
                target.writestr(entry,content)
        with self.assertRaises(api.APIError):api.save_manifest(out.getvalue())

    def test_concurrent_writers_cannot_silently_overwrite(self):
        first=self.store.put('alice',TITLE,'default',self.payload,'')
        barrier=threading.Barrier(2);outcomes=[]
        def write():
            barrier.wait()
            try:outcomes.append(self.store.put('alice',TITLE,'default',snapshot(secrets.token_bytes(20)),first))
            except api.APIError as error:outcomes.append(error.status)
        threads=[threading.Thread(target=write) for _ in range(2)]
        for thread in threads:thread.start()
        for thread in threads:thread.join(timeout=10)
        self.assertEqual(sum(isinstance(value,str) for value in outcomes),1)
        self.assertIn(412,outcomes)

    def test_real_http_requires_auth_and_preconditions(self):
        from wsgiref.simple_server import make_server, WSGIRequestHandler
        class Quiet(WSGIRequestHandler):
            def log_message(self,format,*args):pass
        def verify(token):
            if token!='test-alice':raise api.APIError(401,'invalid test identity')
            return 'alice'
        server=make_server('127.0.0.1',0,api.SaveAPI(self.store,verify),handler_class=Quiet)
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        try:
            base=f'http://127.0.0.1:{server.server_port}'
            with closing(urlopen(base+'/health')) as response:self.assertEqual(response.status,200)
            with self.assertRaises(HTTPError) as failure:urlopen(base+'/v1/me')
            self.assertEqual(failure.exception.code,401)
            endpoint=base+f'/v1/games/{TITLE}/saves/default/snapshot'
            headers={'Authorization':'Bearer test-alice','If-None-Match':'*'}
            with closing(urlopen(Request(endpoint,data=self.payload,headers=headers,method='PUT'))) as response:
                self.assertEqual(response.status,201);revision=json.load(response)['revision']
            with self.assertRaises(HTTPError) as failure:urlopen(Request(endpoint,data=self.payload,headers=headers,method='PUT'))
            self.assertEqual(failure.exception.code,412)
            with closing(urlopen(Request(endpoint,headers={'Authorization':'Bearer test-alice'}))) as response:
                self.assertEqual(response.read(),self.payload);self.assertEqual(response.headers['ETag'],'"'+revision+'"')
        finally:server.shutdown();server.server_close();thread.join(timeout=5)


@unittest.skipUnless(importlib.util.find_spec('jwt'),'install dm/cloud/requirements.txt for real JWT checks')
class Identity(unittest.TestCase):
    def test_real_signed_token_validates_signature_issuer_audience_and_expiry(self):
        import jwt
        from jwt.algorithms import RSAAlgorithm
        from cryptography.hazmat.primitives.asymmetric import rsa
        key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        issuer='https://identity.example.invalid';audience='nxnative-save-api'
        verifier=api.oidc_verifier(issuer,audience,issuer+'/jwks')
        jwk=jwt.PyJWK.from_json(RSAAlgorithm.to_jwk(key.public_key()))
        claims=dict(iss=issuer,aud=audience,sub='alice',iat=int(time.time()),exp=int(time.time())+300)
        with patch.object(jwt.PyJWKClient,'get_signing_key_from_jwt',return_value=jwk):
            valid=jwt.encode(claims,key,algorithm='RS256')
            self.assertEqual(verifier(valid),hashlib.sha256((issuer+'\0alice').encode()).hexdigest())
            for changes in ({'iss':'https://other.invalid'},{'aud':'other-app'},{'exp':int(time.time())-120}):
                with self.subTest(changes=changes),self.assertRaises(api.APIError):verifier(jwt.encode(dict(claims,**changes),key,algorithm='RS256'))
            with self.assertRaises(api.APIError):verifier(jwt.encode(claims,'synthetic-test-key-with-32-bytes-minimum',algorithm='HS256'))
            other=rsa.generate_private_key(public_exponent=65537,key_size=2048)
            with self.assertRaises(api.APIError):verifier(jwt.encode(claims,other,algorithm='RS256'))
        with self.assertRaises(ValueError):api.oidc_verifier(issuer,audience,'https://other.invalid/jwks')


class PortableBackup(unittest.TestCase):
    def test_committed_wal_history_and_shares_survive_relocation(self):
        from scripts.backup_save_api import backup
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);source=root/'source.sqlite3';store=api.SaveStore(source)
            # Keep a connection open so committed records can remain in the WAL.
            with closing(store.connect()) as keeper:
                keeper.execute('PRAGMA journal_mode=WAL')
                payload=snapshot();first=store.put('alice',TITLE,'default',payload,'')
                share=store.share('alice',TITLE,'default',first,60)
                second=store.put('alice',TITLE,'default',snapshot(b'new'),first)
                target=backup(source,root/'moved.sqlite3')
                moved=api.SaveStore(target)
                self.assertEqual(moved.get('alice',TITLE,'default')['id'],second)
                self.assertEqual(len(moved.history('alice',TITLE,'default')),2)
                copied=moved.copy_share('bob',share['token'],TITLE,'shared','')
                self.assertEqual(moved.get('bob',TITLE,'shared',copied)['payload'],payload)
                self.assertEqual(store.list('bob',TITLE),[])
                self.assertEqual(target.stat().st_mode&0o777,0o600)
                with self.assertRaises(FileExistsError):backup(source,target)

    def test_missing_and_unrelated_sources_are_not_created_or_published(self):
        from scripts.backup_save_api import backup
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);missing=root/'missing.sqlite3';target=root/'backup.sqlite3'
            with self.assertRaises(FileNotFoundError):backup(missing,target)
            self.assertFalse(missing.exists());self.assertFalse(target.exists())
            source=root/'unrelated.sqlite3'
            with closing(api.sqlite3.connect(source)) as db:db.execute('CREATE TABLE other(value)')
            with self.assertRaises(ValueError):backup(source,target)
            self.assertFalse(target.exists())
