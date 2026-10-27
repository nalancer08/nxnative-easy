"""Compiled helper diagnostics must not echo credentials; no Apple/device operations."""
import json
import os
from pathlib import Path
import subprocess
import unittest

@unittest.skipUnless(os.environ.get('NXE_SIDELOAD_TEST_HELPER'),'set the locally compiled helper for protocol checks')
class SideloadProtocol(unittest.TestCase):
    def test_arm64_and_secret_redaction(self):
        helper=Path(os.environ['NXE_SIDELOAD_TEST_HELPER'])
        request=json.dumps({'op':'unknown-operation','password':'SYNTHETIC-SECRET-MUST-NOT-APPEAR','session':'SYNTHETIC-PRIVATE-TOKEN'})+'\n'+json.dumps({'op':'quit'})+'\n'
        result=subprocess.run([str(helper)],input=request,text=True,capture_output=True,check=True,timeout=10)
        self.assertNotIn('SYNTHETIC-SECRET',result.stdout+result.stderr)
        self.assertNotIn('SYNTHETIC-PRIVATE',result.stdout+result.stderr)
        events=[json.loads(line) for line in result.stdout.splitlines()]
        self.assertEqual(events[0]['architecture'],'aarch64');self.assertEqual(events[0]['protocol'],1)
        self.assertEqual(events[1]['event'],'error')

    def test_empty_game_scope_never_queries_a_device(self):
        helper=Path(os.environ['NXE_SIDELOAD_TEST_HELPER'])
        request=json.dumps({'op':'installed_apps','udid':'NOT-A-REAL-DEVICE','original_ids':[],'known_ids':[]})+'\n'+json.dumps({'op':'quit'})+'\n'
        result=subprocess.run([str(helper)],input=request,text=True,capture_output=True,check=True,timeout=10)
        events=[json.loads(line) for line in result.stdout.splitlines()]
        self.assertIn('scoped-games-v1',events[0]['capabilities'])
        self.assertIn('registration-consent-v1',events[0]['capabilities'])
        self.assertEqual(events[1],{'event':'installed_apps','items':[]})
