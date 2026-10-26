"""The GUI must cancel its worker group without affecting the caller."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT=Path(__file__).resolve().parents[2]

@unittest.skipUnless(sys.platform=='darwin','macOS desktop worker')
class DesktopSession(unittest.TestCase):
    def test_worker_has_separate_group_and_cancels(self):
        with tempfile.TemporaryDirectory() as temporary:
            path=Path(temporary);marker=path/'ready'
            script=path/'worker.sh'
            script.write_text('echo ready > "$1"\nsleep 30\n')
            task=subprocess.Popen([sys.executable,str(ROOT/'desktop/NxNativeEasy/build_session.py'),str(script),str(marker)])
            try:
                deadline=time.monotonic()+5
                while not marker.exists() and time.monotonic()<deadline:time.sleep(0.02)
                self.assertTrue(marker.exists())
                self.assertEqual(os.getpgid(task.pid),task.pid)
                self.assertNotEqual(os.getpgrp(),task.pid)
                os.killpg(task.pid,signal.SIGTERM)
                self.assertEqual(task.wait(timeout=5),-signal.SIGTERM)
            finally:
                if task.poll() is None:
                    os.killpg(task.pid,signal.SIGKILL);task.wait()
