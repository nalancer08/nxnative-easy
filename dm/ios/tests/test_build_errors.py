"""Keep the actual linker cause visible in the bounded desktop build log."""
from pathlib import Path
import importlib.util
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1] / 'tools/build_errors.py'
spec = importlib.util.spec_from_file_location('build_errors', SOURCE)
assert spec and spec.loader
errors = importlib.util.module_from_spec(spec)
spec.loader.exec_module(errors)


class BuildErrors(unittest.TestCase):
    def test_unresolved_symbol_and_compiler_error(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'build.log'
            path.write_text('command output\nUndefined symbols for architecture arm64:\n'
                            '  "_AVAudioSessionCategoryPlayback", referenced from:\n'
                            '      _front_ios_audio_session in front_ios.o\n'
                            'ld: symbol(s) not found for architecture arm64\n'
                            'clang: error: linker command failed with exit code 1\n')
            output = errors.diagnostics(path)
            self.assertIn('AVAudioSessionCategoryPlayback', output)
            self.assertIn('front_ios_audio_session', output)
            self.assertIn('linker command failed', output)
            self.assertNotIn('command output', output)
            path.write_text('/a path/source.m:10:2: error: missing header\n')
            self.assertIn('missing header', errors.diagnostics(path))

    def test_large_logs_and_diagnostics_are_bounded(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'build.log'
            path.write_text('old ignored output\n' * 160000 + 'Undefined symbols for architecture arm64:\n' + ('x' * 5000 + '\n') * 200)
            output = errors.diagnostics(path)
            self.assertLessEqual(len(output.splitlines()), 65)
            self.assertTrue(all(len(line) <= 1500 for line in output.splitlines()))
