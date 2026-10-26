## Interface language

The desktop app defaults to English. Its English/Español selector updates labels,
status messages and app-owned folder-picker prompts immediately, and persists the
choice in local UserDefaults (`interfaceLanguage`). Invalid saved values fall back
to English. Game language, the in-game touch editor and raw build/tool/OS diagnostics
are independent and are not translated by this selector. Gameplay compatibility is
reported by upstream game notes, not detected from a build or device by this app.

# Desktop interface

For daily use, open `nxnative.app`, choose a game folder and press **Preparar para iPhone**.
The native macOS interface uses generic SF Symbols instead of game artwork and shows progress and provides buttons for the lightweight IPA,
RomFS folder and Sideloadly. First-time setup still needs full Xcode, Homebrew and the
user's game/key files. It never signs, installs or enters an Apple account.

To create it on another Mac, double-click `scripts/Abrir-interfaz.command` from the
checkout. Build outputs stay beside the repository, under `nxnative-easy/`; the local
app points back to this checkout, so recreate it if the checkout is moved. The existing
CLI remains available below. Cancellation signals the entire build process group.

# Personal iOS builds

This branch retains nxnative's MIT license and attribution. It starts from
upstream `ecbeae164c0b419d1ba1031248fe1402050a3eb0`, includes the shared iOS touch
editor and the tested #277 extraction-space fix, and keeps the working Dread shader
chain. Upstream changes are reviewed in [the PR review](personal-pr-review.md).

## One command, including lightweight export

Double-click `scripts/Build-iPhone.command` in Finder, choose the folder containing
one game's base NSP/XCI and updates, and select the external folder containing your own `prod.keys` when asked.
Alternatively, from this checkout:

```sh
bash scripts/prepare_ios.sh "/Volumes/Games/MyGame"
```

Full Xcode and Homebrew must be installed first. The script checks iOS SDK 26+,
installs missing command-line dependencies, and keeps its Python environment next
to the game. It builds using THIS checkout, including the editor and any local
changes. It never clones an older revision over it, resets it, or pulls upstream.
For subsequent games, run the same command with a different external game folder.
It supports the upstream builder's known games; unsupported titles may require
bring-up even when a provisional IPA can be generated.

The default result is an unsigned full IPA plus a separate output folder with a
lightweight unsigned IPA, `romfs/`, and installation instructions. Each run uses
new names; previous IPAs, game packages, extraction and shader caches are retained.
Lightweight ZIP validation rejects traversal, duplicate/colliding paths, symlinks,
keys and unsupported compression. All exported data are streamed with CRC checks.
Large uncompressed app resources may still exceed the non-ZIP64 format limit;
the script stops rather than silently emit a Sideloadly-incompatible archive.

Per-game `nxnative-ios.json` records the source revision, app identity, language,
version and outputs; it contains no key values. Later runs retain its bundle ID.
The default language is `es-419`; the upstream builder handles supported-language
selection. The default pipeline archive target is `none`, as in the working Dread
build; choose a known compatible target explicitly with `--gpu` when desired.
Game versions are selected by upstream (newest present unless `--package` is set).
An update may change RomFS, so only reuse phone data when that data are identical.

## Developer CLI: rebuild the app using existing caches

The desktop interface always uses the normal pipeline, which validates and reuses
unchanged stages automatically. There is no cache-mode toggle for users to choose.
The app-only option below remains a developer CLI tool, outside the desktop flow.

For editor/app-only changes on an already prepared game:

```sh
bash scripts/prepare_ios.sh "/Volumes/Games/MyGame" --app-only
```

This does not need keys or re-extraction. It requires exactly one existing
`<title>_build` folder in the game folder, valid rewritten modules, extracted
RomFS and iOS shaders in the builder's standard locations. It selects the newest
cached `patched_v*` unless `--package` is supplied. On the first app-only run,
identity is read from the newest root-level unsigned IPA, then persisted. Keep
only the intended app's IPAs in that game's folder. Shader stamp verification in
`build_ipa.sh` remains enabled; stale caches fail explicitly rather than being used.
Changes to a profile/compiler/shader chain require a normal full pipeline run.
App-only and normal runs both re-export RomFS into a new output folder; they do
not delete or synchronize the existing phone's Documents.

## Options and diagnostics

```sh
bash scripts/prepare_ios.sh --setup-only "/Volumes/Games/MyGame"
python3 scripts/build_ios.py "/Volumes/Games/MyGame" --dry-run
python3 scripts/split_ipa.py "/Volumes/Games/MyGame/full-unsigned.ipa"
python3 scripts/review_upstream.py --output /Volumes/Games/new-pr-review
```

The direct Python build invocation needs the prepared venv. For example use
`<game>/nxnative-tools/venv/bin/python` instead of `python3`. Dry-run reads the
folder/configuration and source revision without opening keys or running a build;
the setup shell still checks/installs dependencies before invoking Python.
`--full-only` omits RomFS export. `--keys-folder` (or an explicit `--keys` file path), `--bundle-id`, `--app-name`, `--language`,
`--package` and `--gpu` provide explicit overrides. The wrapper rejects simultaneous builds from this checkout because generated files
and caches are shared. Avoid launching the original upstream builder alongside it.

## Install and preserve saves

The scripts do not sign or install, use Apple accounts, or choose developer teams.
The placeholder `0000000000` is only for unsigned packaging. Sign with Sideloadly
using your personal account. Updating the installed app requires the same personal
Apple account and the same effective bundle ID Sideloadly previously used. Keep
any Sideloadly custom bundle-ID settings. The source IPA identifier alone cannot
prove the identifier installed on the phone. Do not uninstall: this deletes saves
and `Documents/romfs`. First installation needs the exported `romfs` folder copied
whole to app Documents through Finder. Later app-only updates can reuse identical
RomFS already there. Updates to game data require the matching new export.

## Touch editor

Tap **Edit controls** above the game. Select a control from the menu or touch near
its center; drag outside the tools to move it. **Show / hide tools** exposes areas
behind the panel. Adjust **Size** (50–200%) and **Opacity** (0–100%). At 0% its hit
area remains active; editing keeps an invisible control findable. **Save** commits,
**Cancel** reloads saved preferences, **Reset control** and **Reset all** restore
original geometry and need **Save** to confirm. Each app stores independent 2D
and 3D layouts. The game keeps running during editing. Controller connection changes
cancel unsaved edits. Actual iPhone multitouch and controller behavior still need
user validation after signing/installing.

## Verify changes before committing

```sh
python3 -m unittest discover -s scripts/tests
python3 -m unittest dm.tools.tests.test_nsp_space
python3 -m unittest discover -s dm/ios/tests
GAME=010093801237C000 python3 dm/ios/tools/compile_check.py
```

Keep game packages, keys, saves, IPAs, signing material and extracted resources
outside this source repository. `.gitignore` guards common output types; it is
not a substitute for reviewing staged files. Original downloaded scripts were
preserved on the Mac. These maintained scripts generalize that preparation and
splitting workflow without the Metroid-only profile/bundle assumptions.

## Accounts and keys

The desktop build runs swiftc and explicitly ad-hoc signs with `codesign --sign -`.
No Apple identity, certificate or development team is selected. The iPhone package
continues to use CODE_SIGNING_ALLOWED=NO; Sideloadly signing is a separate user step.
The GUI remembers only a user-selected keys-folder path in local UserDefaults.
It passes that explicit folder to the builder; keys are not copied, bundled,
downloaded or stored in repository configuration. The CLI always prompts for a
folder when no explicit key option is supplied, even if prod.keys is beside a game.
The game app's key file is never packed into an IPA. Tests use disposable synthetic
bytes, not Nintendo key material.

## Game catalog

The home carousel lists all local game profiles as a support reference, with an explicit reminder that users must supply their own game files. **View all / Ver todos** at the top right of the carousel opens the searchable catalog. The native catalog reads every
16-digit title directory containing `dm/games/<id>/game.tsv` from the current checkout
when opened. It shows the profile name, registered build display versions and title ID,
with a link to the corresponding repository game note. Search ignores case and accents
and matches name, version or title ID; whitespace-separated terms must all match.
No game artwork or network request is needed to populate/search the list. Profile
presence is not interpreted as verified iPhone gameplay. The current checkout has 70
profiles, including regional variants.

## Simplified player flow

The home screen contains the catalog, game-folder selection, explicit keys-folder
selection and one prepare action. Empty-state status copy, technical cache choices,
permanent legal/compatibility footers and the standalone installation-guide link
were removed. There is one progress indicator while running. Only failures expose
raw diagnostics; common missing-tool failures receive direct recovery instructions.
The catalog keeps version search but does not show raw title IDs in every row.

When an existing or newly built IPA is available, the app shows the two remaining
steps: send the prepared file to Sideloadly, then copy RomFS through Finder for a
first installation. Sending a file opens it in the installed Sideloadly application;
it does not click Start, select an account, sign or install on a phone. If Sideloadly
is missing, the action is labelled Get Sideloadly and opens its official website.
The normal build workflow still requires Xcode/Homebrew first and installs other
missing dependencies. No Apple identity is selected by the desktop compiler.

## One-command setup and destination selection

`install.sh` installs missing Homebrew/build tools, prepares an isolated Python
runtime, compiles the desktop app locally and opens it. Full Xcode must already be
installed and opened once; the script checks this before downloading anything.
The install uses an independent source checkout and never resets local changes.
`--check` reports prerequisite status without installations or network access.

Users must explicitly choose iPhone/iPad or Mac before preparing a game. The iOS
route preserves the lightweight IPA workflow and `nxnative-ios.json`. The Mac route
uses the upstream `--platform mac-app` packer with explicit ad-hoc signing, a unique
output path per build and a separate `nxnative-mac.json` output record. It uses the
upstream per-title save location without replacing iOS state. Apple silicon is
required. Successful packaging is not a new claim of gameplay verification.


## Controller readiness and one launcher

`desktop/NxNativeEasy/ControllerMonitor.swift` enumerates `GCController.controllers`
at launch and refreshes on connect, disconnect and foreground notifications. Only
an extended gamepad profile is marked ready. The entire controller panel is displayed only for Mac builds. This is local Mac
input readiness, not a claim of a phone connection or a successful game boot. It does not install
input handlers or change pairing, so it cannot take input away from a game.
Notification tests use Apple's snapshot controllers, including unsupported profiles;
they do not claim testing physical Xbox or PlayStation hardware.

The launcher has one SwiftUI Window scene and activates an existing process with
the same bundle ID rather than keeping a duplicate process. The installer and
local opening command now use `~/Applications/nxnative Easy.app` by default.


## Live controller test

The Mac-only Test controller sheet samples `GCExtendedGamepad` values at 60 Hz
while visible and foreground. It draws actual button/D-pad presses, both stick
positions, thumbstick clicks, menu buttons and analog trigger pressure. The success
label requires input, not a connection alone. PlayStation gamepad profiles use
PlayStation face-button symbols. Disconnecting or changing the selected controller
clears stale input; switching to another app clears the live drawing. Sampling
never replaces input handlers or enables background controller capture.
Snapshot-controller tests check pressure, axes, releases, disconnect and selecting
a second device. They are not physical-hardware or game compatibility validation.


## In-app source updates (1.4+)

`desktop/release.json` is the public release version, monotonically increasing
build number and minimum macOS version. The app checks GitHub's public main commit,
then reads the manifest pinned to that SHA. It checks at launch, every six hours
while open, and from the app menu. Offline automatic checks stay quiet.

The bundled `update_app.py` helper downloads only the fixed repository at that SHA,
rejects unsafe ZIP paths, symlinks, game packages and credential filenames, and
extracts to a new versioned directory under Application Support. It never pulls or
resets the existing checkout. It compiles the app in a staging directory on the
installation volume and verifies its build, version, bundle identifier and ad-hoc
signature before asking the old process to quit. After that process exits, it swaps
in the new bundle, retains a hidden backup and relaunches. A failed swap rolls back;
a failure before verification leaves the running app intact. The helper serializes
updates with a per-installation file lock. It does not sign or install iPhone games.

`--prepare-only` downloads and compiles without closing, replacing or launching an
installed app, for release validation. Pass an external `--cache` directory in tests.
Older apps must run the setup command once to receive the updater itself. Existing
prepared games require a normal rebuild to incorporate newer engine/profile code.

Profile artwork is mapped by title ID in `desktop/NxNativeEasy/game-artwork.json`.
All 70 current profiles use existing repository screenshots, including the shared
13 Sentinels image for its Asia profile; no network image search is performed.

Validation on 2026-10-26 completed an actual in-app update to public commit
`86793e23d67cdb035405996d3fa6d79acc9586a8`: download, staged compilation,
signature verification, backup, replacement and automatic relaunch all passed.
The resulting app reported version 1.4/build 5 and only one launcher process
remained. The manual check then reported it was up to date. The 24 script tests
and four documentation checks passed. No game preparation or gameplay was part
of this updater validation.
