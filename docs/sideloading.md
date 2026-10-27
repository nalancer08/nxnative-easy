# Native iPhone/iPad installation: implementation and validation boundary

Version 1.8 adds an integrated **experimental** Apple-silicon installer. Its UI,
ARM64 build, helper protocol and synthetic policy tests are implemented. A real
Apple-account login, provisioning/signing, phone installation, save-preserving
upgrade, RomFS recovery on a physical device and unattended refresh still need
end-to-end device validation. Keep the working Sideloadly path available until
those checks pass. Do not present compilation as proof of a working install.

## What REA established

REA 6.8.0's `inspect-macho` inspected the user's installed Sideloadly read-only.
The inspected version was **0.71.1**, with an **x86_64-only** main executable.
The [inspection summary](sideloadly-investigation.json) records its SHA-256,
architecture, scope and limitations. The large raw Evidence remains outside the
repository. No account data was read and no proprietary binary/source was copied.
This was native metadata/import inspection, not recovery of a complete source tree.
No official Sideloadly source distribution was identified during this review.

The actual native implementation uses open source:
[isideload](https://github.com/nab138/isideload) 0.5.0 and
[idevice](https://github.com/jkcoxson/idevice) 0.1.68, both MIT. It does not embed,
patch, emulate or launch Sideloadly. The Rust helper and SwiftUI interface build
for ARM64. A small audited isideload source patch preserves the exact supplied
bundle identifier instead of always adding a team suffix; see the vendored
[patch record](../native/sideload-helper/vendor/isideload/NXNATIVE_PATCH.md).
The source and MIT attribution remain available in this repository. Other library
licenses, including the signing library's MPL source links, ship in the bundle's
`Contents/Resources/SideloadLicenses`; Cargo.lock pins the dependency graph.

## User flow

1. Prepare the game normally. Its original IPA output remains unsigned.
2. Choose **Install on iPhone / iPad**. Connect/unlock and trust the Mac; enable
   Developer Mode on the device if iOS requests it.
3. Sign in with your own personal Apple account. Enter verification codes in the
   same window; resend/device/SMS methods are available when Apple requests them.
4. Explicitly choose your personal developer team. It is not selected silently.
5. For a Sideloadly migration, select the actual existing game from the device's
   app list. Its exact effective identifier is used. The helper checks that the
   selected installed app matches the game and that the signed/provisioned
   identity matches the requested team and identifier. It stops on mismatch and
   never uninstalls the previous app to make an update succeed.
6. Sign/install. If the preparation includes separate `romfs`, the same helper
   transfers it through HouseArrest/AFC. Keep the game closed until it finishes.
   A refresh of unchanged content installs only the app; it does not recopy RomFS.

Apple's account/device/app/certificate limits continue to apply. Maximum-certificate
failures stop the operation: our callback never authorizes revoking someone else's
certificate. A renamed/custom existing app whose game identity cannot be verified
must use the retained Sideloadly path until migration is validated; the installer
must not guess or delete it. A different signing account/team can be rejected by
iOS even with the same identifier. [Save locations and backup limits](saves.md).

## Credentials and authentication service

The helper accepts bounded newline JSON on a private stdin pipe. Passwords and
verification codes are not argv, environment variables or persistent diagnostics.
They go to Apple's authentication API through isideload. The UI clears password
and code fields after submission; helper errors expose fixed messages/codes rather
than raw HTTP bodies, tokens or provisioning contents.

**Remember session** stores session data in macOS Keychain, not the Apple password.
Anisette state and our signing private key/certificate cache also use Keychain in
separate namespaces. Forgetting login removes the remembered session and disables
our refresh jobs; it does not revoke certificates or delete the reusable identity
keys. Updates of an ad-hoc-signed app/helper may require Keychain access approval.

The default configurable HTTPS anisette endpoint is isideload's published
`https://ani.iloader.app`. It receives the technical identity/provisioning data
needed by that protocol, not the password/code sent to Apple. This is a third-party
service, not a cloud-save account or a completely offline authentication system.
The UI exposes the endpoint before sign-in; a compatible self-hosted HTTPS service
can be used. TLS verification is retained. No insecure-debug mode is enabled.

## Refresh behavior

After a successful installation and actual profile-expiry validation, a private
`~/Library/Application Support/nxnative Easy/refresh-jobs.json` stores metadata:
IPA path/hash, game-folder path, device UDID, team/effective ID, hashed account,
expiry and opt-in status. No password or Apple session token is in that file.
The original IPA remains in the user's game folder; keep it for future refreshes.

Every 30 minutes while the app runs, opted-in jobs are considered within 48 hours
of their **actual** profile expiry. The Mac must be awake, online and able to reach
the already paired device by USB or configured Wi-Fi. The app does not create a
permanent signature or work while the Mac is off. Opening the app at login is an
explicit optional Login Item and may need macOS approval. No separate GUI app is
required. Only one job runs at a time, outside game compilation/launcher updates.

Before an automatic reinstall, Xcode's read-only `devicectl device info processes`
query must report that the game's executable is not running. Running games are
postponed; an unavailable/unrecognized process inventory requires manual refresh.
The helper never terminates the game to make renewal succeed. This guard is
checked before signing and again before installation; it still needs physical
validation and cannot promise an atomic lock against a user launching the app
between the check and installation. Process inventories are not persisted.

Each refresh restores the remembered Keychain session, retains the same
account/team/device/effective ID, checks that the installed target still exists,
and verifies the original IPA hash. It never resurrects an app the user removed,
signs changed source silently, changes account/team or recopies game content.
Expired sessions require manual login; other failures back off for six hours.
A successful install records the new real expiry. There is no automatic retry
that revokes certificates or deletes apps to bypass Apple quotas.

## RomFS transfer and saves

Only `/Documents/romfs` and reserved `.nxnative-romfs-*` journal/staging paths are
reachable through the transfer wrapper. `save`, `save_device`, preferences and
arbitrary container paths are refused even if a future call passes them by mistake.
The source inventory rejects links and special files. Uploads use bounded chunks,
real byte progress, size checks and source-change checks.

For updates, content is staged separately with a recovery journal. Previous
RomFS is moved to a reserved backup before publication; incomplete publication is
rolled back on retry, while a completed journal only cleans old content. Extra
storage for staging is required. A cancelled/interrupted transfer can leave its
journal/temporary data and require retry before the game is ready; it never uses
save folders as scratch. Device disconnect, power-loss and actual HouseArrest
behavior still need physical-device validation. Tests cover the path capability,
source inventory and recovery decisions, not an actual disconnected phone.

## Build and test

`scripts/build_sideload_helper.py` downloads checksum-pinned official Rust 1.99.1
ARM64 components into a private external build cache, preserving any installed
Rust/Homebrew configuration. Official component manifests are installed directly
because Rust's shell installer mishandles prefixes with spaces. The isolated
LLVM-tools component supplies the matching `libLLVM` required by `rust-objcopy`.
System Python 3.9's missing tar filters are handled by validated extraction.
The desktop builder compiles/signs the nested helper ad hoc before verifying and
atomically replacing the launcher. No Apple account is used for this build.

Local checks: Rust policy/archive/recovery tests; a Swift client using synthetic
stdio login/2FA and no account/device; pin/bootstrap/unsafe-archive fixtures;
redacted compiled-helper diagnostics; production ARM64 bundle/signature and
system-library linkage checks. The native CI job performs no Apple login,
Keychain credential creation, signing of game IPAs or device installation.
Cloud-save work remains separate and inactive until native backup/restore is
implemented and validated.

## Installation library (1.8.1)

**My iPhones and iPads** is available independently of the current preparation.
It lists all our recorded installations, their devices, exact effective IDs,
actual expiry dates and per-game refresh toggles. It does not import another
installer's private credentials or claim to discover all its scheduled jobs.
For a previously Sideloadly-installed game, prepare the same game and select its
actual installed app in our installer; retain the same Apple account/team.

Manual **Refresh now** preserves the recorded IPA hash and identity, checks the
account and connected device, signs/installs the unchanged app and omits RomFS.
It can reuse an authenticated session or restore a remembered Keychain session.
Save and close the game before manual refresh; automated refresh retains its
fail-closed running-process guard. Manual refresh does not enable a previously
paused schedule. Record removal only changes local scheduling metadata, never
uninstalls an app or deletes source game files. Login, expiry and USB/AFC behavior
remain subject to the physical validation boundary above.

The implementation covers our prepared-game installation lifecycle. It is not a
full binary/source migration of Sideloadly: no proprietary code is available to
port, and arbitrary IPA injection/plugins and all of its advanced options are
not implemented. Intel Sideloadly is not required by the native code path.

## Guided device workspace (1.9)

The device workspace separates three different inventories:

- **Connected devices:** read-only usbmuxd/Lockdown discovery. Duplicate USB/Wi-Fi
  entries are merged by UDID, preferring USB for operations. Device cards show
  Apple's model identifier, OS version, available transports and trust/readiness.
  A model identifier is not a guessed marketing model name.
- **Installed games (scoped since 1.10.1):** only exact identifiers from local
  preparations/our installation records, plus a strictly checked legacy team
  suffix for the same known nxnative Title ID. Matching never uses display names.
  First query explicit BundleIDs. If a known standard game is missing, legacy
  discovery requests only CFBundleIdentifier, discards unrelated identifiers and
  fetches names/versions only for matched games. Other app containers/files are
  never opened. **Update using my files** carries that game/device into preparation.
- **Apple-account devices:** after login and explicit team selection, **Read my
  Apple account devices** queries that team's actual registrations. This is not
  the same as a list of devices currently connected. A query failure is shown,
  not interpreted as zero registrations or available free slots.

Apple documents a Personal Team limit of up to three test devices and seven-day
profiles in its [account overview](https://developer.apple.com/help/account/basics/about-your-developer-account).
Sideloadly's [FAQ](https://sideloadly.io/faq.html) also describes the three-active-app
limit for free accounts. The UI shows returned registrations and team type; it
cannot infer a reliable remaining quota from installed user-app counts, count
paid teams as free, remove registrations or bypass Apple's limits. No speculative
"slots remaining" counter is displayed.

### Folder to device

Choose iPhone/iPad, select your own game folder and keys, select packaging, and
press Prepare. Compilation already exposes live and retained compiler logs.
After success the native installer opens automatically: select the device, sign
in with your Apple account/2FA, explicitly choose your team and existing target,
then approve signing/installing. Installation remains an explicit button; finishing
compilation never signs or installs silently. Device-workspace account access is
also available before preparing a game. A new source folder alone does not
install anything.

**Lightweight IPA** is the default. RomFS remains separate and the installer
copies it with bounded progress and staging/recovery. **Complete IPA** uses
`--full-only`, omits separate content transfer and includes the game inside the
app; every signature renewal must transfer that larger app. Archive expansion is
bounded to 64 GiB; use lightweight mode for larger content or constrained storage. Older preparation
records require a new full preparation before using this mode. During native
signing a bundle with RomFS gets `DMPreferBundledRomFS`; the updated game runtime
then checks bundled content first, falling back to Documents when absent. This
prevents a complete game update from booting an older external RomFS. It does not
delete the previous external directory or touch saves. Legacy apps without the
flag retain their intentional Documents override. Physical content-mode migration
still needs device validation.

**Installation activity** shows timestamped, bounded events for discovery, login
state, device registration, signing, signature verification, installation and
content transfer. Percentages come from actual helper callbacks when available;
otherwise progress is indeterminate with elapsed time. The viewer can copy the
log and reveal a retained `nxnative-tools/logs/install-<id>.log` in the game folder.
Only fixed local status/error messages and numeric progress/Apple error codes
are logged, never raw protocol payloads, passwords, 2FA codes, Apple responses,
account names, device IDs or session tokens. The compiler log remains separate.

### Honest parity boundary

The REA investigation was read-only Mach-O inspection, not full decompilation or
a recovered Sideloadly source tree. This project implements our game workflow
using a separately licensed open-source signer. It has no claim of full Sideloadly
parity: arbitrary IPA/plugin injection, all advanced signing options and its
unattended background-daemon behavior are not implemented. Auto-renewal requires
our launcher running. Real connected-device metadata and installed-app discovery
were checked locally; account registrations, real provisioning/signing, physical
RomFS recovery and unattended renewal remain unvalidated. Keep the fallback.

## Inline Devices and restricted game discovery (1.10.1)

**Devices** is an in-window workspace page with a selected sidebar state, not a
sheet. Library/preparation state and background activity remain alive across all
three pages. Opening account/signing forms is still an explicit separate action.
Choosing game files from Devices changes to preparation without dismissing the
main window. Renewal records are scoped to the selected device.

The helper requires an explicit game scope: original IDs from folders in the
personal library/current preparation, and exact effective IDs from our device's
installation records. Empty scope returns an empty result without connecting to
installation_proxy. No `Lookup` without BundleIDs remains. Exact lookups run
first; missing standard `org.nxnative.<16-hex-title>` games may use a minimal
identifier-only Browse to find one 10-character alphanumeric team suffix. Custom
legacy IDs need an exact known preparation/installation record; names, loose
prefixes, accepted-profile lists and all-app catalogs are not ownership evidence.

This fallback necessarily sees an identifier index of user apps, but requests no
names, versions, paths or files for unrelated apps. If the device ignores the
requested attribute/scope restriction, stop instead of falling back to a broad
inventory. The public [installation-proxy implementation](https://cgit.libimobiledevice.org/libimobiledevice.git/tree/src/installation_proxy.c?id=d87213038d0a428adb3e91432a1b7f6ae4817993)
documents BundleIDs/ReturnAttributes behavior. The Swift client also filters
returned rows independently, including an unrelated app with the same game name.
Old helpers lacking `scoped-games-v1` cannot be asked for app discovery.

Local read-only validation with the Metroid preparation scope returned only
**Metroid Dread** from the connected phone, replacing the previous broad inventory.
No app was installed, updated, uninstalled or accessed through HouseArrest during
that check. Rust tests cover matching boundaries and empty-scope/no-device access;
compiled Swift/protocol tests cover scope forwarding and unrelated-row rejection.


## Save export, standalone content copy and app-only updates (1.11)

Recognized device games now resolve artwork through the local profile catalog
using their Title ID. No name-based ownership matching was added.

**Export saves** is a separate read-only HouseArrest/AFC module. Its path boundary
can address only committed `save`/`save_device`, never game content, transaction
siblings, credential files or arbitrary container paths. It refuses unsupported
case aliases, checks source stability with inventories plus two hash reads and
publishes a local ZIP atomically without overwriting another backup. Directory
permissions remain traversable (0700); files/the archive are private (0600).
Destinations inside Git checkouts are refused. No restore/device write endpoint
was introduced. [Export format and limits](saves.md#export-from-a-trusted-iphoneipad-111).
A real read-only Metroid export was verified locally: four committed files,
38,362 uncompressed bytes, ZIP CRCs and per-file hashes checked. The private ZIP
is outside this repo and is not published. The device was not modified.

**Copy game data** transfers the local preparation's RomFS to the selected
recognized game without signing/reinstalling or asking for an Apple login. The
client and helper check the installed game version; keep the game closed.
The existing RomFS-only staging/recovery capability remains unchanged, so this
operation cannot write to saves. It has not been rerun over the working Metroid
content just to test this UI; physical interrupted-transfer recovery remains a
validation item.

**Update app only; keep romfs** is offered for an existing installation when the
reported game version matches the local preparation. It sends no RomFS and keeps
existing data. The helper checks the IPA's actual version against the installed
app again; scheduled renewals now also stop on a version mismatch. This is not
a full asset-difference detector: new game assets, mods or DLC need their new
data even if the displayed version happens to be unchanged.

For controls/runtime-only changes: prepare again with valid cached work, then
choose app-only update. For a new game update: place your own new NSP update with
the base files, prepare again and install the app plus its newly prepared data.
Retain the same effective bundle ID/team/account and never uninstall the previous
app. Support for the new game version still depends on the engine/profile.
A lightweight IPA still needs the complete RomFS on the phone; it makes app
signing/reinstallation smaller, not the game data optional. Full-IPA mode embeds
those data and retransfers the larger app on renewal.

## Apple verification presentation (1.13.1)

An active verification challenge replaces the password form with one card:
account context, six-digit ASCII code input, paste/Enter support and one primary
Verify and continue action. It remains disabled until six digits are entered.
Alternative trusted-device/SMS delivery and resend live under Did not receive a
code, rather than competing with verification. The code is cleared on submission
or requesting another delivery and is never persisted or logged. No password,
provider/session, request transport or delivery behavior changed. Generic busy
activity and the installer Continue button do not compete with a pending code.
The update does not restart a running launcher or interrupt its in-memory login.
