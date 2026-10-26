#!/usr/bin/env python3
"""Give a GUI build its own process group so cancellation includes child tools."""
import os
import sys

if __name__ == '__main__':
    os.setsid()
    os.execv('/bin/bash', ['bash', *sys.argv[1:]])
