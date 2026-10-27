#!/usr/bin/env python3
"""Give a GUI build its own process group so cancellation includes child tools."""
import os
import sys

if __name__ == '__main__':
    # Foundation Process already starts a separate process group on macOS.
    # A group leader cannot call setsid(); its existing group is safe to cancel.
    if os.getpgrp() != os.getpid():
        os.setsid()
    os.execv('/bin/bash', ['bash', *sys.argv[1:]])
