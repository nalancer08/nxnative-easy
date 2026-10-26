#!/bin/bash
# Local, account-free desktop setup. Never modifies game data or resets a checkout.
set -euo pipefail
nxe_check=0
case "${1:-}" in --check) nxe_check=1;; '') ;; *) echo 'Usage: bash install.sh [--check]' >&2; exit 2;; esac
[ "$(uname -s)" = Darwin ] || { echo 'This app requires macOS.' >&2; exit 1; }
[ "$(uname -m)" = arm64 ] || { echo 'An Apple silicon Mac (M1 or newer) is required.' >&2; exit 1; }
nxe_os=$(/usr/bin/sw_vers -productVersion)
[ "${nxe_os%%.*}" -ge 26 ] || { echo 'Update this Mac to macOS 26 or newer first.' >&2; exit 1; }
echo "[1/4] Checking your Mac and Xcode / Revisando tu Mac y Xcode…"
nxe_developer=${DEVELOPER_DIR:-$(/usr/bin/xcode-select -p 2>/dev/null || true)}
if [ ! -d "$nxe_developer/Platforms/MacOSX.platform" ]; then nxe_developer=/Applications/Xcode.app/Contents/Developer; fi
if [ ! -d "$nxe_developer/Platforms/MacOSX.platform" ]; then
  echo 'First install full Xcode from the Mac App Store and open it once.'
  echo 'Primero instala Xcode completo desde App Store y ábrelo una vez.'
  echo 'https://apps.apple.com/app/xcode/id497799835'
  echo 'Then run this same command again / Después repite este mismo comando.'
  exit 1
fi
export DEVELOPER_DIR="$nxe_developer"
/usr/bin/xcodebuild -version >/dev/null || { echo 'Open Xcode and finish its first-time setup, then retry.' >&2; exit 1; }
nxe_sdk=$(/usr/bin/xcrun --sdk macosx --show-sdk-version)
[ "${nxe_sdk%%.*}" -ge 26 ] || { echo 'Install Xcode 26 or newer, open it once and retry.' >&2; exit 1; }
nxe_brew=$(command -v brew || true)
if [ -z "$nxe_brew" ] && [ -x /opt/homebrew/bin/brew ]; then nxe_brew=/opt/homebrew/bin/brew; fi
if [ "$nxe_check" -eq 1 ]; then
  echo 'Apple silicon, macOS and Xcode: ready.'
  if [ -n "$nxe_brew" ]; then echo 'Homebrew: ready.'; else echo 'Homebrew: will be installed by setup.'; fi
  exit 0
fi
echo "[2/4] Preparing Homebrew and source / Preparando Homebrew y código…"
if [ -z "$nxe_brew" ]; then
  echo 'Installing Homebrew / Instalando Homebrew. It may request your Mac password.'
  /bin/bash -c "$(/usr/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  nxe_brew=/opt/homebrew/bin/brew
fi
[ -x "$nxe_brew" ] || { echo 'Homebrew installation did not complete; retry setup.' >&2; exit 1; }
export PATH="$("$nxe_brew" --prefix)/bin:$PATH"
nxe_base=${NXNATIVE_INSTALL_ROOT:-"$HOME/Library/Application Support/nxnative Easy"}
nxe_source=${NXNATIVE_SOURCE_DIR:-"$nxe_base/Checkout"}
nxe_tools=${NXNATIVE_TOOLS_DIR:-"$nxe_base/Tools"}
nxe_app=${NXNATIVE_APP_PATH:-"$HOME/Applications/nxnative Easy.app"}
mkdir -p "$nxe_base" "$nxe_tools" "$(dirname "$nxe_app")"
if [ -n "${NXNATIVE_SOURCE_DIR:-}" ]; then
  [ -f "$nxe_source/scripts/build_desktop_app.py" ] || { echo 'Invalid source checkout.' >&2; exit 1; }
elif [ ! -e "$nxe_source" ]; then
  /usr/bin/git clone --depth 1 https://github.com/nalancer08/nxnative-easy.git "$nxe_source"
elif [ -d "$nxe_source/.git" ]; then
  nxe_remote=$(/usr/bin/git -C "$nxe_source" remote get-url origin)
  [ "$nxe_remote" = https://github.com/nalancer08/nxnative-easy.git ] || { echo 'Unexpected checkout origin; preserved without changes.' >&2; exit 1; }
  if [ -z "$(/usr/bin/git -C "$nxe_source" status --porcelain)" ]; then
    /usr/bin/git -C "$nxe_source" pull --ff-only
  else
    echo 'Local edits preserved: building your existing checkout without updating it.'
  fi
else
  echo 'The setup folder already contains other files; preserved without changes.' >&2; exit 1
fi
echo '[3/4] Preparing tools / Preparando herramientas…'
/bin/bash "$nxe_source/scripts/prepare_ios.sh" --target mac --setup-only "$nxe_tools"
echo '[4/4] Building and verifying your Mac app / Compilando y verificando tu app…'
"$nxe_tools/nxnative-tools/venv/bin/python" "$nxe_source/scripts/build_desktop_app.py" --output "$nxe_app"
echo "Ready / Lista: $nxe_app"
if [ "${NXNATIVE_NO_OPEN:-0}" != 1 ]; then /usr/bin/open "$nxe_app"; fi
