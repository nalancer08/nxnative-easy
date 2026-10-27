"""Portable, authenticated save-snapshot API. It never reads local game folders or restores a running game."""
from contextlib import closing
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import secrets
import sqlite3
import stat
import time
import unicodedata
import zipfile

MAX_ARCHIVE=64*1024*1024
MAX_ACCOUNT=512*1024*1024
TITLE=re.compile(r'[0-9A-F]{16}')
SLOT=re.compile(r'[a-z0-9][a-z0-9-]{0,39}')

class APIError(Exception):
    def __init__(self,status,message):
        super().__init__(message);self.status=status


def save_manifest(payload):
    """Validate the portable nxsave v1 envelope before accepting immutable bytes."""
    if len(payload)>MAX_ARCHIVE:raise APIError(413,'Snapshot exceeds 64 MiB.')
    try:
        with zipfile.ZipFile(io.BytesIO(payload)) as archive:
            entries=archive.infolist();names=[entry.filename for entry in entries]
            if len(entries)>4097 or len(names)!=len(set(names)):raise ValueError('Duplicate or excessive ZIP entries.')
            manifest=archive.getinfo('manifest.json')
            if manifest.file_size>1024*1024:raise ValueError('Manifest is too large.')
            metadata=json.loads(archive.read(manifest))
            if type(metadata.get('schema')) is not int or metadata['schema']!=1 or not TITLE.fullmatch(str(metadata.get('title_id',''))):raise ValueError('Invalid schema or title ID.')
            if not re.fullmatch('[0-9a-fA-F]{64}',str(metadata.get('build_id',''))):raise ValueError('Missing exact game build ID.')
            version=metadata.get('game_version')
            if not isinstance(version,str) or not 1<=len(version)<=64:raise ValueError('Missing game version.')
            records=metadata.get('entries')
            if not isinstance(records,list) or not 1<=len(records)<=4096:raise ValueError('Missing save entries.')
            for entry in entries:
                mode=entry.external_attr>>16
                if entry.flag_bits&1 or stat.S_ISLNK(mode) or (stat.S_IFMT(mode) and not (stat.S_ISREG(mode) or stat.S_ISDIR(mode))):
                    raise ValueError('Links, encrypted entries and special files are not supported.')
            expected={'manifest.json'};expanded=manifest.file_size;physical={}
            for record in records:
                name=record['path'];path=PurePosixPath(name)
                if not isinstance(name,str) or name.endswith('/') or name!=str(path) or len(name.encode())>1024:
                    raise ValueError('Invalid snapshot path.')
                if path.is_absolute() or '..' in path.parts or '\\' in name or ':' in name or any(ord(c)<32 for c in name):raise ValueError('Unsafe snapshot path.')
                if path.parts[0] not in ('account','device') or len(path.parts)<2:raise ValueError('Only committed account/device save entries are allowed.')
                if path.name.lower() in ('prod.keys','title.keys') or path.suffix.lower() in ('.nsp','.xci','.nsz','.xcz','.ipa','.p12','.mobileprovision'):
                    raise ValueError('Game packages and credentials are not save snapshots.')
                if record.get('kind') not in ('file','directory'):raise ValueError('Invalid entry kind.')
                key=unicodedata.normalize('NFC',name).casefold()
                if key in physical:raise ValueError('Colliding physical paths; case aliases must use their distinct physical names.')
                physical[key]=record['kind']
                zip_name=name+'/' if record['kind']=='directory' else name
                if zip_name in expected:raise ValueError('Duplicate manifest entry.')
                expected.add(zip_name);entry=archive.getinfo(zip_name)
                mode=entry.external_attr>>16
                if entry.flag_bits&1 or stat.S_ISLNK(mode) or (stat.S_IFMT(mode) and not (stat.S_ISREG(mode) or stat.S_ISDIR(mode))):
                    raise ValueError('Encrypted entries, links and special files are not supported.')
                if record['kind']=='directory':
                    if not entry.is_dir() or entry.file_size:raise ValueError('Invalid directory entry.')
                else:
                    if type(record.get('size')) is not int or record['size']!=entry.file_size:raise ValueError('Snapshot size mismatch.')
                    expanded+=entry.file_size
                    if expanded>MAX_ARCHIVE:raise APIError(413,'Expanded snapshot exceeds 64 MiB.')
                    digest=hashlib.sha256()
                    with archive.open(entry) as stream:
                        for block in iter(lambda:stream.read(65536),b''):digest.update(block)
                    if digest.hexdigest()!=record.get('sha256'):raise ValueError('Snapshot hash mismatch.')
                if 'guest_name' in record:
                    guest=record['guest_name']
                    if not path.name.startswith('.dm-case-') or not isinstance(guest,str) or not guest or len(guest.encode())>768 or guest in ('.','..') or any(c in guest for c in '/\\\0'):
                        raise ValueError('Invalid case-alias metadata.')
            for path in physical:
                if any(physical.get(str(parent))=='file' for parent in PurePosixPath(path).parents):raise ValueError('A file cannot contain another save entry.')
            if set(names)!=expected:raise ValueError('ZIP entries do not match the manifest.')
            return metadata
    except APIError:raise
    except (ValueError,KeyError,TypeError,AttributeError,UnicodeError,zipfile.BadZipFile,RuntimeError) as error:
        raise APIError(400,'Invalid nxsave snapshot: '+str(error)) from error


class SaveStore:
    def __init__(self,path):
        self.path=Path(path);self.path.parent.mkdir(parents=True,exist_ok=True)
        with closing(self.connect()) as db:
            db.executescript('''
                PRAGMA journal_mode=WAL;
                CREATE TABLE IF NOT EXISTS revisions(id TEXT PRIMARY KEY, owner TEXT NOT NULL, title TEXT NOT NULL,
                  slot TEXT NOT NULL, created REAL NOT NULL, metadata TEXT NOT NULL, payload BLOB NOT NULL);
                CREATE TABLE IF NOT EXISTS heads(owner TEXT, title TEXT, slot TEXT, revision TEXT NOT NULL,
                  PRIMARY KEY(owner,title,slot));
                CREATE TABLE IF NOT EXISTS shares(id TEXT PRIMARY KEY, token_hash TEXT UNIQUE NOT NULL, owner TEXT NOT NULL,
                  revision TEXT NOT NULL, expires REAL NOT NULL, revoked INTEGER NOT NULL DEFAULT 0);
            ''')
        os.chmod(self.path,0o600)
    def connect(self):
        db=sqlite3.connect(self.path,isolation_level=None,timeout=10);db.row_factory=sqlite3.Row
        db.execute('PRAGMA synchronous=FULL');return db
    @staticmethod
    def identity(title,slot):
        if not TITLE.fullmatch(title) or not SLOT.fullmatch(slot):raise APIError(400,'Invalid title ID or slot.')
    def list(self,owner,title):
        self.identity(title,'default')
        with closing(self.connect()) as db:
            rows=db.execute('SELECT r.id,r.title,r.slot,r.created,r.metadata FROM heads h JOIN revisions r ON r.id=h.revision WHERE h.owner=? AND h.title=? ORDER BY r.slot',(owner,title)).fetchall()
        return [dict(revision=r['id'],slot=r['slot'],created=r['created'],game=json.loads(r['metadata'])) for r in rows]
    def get(self,owner,title,slot,revision=None):
        self.identity(title,slot)
        with closing(self.connect()) as db:
            if revision:row=db.execute('SELECT * FROM revisions WHERE owner=? AND title=? AND slot=? AND id=?',(owner,title,slot,revision)).fetchone()
            else:row=db.execute('SELECT r.* FROM heads h JOIN revisions r ON r.id=h.revision WHERE h.owner=? AND h.title=? AND h.slot=?',(owner,title,slot)).fetchone()
        if row is None:raise APIError(404,'Snapshot not found.')
        return row
    def history(self,owner,title,slot):
        self.identity(title,slot)
        with closing(self.connect()) as db:
            rows=db.execute('SELECT id,created,metadata FROM revisions WHERE owner=? AND title=? AND slot=? ORDER BY created DESC,id DESC LIMIT 100',(owner,title,slot)).fetchall()
        return [dict(revision=r['id'],created=r['created'],game=json.loads(r['metadata'])) for r in rows]
    def put(self,owner,title,slot,payload,expected):
        self.identity(title,slot)
        if expected is None:raise APIError(428,'If-Match is required; use If-None-Match: * for a new slot.')
        metadata=save_manifest(payload)
        if metadata['title_id']!=title:raise APIError(400,'Snapshot title does not match the requested game.')
        with closing(self.connect()) as db:
            db.execute('BEGIN IMMEDIATE')
            try:
                old=db.execute('SELECT revision FROM heads WHERE owner=? AND title=? AND slot=?',(owner,title,slot)).fetchone()
                current=old['revision'] if old else ''
                if current!=expected:raise APIError(412,'Cloud save changed. Keep both versions; download the current revision before choosing.')
                used=db.execute('SELECT COALESCE(SUM(length(payload)),0) FROM revisions WHERE owner=?',(owner,)).fetchone()[0]
                if used+len(payload)>MAX_ACCOUNT:raise APIError(413,'Account snapshot quota reached; existing versions were preserved.')
                revision=secrets.token_hex(16)
                summary={k:metadata[k] for k in ('title_id','build_id','game_version')}
                db.execute('INSERT INTO revisions VALUES(?,?,?,?,?,?,?)',(revision,owner,title,slot,time.time(),json.dumps(summary),payload))
                db.execute('INSERT INTO heads VALUES(?,?,?,?) ON CONFLICT(owner,title,slot) DO UPDATE SET revision=excluded.revision',(owner,title,slot,revision))
                db.commit();return revision
            except BaseException:db.rollback();raise
    def share(self,owner,title,slot,revision,ttl):
        row=self.get(owner,title,slot,revision)
        if type(ttl) is not int or not 60<=ttl<=7*24*3600:raise APIError(400,'Share expiry must be between one minute and seven days.')
        token=secrets.token_urlsafe(32);identifier=secrets.token_hex(16)
        with closing(self.connect()) as db:
            db.execute('INSERT INTO shares VALUES(?,?,?,?,?,0)',(identifier,hashlib.sha256(token.encode()).hexdigest(),owner,row['id'],time.time()+ttl))
        return dict(id=identifier,token=token,expires_in_seconds=ttl)
    def revoke(self,owner,identifier):
        with closing(self.connect()) as db:
            result=db.execute('UPDATE shares SET revoked=1 WHERE owner=? AND id=?',(owner,identifier))
            if not result.rowcount:raise APIError(404,'Share not found.')
    def copy_share(self,recipient,token,title,slot,expected):
        with closing(self.connect()) as db:
            row=db.execute('SELECT r.* FROM shares s JOIN revisions r ON r.id=s.revision WHERE s.token_hash=? AND s.revoked=0 AND s.expires>?',
                           (hashlib.sha256(token.encode()).hexdigest(),time.time())).fetchone()
        if row is None:raise APIError(404,'Share is unavailable or expired.')
        if row['title']!=title:raise APIError(400,'Share belongs to another game.')
        # Shares reference an immutable revision, never the sender's changing head; copy is into the recipient's own slot.
        return self.put(recipient,title,slot,row['payload'],expected)


def oidc_verifier(issuer,audience,jwks_url):
    from urllib.parse import urlparse
    import jwt
    if not issuer or not audience or not jwks_url:raise ValueError('Configure OIDC_ISSUER, OIDC_AUDIENCE and OIDC_JWKS_URL first.')
    issuer_url=urlparse(issuer);key_url=urlparse(jwks_url)
    if issuer_url.scheme!='https' or key_url.scheme!='https' or issuer_url.hostname!=key_url.hostname:
        raise ValueError('OIDC issuer and JWKS must use HTTPS on the same trusted host.')
    client=jwt.PyJWKClient(jwks_url,cache_keys=True,timeout=10)
    def verify(token):
        try:
            if jwt.get_unverified_header(token).get('alg') not in ('RS256','ES256'):raise jwt.InvalidAlgorithmError('Unsupported signing algorithm.')
            key=client.get_signing_key_from_jwt(token)
            claims=jwt.decode(token,key.key,algorithms=['RS256','ES256'],issuer=issuer,audience=audience,leeway=30,
                              options={'require':['exp','iat','iss','sub','aud']})
            if not isinstance(claims['sub'],str) or not claims['sub']:raise ValueError('Missing subject.')
            return hashlib.sha256((issuer+'\0'+claims['sub']).encode()).hexdigest()
        except jwt.PyJWKClientConnectionError as error:raise APIError(503,'Identity provider unavailable; retry later.') from error
        except (jwt.PyJWTError,ValueError) as error:raise APIError(401,'Sign in again.') from error
    return verify


class SaveAPI:
    def __init__(self,store,verify_token):self.store=store;self.verify_token=verify_token
    def __call__(self,environ,start_response):
        from http import HTTPStatus
        from urllib.parse import parse_qs
        headers=[]
        try:
            method=environ['REQUEST_METHOD'];path=environ.get('PATH_INFO','')
            if method=='GET' and path=='/health':data=b'{"status":"ok"}';status=200
            else:
                auth=environ.get('HTTP_AUTHORIZATION','')
                if not auth.startswith('Bearer ') or len(auth)>16384:raise APIError(401,'Sign in is required.')
                owner=self.verify_token(auth[7:])
                if not isinstance(owner,str) or not owner:raise APIError(401,'Invalid identity.')
                length=environ.get('CONTENT_LENGTH','')
                try:length=int(length or 0)
                except ValueError as error:raise APIError(400,'Invalid Content-Length.') from error
                if length<0 or length>MAX_ARCHIVE:raise APIError(413,'Request exceeds snapshot limit.')
                if method!='PUT' and length>16384:raise APIError(413,'JSON request is too large.')
                body=environ['wsgi.input'].read(length)
                if len(body)!=length:raise APIError(400,'Incomplete request.')
                if method in ('PUT','POST') and (environ.get('HTTP_IF_MATCH') and environ.get('HTTP_IF_NONE_MATCH')):raise APIError(400,'Choose one write precondition.')
                expected=environ.get('HTTP_IF_MATCH')
                if expected is not None:expected=expected.strip('"')
                elif environ.get('HTTP_IF_NONE_MATCH')=='*':expected=''
                game=re.fullmatch(r'/v1/games/([0-9A-F]{16})/saves(?:/([a-z0-9-]+)(/snapshot)?)?',path)
                history=re.fullmatch(r'/v1/games/([0-9A-F]{16})/saves/([a-z0-9-]+)/revisions',path)
                share_copy=re.fullmatch(r'/v1/shares/([A-Za-z0-9_-]{20,100})/copy',path)
                revoke=re.fullmatch(r'/v1/shares/([a-f0-9]{32})',path)
                result={};status=200
                if method=='GET' and path=='/v1/me':result={'account':owner}
                elif method=='GET' and history:result={'revisions':self.store.history(owner,history[1],history[2])}
                elif game and method=='GET' and game[2] is None:result={'saves':self.store.list(owner,game[1])}
                elif game and game[3] and method=='GET':
                    revision=parse_qs(environ.get('QUERY_STRING','')).get('revision',[None])[0]
                    row=self.store.get(owner,game[1],game[2],revision)
                    headers=[('Content-Type','application/vnd.nxnative.save+zip'),('ETag','"'+row['id']+'"')]
                    data=row['payload'];start_response('200 OK',headers+[('Content-Length',str(len(data))),('Cache-Control','no-store')]);return [data]
                elif game and game[3] and method=='PUT':
                    revision=self.store.put(owner,game[1],game[2],body,expected);status=201;result={'revision':revision};headers=[('ETag','"'+revision+'"')]
                elif method=='POST' and path=='/v1/shares':
                    value=json.loads(body);result=self.store.share(owner,value['title_id'],value['slot'],value['revision'],value.get('expires_in_seconds',3600));status=201
                elif method=='POST' and share_copy:
                    value=json.loads(body);revision=self.store.copy_share(owner,share_copy[1],value['title_id'],value['slot'],expected);result={'revision':revision};status=201
                elif method=='DELETE' and revoke:self.store.revoke(owner,revoke[1]);result={'revoked':True}
                else:raise APIError(404,'Endpoint not found.')
                data=json.dumps(result).encode()
        except APIError as error:status=error.status;data=json.dumps({'error':str(error)}).encode()
        except (ValueError,KeyError,TypeError,AttributeError):status=400;data=json.dumps({'error':'Invalid request.'}).encode()
        except Exception:status=500;data=b'{"error":"Server error; existing snapshots were preserved."}'
        start_response(f'{status} {HTTPStatus(status).phrase}',headers+[('Content-Type','application/json'),('Content-Length',str(len(data))),('Cache-Control','no-store')])
        return [data]
