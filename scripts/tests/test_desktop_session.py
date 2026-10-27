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
        self.check_worker()

    def test_worker_already_group_leader(self):
        self.check_worker(preexec_fn=os.setpgrp)

    def test_worker_already_session_leader(self):
        self.check_worker(start_new_session=True)

    def test_foundation_process_launch_and_cancellation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);swift=root/'launch.swift';executable=root/'launch'
            swift.write_text('''import Foundation
let task=Process()
task.executableURL=URL(fileURLWithPath:CommandLine.arguments[1])
task.arguments=Array(CommandLine.arguments[2...4])
try task.run()
try String(task.processIdentifier).write(toFile:CommandLine.arguments[5],atomically:true,encoding:.utf8)
task.waitUntilExit()
exit(task.terminationStatus)
''')
            subprocess.run(['xcrun','swiftc',str(swift),'-o',str(executable)],check=True)
            self.check_worker(foundation=executable)

    def check_worker(self,foundation=None,**options):
        with tempfile.TemporaryDirectory() as temporary:
            path=Path(temporary);marker=path/'ready'
            script=path/'worker.sh'
            script.write_text('echo ready > "$1"\nsleep 30\n')
            arguments=[sys.executable,str(ROOT/'desktop/NxNativeEasy/build_session.py'),str(script),str(marker)]
            pidfile=path/'pid'
            if foundation:arguments=[str(foundation),*arguments,str(pidfile)]
            task=subprocess.Popen(arguments,**options)
            worker_pid=None
            try:
                deadline=time.monotonic()+5
                while (not marker.exists() or (foundation and not pidfile.exists())) and time.monotonic()<deadline:time.sleep(0.02)
                self.assertTrue(marker.exists())
                worker_pid=int(pidfile.read_text()) if foundation else task.pid
                self.assertEqual(os.getpgid(worker_pid),worker_pid)
                self.assertNotEqual(os.getpgrp(),worker_pid)
                os.killpg(worker_pid,signal.SIGTERM)
                self.assertEqual(task.wait(timeout=5),signal.SIGTERM if foundation else -signal.SIGTERM)
            finally:
                if task.poll() is None:
                    if worker_pid is not None:
                        try:os.killpg(worker_pid,signal.SIGKILL)
                        except ProcessLookupError:pass
                    task.kill();task.wait()
