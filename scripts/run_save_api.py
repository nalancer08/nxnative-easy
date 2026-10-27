#!/usr/bin/env python3
"""Run the portable save API on localhost with a configured external OIDC login provider."""
import argparse
import os
from pathlib import Path
import sys
from wsgiref.simple_server import WSGIRequestHandler, WSGIServer, make_server

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'dm/cloud'))
from save_api import SaveAPI, SaveStore, oidc_verifier

class QuietHandler(WSGIRequestHandler):
    # Do not log bearer tokens, share URLs, payloads or user identity.
    def log_message(self,format,*args):pass

class TimeoutServer(WSGIServer):
    def get_request(self):
        connection,address=super().get_request();connection.settimeout(15);return connection,address


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data',type=Path,required=True,help='private persistent directory outside this checkout')
    parser.add_argument('--port',type=int,default=8787)
    args=parser.parse_args();data=args.data.expanduser().resolve()
    if data==ROOT or ROOT in data.parents:parser.error('Keep private saves outside the repository.')
    verify=oidc_verifier(os.environ.get('OIDC_ISSUER'),os.environ.get('OIDC_AUDIENCE'),os.environ.get('OIDC_JWKS_URL'))
    data.mkdir(parents=True,exist_ok=True);os.chmod(data,0o700)
    app=SaveAPI(SaveStore(data/'saves.sqlite3'),verify)
    with make_server('127.0.0.1',args.port,app,server_class=TimeoutServer,handler_class=QuietHandler) as server:
        print(f'Save API listening on http://127.0.0.1:{args.port}; native cloud login/import is not connected yet.',flush=True)
        server.serve_forever()

if __name__=='__main__':main()
