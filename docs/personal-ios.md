## Interface language

The desktop app defaults to English. Its English/Español selector updates labels,
status messages and app-owned folder-picker prompts immediately, and persists the
choice in local UserDefaults (`interfaceLanguage`). Invalid saved values fall back
to English. Game language, the in-game touch editor and raw build/tool/OS diagnostics
are independent and are not translated by this selector. Gameplay compatibility is
reported by upstream game notes, not detected from a build or device by this app.

# Desktop interface

For daily use, open `~/Applications/nxnative Easy.app`, choose iPhone/iPad or Mac,
select your own game and key folders, and press Prepare game. Cards use existing
repository screenshots. The interface shows progress, cancellation and the output
steps appropriate to the selected target.

On another Mac, run the root `START-HERE.command` or the README's single-command
installer. It keeps an independent checkout and prepared tools in Application
Support, builds the launcher locally with ad-hoc signing and opens it. Full Xcode
must already be installed and opened once. No Apple account is used for these
builds. Source ZIPs can be deleted after setup; games and keys remain external.
Cancellation signals the entire build process group.

# Personal iOS builds

This branch retains nxnative's MIT license and attribution. It starts from
upstream `ecbeae164c0b419d1ba1031248fe1402050a3eb0`, includes the shared iOS touch
editor and the tested #277 extraction-space fix. Release 1.5 integrates upstream
main through the SHA in [upstream-sync.json](upstream-sync.json); the previous
working game apps/caches remain untouched. The new chain has a separate validated
Dread shader build. See [the integration review](personal-pr-review.md) and the
[standing agent procedure](agents/07-upstream-maintenance.md).

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
original geometry and need **Save** to confirm. Each game now stores four named
profiles under `DmPadProfiles.v2.<Title ID>` in UserDefaults; every profile has
independent 2D/3D maps and the selected slot survives relaunch. The first profile
migrates both legacy `DmPadControls.v1.*` maps without deleting them. Names can be
changed from the profile menu; **Save as…** copies both maps plus the visible
draft into another slot after confirmation, preserving the source. Switching
profiles releases touches and asks before discarding a dirty draft. Cancel reloads
the current saved profile; reset affects only its current layout after Save.
Profiles are local to the device, not uploaded as game progress. The game keeps running during editing. Controller connection changes
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

## Clean-download installation validation (1.4.1)

On 2026-10-26, a public GitHub main ZIP at `a5ed1e8` was downloaded and
extracted outside the development checkout. Its `START-HERE.command` was run
through Bash with new installation, tools and application directories. Automatic
opening was suppressed only so the installed bundle could be opened explicitly
through the UI. Setup cloned an independent checkout, created a new Python
environment, installed its packages, compiled and signed version 1.4/build 5.
After moving the downloaded folder away, the installed app still opened and
its catalog displayed all 70 profiles; searching Metroid returned its one profile.

That unmodified release version detected the genuinely newer public release
1.4.1/build 6 at `d151d54`. Clicking Update now downloaded, compiled, verified,
replaced and automatically reopened the app. Its version, pinned source revision,
ad-hoc signature and retained previous bundle were verified; one launcher process
remained, and the manual check reported it was up to date. Only the validation
cache location was overridden, keeping test downloads in the separate validation
directory outside the checkout.
The original installer checkout remained clean and unchanged.

A second new installation used the current published raw `install.sh` with
separate source, tools and app directories. All four setup stages completed and
produced version 1.4.1/build 6; opening it through Finder displayed the home
window with its profiles and game/key folder selectors. Launcher rebuilds now
stage and verify before
replacement, keep backups and roll back on replacement failure. Regression tests
cover compile failure, replacement failure and preserving an unrelated app.
All 27 script tests and four documentation checks passed.

This validates clean app installations on an existing Apple silicon Mac, not a
fresh macOS installation or another physical Mac. Xcode 27.1, Homebrew, Metal
tools and system build dependencies were already installed; initial installation
of those system components, browser quarantine prompts, a fresh macOS user
account and game compilation/gameplay were not exercised by this check. No
game packages, keys or saves were used or modified.

The clean-install check above did not start game preparation. A later user report
exposed a Foundation worker-launch failure, fixed and reproduced in 1.4.2; see
[Prepare game fails at os.setsid](reference/packing.md#prepare-game-fails-at-ossetsid).
The regression suite now exercises the actual Foundation launch mechanism.

## Cloud-save investigation and API foundation

The separate [save API prototype](../dm/cloud/README.md) records the current save
layout, transaction/case-alias constraints, portable snapshot envelope, identity
provider requirements and remaining native restore work. It stores immutable
versions with optimistic concurrency and authenticated, expiring/revocable copy
sharing; it does not access game files or modify game saves. No native cloud
controls are exposed before login, export and journaled restore are integrated.

On 2026-10-26, upstream main was checked and still matched our integrated
`40e6baede556acd454169ac75b33d1686063f528`. No open PR or new engine/shader change
was imported for the control-profile/API work. The shared profile storage's native
Foundation tests and unsigned production iOS compile/link passed; actual touch
menus on physical iPhone/iPad still need device validation after sideloading.

The focused profile/geometry/API checks passed (9 tests, including real RSA JWT
validation and loopback HTTP); the script suite passed 50 tests (one optional
JWT test skipped without the API dependency), and Python lint had no new
findings. A final iOS compile check compiled 178 sources with zero failures.
The gameplay regression harness was invoked but found no registered Mac build
for the local Dread folder (its `tools/dmhost` is absent); it did not run a
save/gameplay comparison. Existing game packages and save folders were untouched.

## Upstream Metal front-end update after the profile work

A final remote check found a newly published main commit, `8334fdfb50a9900d8a5fc950d099fde46d85135f`.
It was reviewed and merged in a detached candidate, retaining the fork and all
four-profile/API changes. It changes Mac/iOS Metal front-end optimization to
`-O1` and the coherent shader chain to `d374e783beec`; no profiles were added,
removed or changed. The catalog gate still covers 78 profiles/artwork mappings.

Validation passed: the candidate's 451 Python cases across 63 suites (optional
checks retain their documented skips), the tool suite (301 cases, 16 skipped),
native Metal graphics suite, Dread Mac host build and unsigned production iOS
compile/link with synthetic game modules. A full separate Dread shader rebuild
produced 1,010 successful shaders plus 359 pulling variants for Mac and iOS with
no compile failures, stamped with game inputs `d2ce2b7a20f2`. The existing
`own_compilers.py` flow explicitly reported this Mac's spirv-cross fingerprint
`242d2c694be3ec91`, differing from upstream's tested `d9dc197f061b42a5`; the
locked translator matched and no tool lock or chain was falsified.

All shader/build outputs are in the external `upstream-o1-validation-20261026`
folder. The gameplay regression harness was invoked again but could not discover
a registered Dread Mac build (`tools/dmhost` absent); no real gameplay/image or
physical iPhone/iPad comparison was performed. Existing installed games, working
caches, keys and saves were not changed. Preparing a game again builds against
the new chain and includes the control profiles; sideload over the same bundle
identity rather than deleting the game to retain its local data.

## Live preparation logs and game updates

Version 1.7/build 11 detects prior target-specific preparation records and explains
Mac versus iPhone update handling. Mac output remains a fresh complete app;
its previous identity and Title ID are checked before recording success, and
external saves are untouched. iPhone retains its existing identity checks;
content updates require the new RomFS, preserving the app and both save roots.

The shared worker retains cancellable process groups, persists console output,
streams bounded changed compiler-log tails and leaves original logs complete.
The native parser handles split UTF-8/JSON records, partial final lines and
unknown counts. The UI exposes live logs, compiler-log folders and elapsed time;
it never invents a percentage or interprets silence as a dead process.

The separate [REA flow](game-analysis.md) exports original NSO to ELF and offers
optional local analysis. Synthetic converter tests exercise the actual NSO/ELF
tool, source integrity, destination isolation, tool pins and preserved Evidence
on provider failure. Published REA 6.8.0 was downloaded with isolated Node
24.22.1 and provider discovery ran successfully; no native decompiler provider
was configured on the validation Mac, so full Ghidra/Hopper/IDA analysis is not
claimed. No real game module, game installation, key or save was changed.

Validation for this release: 58 script cases passed (one optional API-identity
test skipped without its separate dependency); focused native progress/log/
language cases passed, including byte-split UTF-8, real counts, final log replay,
private retained logs, bounded tails and Foundation cancellation. The production
SwiftUI bundle compiled and its ad-hoc signature verified. The game catalog
remains 78 profiles and documentation checks passed. Python lint retained 414
baseline findings and introduced none. `scripts/regress.py` was invoked, but no
registered Dread Mac build was discoverable (`tools/dmhost` absent); no gameplay
comparison or physical Mac/iPhone update was performed. The shader chain and
runtime were not changed by this release.

## Native installation and save-location guidance (1.8)

The [native sideloading implementation](sideloading.md) uses an ARM64 helper with
isideload/idevice and an exact-identifier patch. REA read-only inspection of the
installed Sideloadly 0.71.1 found an x86_64-only executable; it did not recover
source. No Sideloadly proprietary resources are distributed. Helper/build source,
checksums, licenses, Keychain/stdio policy and runtime validation limits are
recorded in the linked guide. Existing game outputs remain unsigned and intact.

The player-facing [save guide](saves.md) and [Spanish guide](saves-es.md) distinguish
Mac Application Support, iOS Documents, account/device saves, transient journals,
RomFS, app preferences and the limits of manual copies. A Your saves sheet links
those guides and can reveal the default Mac folder by Title ID. Cloud sync is
still inactive. No real Apple login, game signing or device installation was
performed during development; physical validation is required before promoting
the integrated installer over the retained Sideloadly route.

Validation: all 10 Rust unit tests passed, including exact app/extension identity,
restricted RomFS access and fail-closed idle detection. All 62 script tests passed
with one optional API dependency skip; the Swift client tests use a simulated
helper, not Apple services. The ARM64 production bundle compiled and verified
with an ad-hoc signature; its helper links only system libraries. Catalog and
documentation checks passed, with no new Python lint findings. The gameplay
harness could not discover a registered Mac Dread build (`tools/dmhost` absent),
so no gameplay comparison is claimed. Runtime and shader chain are unchanged.
Real account authentication, signing, installation, AFC recovery and scheduled
renewal still require physical-device validation.

## Device/game installation library (1.8.1)

The main window now opens My iPhones and iPads independently of preparation.
Recorded installations expose actual expiry, per-game schedule controls, manual
renewal, Keychain session reuse and metadata-only removal. Manual renewal retains
the original source hash and identity, does not recopy RomFS or enable a paused
schedule, and refuses a different account. Both player READMEs describe the native
flow first and retain the Sideloadly fallback and physical-validation boundary.

The expanded compiled Swift IPC fixture passed with synthetic login/2FA/restore
and installation events, multi-game metadata persistence, manual-refresh protocol
assertions, account rejection and non-destructive record removal. The production
ARM64 bundle compiled and its signature verified; localization, documentation and
78-profile catalog checks passed. No runtime, shader or Rust helper change was
needed. No real account login, signing or physical-device install was performed.
