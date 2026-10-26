#!/bin/bash
# Double-click in Finder to prepare dependencies and build an unsigned lightweight IPA.
nxi_scripts=$(cd "$(dirname "$0")" && pwd -P)
bash "$nxi_scripts/prepare_ios.sh" "$@"
nxi_status=$?
if [ "$nxi_status" -ne 0 ]; then echo "Stopped with error $nxi_status. Existing game data and source changes were preserved."; fi
read -r -p 'Press Enter to close this window. '
exit "$nxi_status"
