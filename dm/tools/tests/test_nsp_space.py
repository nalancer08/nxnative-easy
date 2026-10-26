"""NSP extraction space estimate: distinct archives count even when they have the same size; the shared base counts once.
No game files, keys or Xcode needed (temporary synthetic files only)."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('build_ipa_from_nsp', REPO / 'scripts/build_ipa_from_nsp.py')
nsp = importlib.util.module_from_spec(spec); spec.loader.exec_module(nsp)


class Space(unittest.TestCase):
    def test_equal_sized_archives(self):
        with tempfile.TemporaryDirectory() as tmp:
            base, update = Path(tmp) / 'base.nsp', Path(tmp) / 'update.nsp'
            base.write_bytes(b'base'); update.write_bytes(b'updt')
            self.assertEqual(nsp.picked_nsp_bytes({'v1': (base, update)}), 8)

    def test_shared_base(self):
        with tempfile.TemporaryDirectory() as tmp:
            base, first, second = [Path(tmp) / name for name in ('base.nsp', 'first.nsp', 'second.nsp')]
            base.write_bytes(b'base'); first.write_bytes(b'first'); second.write_bytes(b'second')
            self.assertEqual(nsp.picked_nsp_bytes({'v0': (base, None), 'v1': (base, first), 'v2': (base, second)}), 15)

    def test_base_without_update(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp) / 'base.nsp'; base.write_bytes(b'base')
            self.assertEqual(nsp.picked_nsp_bytes({'v0': (base, None)}), 4)


if __name__ == '__main__':
    unittest.main()
