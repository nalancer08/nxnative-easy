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
