"""Real worker streaming and retained logs, plus bounded tool-file tailing."""
import importlib.util
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import time
import unittest
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('build_session',ROOT/'desktop/NxNativeEasy/build_session.py')
assert spec is not None and spec.loader is not None
worker=importlib.util.module_from_spec(spec);spec.loader.exec_module(worker)

class BuildLogs(unittest.TestCase):
    def test_console_stream_and_private_retained_log(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);script=root/'worker.sh';log=root/'logs/session.log'
            script.write_text("printf 'first\\n'\nsleep 0.15\nprintf 'last ✓'\nexit 7\n")
            env=dict(os.environ,NXE_BUILD_LOG=str(log))
            with subprocess.Popen([sys.executable,str(ROOT/'desktop/NxNativeEasy/build_session.py'),str(script)],env=env,stdout=subprocess.PIPE) as task:
                assert task.stdout is not None
                self.assertEqual(task.stdout.readline(),b'first\n')
                self.assertEqual(log.read_text(),'first\n')
                remaining=task.stdout.read().decode();self.assertEqual(task.wait(),7)
            self.assertEqual(remaining,'last ✓');self.assertEqual(log.read_text(),'first\nlast ✓')
            self.assertEqual(stat.S_IMODE(log.stat().st_mode),0o600)

    def test_tool_logs_new_bytes_bounded_rotation_and_symlink(self):
        with tempfile.TemporaryDirectory() as temporary:
            game=Path(temporary);logs=game/'010093801237C000_build/logs';logs.mkdir(parents=True)
            old=logs/'old.log';old.write_text('old');os.utime(old,(1,1))
            outside=game/'prod.keys';outside.write_text('not a log');(logs/'escape.log').symlink_to(outside)
            tail=worker.ToolLogs(game,time.time()-1)
            path=logs/'active.log';path.write_text('compile 1\n')
            events=tail.read();self.assertEqual(len(events),1);self.assertEqual(events[0]['msg'],'compile 1\n')
            self.assertEqual(tail.read(),[])
            with path.open('a') as stream:stream.write('compile 2\n')
            self.assertEqual(tail.read()[0]['msg'],'compile 2\n')
            path.write_text('new\n');self.assertEqual(tail.read()[0]['msg'],'new\n')
            path.write_text('flood'*100000);event=tail.read()[0]
            self.assertLessEqual(len(event['msg']),8192);self.assertGreater(event['skipped'],0)
            self.assertEqual(outside.read_text(),'not a log')
