#!/bin/bash
set -euo pipefail
nxe_repo=$(cd "$(dirname "$0")/.." && pwd -P)
nxe_output="$(dirname "$nxe_repo")/nxnative-easy/nxnative.app"
/usr/bin/python3 "$nxe_repo/scripts/build_desktop_app.py" --output "$nxe_output" --open
