#!/bin/bash
set -euo pipefail
nxe_here=$(cd "$(dirname "$0")" && pwd -P)
/bin/bash "$nxe_here/install.sh"
