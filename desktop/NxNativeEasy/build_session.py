#!/usr/bin/env python3
"""Launch a cancellable GUI worker and retain its live console/tool diagnostics."""
import codecs
import json
import os
from pathlib import Path
import selectors
from stat import S_ISREG
import subprocess
import sys
import time


class ToolLogs:
    """Tail only this run's changed build logs, with bounded reads and no symlink escape."""
    def __init__(self,game,started):
        self.game=Path(game).resolve();self.started=started;self.positions={}
    def read(self):
        result=[]
        for directory in self.game.glob('*_build/logs'):
            if not directory.resolve().is_relative_to(self.game):continue
            for path in sorted(directory.glob('*.log')):
                try:
                    if not path.resolve().is_relative_to(directory.resolve()) or path.is_symlink():continue
                    stat=path.stat()
                    if not S_ISREG(stat.st_mode) or stat.st_mtime<self.started:continue
                    old_inode,offset=self.positions.get(path,(None,0))
                    if old_inode!=stat.st_ino or stat.st_size<offset:offset=0
                    if stat.st_size==offset:continue
                    # Skip a flood's older bytes in the UI; the original tool file stays complete.
                    skipped=max(0,stat.st_size-offset-8192);offset+=skipped
                    with path.open('rb') as stream:stream.seek(offset);data=stream.read(8192)
                    self.positions[path]=(stat.st_ino,offset+len(data))
                    result.append(dict(ev='tool_log',source=str(path.relative_to(self.game)),msg=data.decode('utf-8',errors='replace'),skipped=skipped))
                    if len(result)>=4:return result
                except OSError:continue
        return result


def run(arguments):
    # Foundation Process already starts a separate process group on macOS.
    if os.getpgrp()!=os.getpid():os.setsid()
    log_path=os.environ.get('NXE_BUILD_LOG');game=os.environ.get('NXE_GAME_DIR')
    log=None
    if log_path:
        path=Path(log_path);path.parent.mkdir(parents=True,exist_ok=True)
        log=os.fdopen(os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600),'w',encoding='utf-8')
    def emit(text):
        sys.stdout.write(text);sys.stdout.flush()
        if log:log.write(text);log.flush()
    started=time.time();watch=ToolLogs(game,started) if game else None
    command=([sys.executable] if arguments[0].endswith('.py') else ['/bin/bash'])+arguments
    decoder=codecs.getincrementaldecoder('utf-8')(errors='replace');pending=''
    try:
        with subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT) as child:
            assert child.stdout is not None
            with selectors.DefaultSelector() as selector:
                selector.register(child.stdout,selectors.EVENT_READ)
                while selector.get_map():
                    for key,_ in selector.select(timeout=0.5):
                        block=os.read(key.fd,65536)
                        if block:
                            pending+=decoder.decode(block)
                            while '\n' in pending:
                                line,pending=pending.split('\n',1);emit(line+'\n')
                            if len(pending)>65536:emit(pending+'\n');pending=''
                        else:selector.unregister(key.fileobj)
                    if watch:
                        for event in watch.read():emit('\n'+json.dumps(event)+'\n')
                emit(pending+decoder.decode(b'',final=True))
                return child.wait()
    finally:
        if log:log.close()


if __name__=='__main__':sys.exit(run(sys.argv[1:]))
