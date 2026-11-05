"""Stable engine numbering over integration history, including old source builds."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('engine_history', ROOT / 'scripts/sync_engine_history.py')
assert SPEC is not None and SPEC.loader is not None
engine = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(engine)


class EngineHistoryTests(unittest.TestCase):
    def test_numbers_advance_only_when_engine_changes(self):
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            def git(*args):
                return subprocess.check_output(['git', '-C', str(repo), *args], text=True).strip()
            git('init', '-b', 'main')
            git('config', 'user.name', 'Synthetic test')
            git('config', 'user.email', 'test@example.invalid')
            def commit(path, value):
                file = repo / path
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text(value)
                git('add', '.')
                git('commit', '-m', 'Synthetic change')
                return git('rev-parse', 'HEAD')
            commit('docs/upstream-sync.json', json.dumps({'integrated_head': 'a' * 40}))
            first = commit('dm/host/engine.c', 'first')
            policy = repo / 'desktop/engine-versioning.json'
            policy.parent.mkdir(parents=True, exist_ok=True)
            policy.write_text(json.dumps(dict(base_revision=first, base_version='1.0.0')))
            cosmetic = commit('desktop/theme.swift', 'cosmetic')
            before = engine.history(repo)
            self.assertEqual(before['number'], 1)
            self.assertEqual(before['version'], '1.0.0')
            self.assertEqual(before['sources'][cosmetic], before['sources'][first])
            second = commit('dm/host/engine.c', 'second')
            after = engine.history(repo)
            self.assertEqual(after['number'], 2)
            self.assertEqual(after['version'], '1.0.1')
            self.assertEqual(after['sources'][first], 1)
            self.assertEqual(after['sources'][cosmetic], 1)
            self.assertEqual(after['sources'][second], 2)
            commit('dm/host/tests/check.c', 'test only')
            commit('dm/host/README.md', 'documentation only')
            self.assertEqual(engine.history(repo)['number'], 2)
            git('checkout', '-b', 'runtime-branch')
            commit('dm/host/engine.c', 'third')
            branch = commit('dm/host/engine.c', 'fourth')
            git('checkout', 'main')
            git('merge', '--no-ff', 'runtime-branch', '-m', 'Integrate runtime work')
            integrated = engine.history(repo)
            self.assertEqual(integrated['number'], 3)
            self.assertEqual(integrated['version'], '1.0.2')
            self.assertNotIn(branch, integrated['sources'])
            self.assertEqual(integrated['sources'][first], 1)
            self.assertEqual(integrated['entries'][0]['number'], 3)
            next_engine = commit('dm/host/engine.c', 'new minor release')
            policy.write_text(json.dumps(dict(base_revision=first, base_version='1.0.0', overrides={next_engine:'1.1.0'})))
            commit('desktop/notes.txt', 'version policy')
            self.assertEqual(engine.history(repo)['version'], '1.1.0')
            commit('dm/host/engine.c', 'minor release patch')
            self.assertEqual(engine.history(repo)['version'], '1.1.1')
