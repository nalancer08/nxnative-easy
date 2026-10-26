#!/bin/bash
# Prepare dependencies and build from this checkout, including its local changes.
# Never reset, pull, sign, install or select an Apple developer account.
set -euo pipefail
nxi_repo=$(cd "$(dirname "$0")/.." && pwd -P)
if [ "${1:-}" = --help ] || [ "${1:-}" = -h ]; then
  cat <<'HELP'
Usage: bash scripts/prepare_ios.sh [--setup-only] [game-folder] [build options]
No folder: opens the macOS folder picker.
Installs missing tools, creates a Python environment beside the game, and builds
an unsigned lightweight IPA using THIS checkout, including local control edits.
Build options: --keys-folder FOLDER (your own prod.keys) --keys PATH --language es-419 --bundle-id ID --app-name NAME
               --package v327680 --gpu none --full-only --app-only --dry-run
Examples:
  bash scripts/prepare_ios.sh /Volumes/Games/MetroidDread
  bash scripts/prepare_ios.sh --setup-only /Volumes/Games/NextGame
Run scripts/build_ios.py --help for build details.
HELP
  exit 0
fi
nxi_setup=0
if [ "${1:-}" = --setup-only ]; then nxi_setup=1; shift; fi
[ "$(uname -s)" = Darwin ] || { echo 'macOS is required.' >&2; exit 1; }
if [ "$#" -gt 0 ] && [[ "$1" != --* ]]; then
  nxi_game=$1; shift
else
  nxi_game=$(/usr/bin/osascript -e 'POSIX path of (choose folder with prompt "Select the folder containing one game")')
fi
[ -d "$nxi_game" ] || { echo 'Game folder does not exist.' >&2; exit 1; }
nxi_game=$(cd "$nxi_game" && pwd -P)
case "$nxi_game/" in "$nxi_repo/"*) echo 'Keep game data outside the source checkout.' >&2; exit 1;; esac
nxi_developer=${DEVELOPER_DIR:-$(/usr/bin/xcode-select -p)}
if [ ! -d "$nxi_developer/Platforms/iPhoneOS.platform" ]; then nxi_developer=/Applications/Xcode.app/Contents/Developer; fi
[ -d "$nxi_developer/Platforms/iPhoneOS.platform" ] || { echo 'Install and open full Xcode first.' >&2; exit 1; }
export DEVELOPER_DIR="$nxi_developer"
/usr/bin/xcodebuild -version
nxi_sdk=$(/usr/bin/xcrun --sdk iphoneos --show-sdk-version)
[ "${nxi_sdk%%.*}" -ge 26 ] || { echo 'iOS SDK 26 or newer is required.' >&2; exit 1; }
nxi_brew=$(command -v brew || true)
if [ -z "$nxi_brew" ] && [ -x /opt/homebrew/bin/brew ]; then nxi_brew=/opt/homebrew/bin/brew; fi
if [ -z "$nxi_brew" ] && [ -x /usr/local/bin/brew ]; then nxi_brew=/usr/local/bin/brew; fi
[ -n "$nxi_brew" ] || { echo 'Install Homebrew from https://brew.sh first.' >&2; exit 1; }
nxi_prefix=$("$nxi_brew" --prefix)
export PATH="$nxi_prefix/bin:$nxi_prefix/sbin:/usr/local/share/dotnet:$PATH"
if ! /usr/bin/xcrun --sdk iphoneos metal --version; then
  /usr/bin/xcodebuild -downloadComponent MetalToolchain
  /usr/bin/xcrun --sdk iphoneos metal --version
fi
for nxi_formula in python@3.13 xcodegen zstd spirv-cross glslang; do
  if ! "$nxi_brew" list --versions "$nxi_formula" >/dev/null 2>&1; then "$nxi_brew" install "$nxi_formula"; fi
done
if ! command -v dotnet >/dev/null 2>&1 || ! dotnet --list-sdks | /usr/bin/grep -Eq '^10\.'; then
  if "$nxi_brew" list --cask --versions dotnet-sdk >/dev/null 2>&1; then "$nxi_brew" upgrade --cask dotnet-sdk
  else "$nxi_brew" install --cask dotnet-sdk; fi
fi
hash -r
dotnet --list-sdks | /usr/bin/grep -Eq '^10\.'
nxi_python_prefix=$("$nxi_brew" --prefix python@3.13)
nxi_venv="$nxi_game/nxnative-tools/venv"
if [ ! -e "$nxi_venv" ]; then "$nxi_python_prefix/bin/python3.13" -m venv "$nxi_venv"; fi
[ -x "$nxi_venv/bin/python" ] || { echo 'Existing Python environment is incomplete; preserved without changes.' >&2; exit 1; }
"$nxi_venv/bin/python" -m pip install lz4 capstone fonttools 'backports.zstd; python_version < "3.14"'
export PATH="$nxi_venv/bin:$PATH"
if [ "$nxi_setup" -eq 1 ]; then
  echo "Ready. Source checkout preserved: $nxi_repo"
  exit 0
fi
exec "$nxi_venv/bin/python" "$nxi_repo/scripts/build_ios.py" "$nxi_game" "$@"
