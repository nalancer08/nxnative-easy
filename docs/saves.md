# Where your game progress lives

Game progress is local to the device on which you played. nxnative Easy on the
Mac prepares the game; it does not receive the iPhone's progress automatically.
Rebuilt game apps now include optional [iCloud continuity](icloud-saves.md).
Existing game apps need rebuilding once; updating Easy alone does not add sync.

## Mac

The default location for each game is:

```text
~/Library/Application Support/nxnative/<TITLE ID>/
  save/                 committed account/game progress
  save_device/          separate device-wide progress, for games that use it
  temp/                 scratch files, not progress
```

For Metroid Dread, `<TITLE ID>` is `010093801237C000`. In Finder choose
**Go → Go to Folder…** and paste:

```text
~/Library/Application Support/nxnative/010093801237C000/
```

The `.app` contains the engine and game data. Saves are outside it, so moving the
app or preparing a new version does not move or replace these save folders.
The Mac launcher chooses this directory by Title ID, not the `.app` filename.
Advanced `DM_SAVE` environment overrides can change the default location.

## iPhone and iPad

Each installed game has its own app container. The default paths inside it are:

```text
Documents/
  save/                 committed account/game progress
  save_device/          present only when the game uses a separate device save
  romfs/                game content for a lightweight IPA; NOT your progress
  temp/                 scratch files; NOT your progress
  log.txt               diagnostics; NOT your progress
```

The container has an iOS-managed UUID; do not look for a fixed Mac filesystem
path. To inspect the shared Documents folder, connect and unlock the device,
trust your Mac, then use **Finder → your iPhone/iPad → Files → the game**.
Finder shows the contents of Documents directly. Depending on iOS settings, the
game may also appear under **Files → On My iPhone/iPad**.

An iPad and an iPhone keep independent local copies. With iCloud continuity
explicitly enabled in both rebuilt games, checked snapshots connect that progress.
Without it, playing on one does not update the other. Signature expiry stops the app from launching but is not an instruction
to remove its data: renew the same app rather than deleting it.

## Updating without losing progress

- **Mac:** close the game, build/open the new complete `.app` with the same Title
  ID. The existing `save` and `save_device` stay in Application Support.
- **iPhone/iPad:** keep the same Apple signing account, team and effective bundle
  identifier. Install over the existing app. For changed game content, replace
  only `romfs`. Keep `save` and `save_device`. Do not uninstall the old app.
- Switching the signing account or effective identifier can create a different
  app/container. A tool must not pretend that this preserves the original save.
  The integrated installer refuses identity changes it cannot preserve.

The preparation records `nxnative-ios.json` / `nxnative-mac.json` in the game
folder are build metadata, not backups of your progress. An IPA is not a backup
of the installed game's Documents. A launcher update is not a game-save backup.

Folders may not exist until the game has first run and saved. These are the
game's own on-disk saves, not an emulator save state or unsaved RAM. Renewing a
signature does not save an open game for you.

## Manual copies and backups

First use the game's own Save option and close the game completely. Keep both
committed folders, if both exist, as one dated backup. For example, store it
outside the repository under your own game folder:

```text
<your-game-folder>/backups/iPad/2026-10-27/save/
<your-game-folder>/backups/iPad/2026-10-27/save_device/
```

A missing `save_device` is normal for games that do not use it. Do not replace a
real destination folder with an empty one. Keep the original backup and the
current destination before trying a restore. Matching game/Title ID, version,
DLC and account data matter; interchange between every game build or another
emulator is not guaranteed.

Manual file copies are a way to retain the files, not a certified portable backup
for every game. The engine can represent case-sensitive names with `.dm-case-*`
physical aliases and an `org.d2rmobile.guest-name` extended attribute. A tool or
archive format that drops that metadata can break those logical names. APFS-aware
copies on a Mac should preserve extended attributes; do not assume Finder/AFC,
Windows ZIP tools or a cloud-drive round trip preserves all of them. A future
native export/import must explicitly carry the known alias metadata and validate
restoration. We do not advertise the current API prototype as that exporter.

Do not back up live transaction directories such as `save.work`, `save.new` or
their `save_device` counterparts. The engine commits each save root separately;
copying during gameplay can mix two generations. `romfs` and console keys are
not required to transfer progress and should not go into a future save service.

## Touch-control profiles are separate

The four named control profiles are app preferences, keyed by
`DmPadProfiles.v2.<Title ID>`, with separate 2D/3D layouts. They are not files in
`save`. On iPhone/iPad they live in the app's preferences rather than shared
Documents. Updating the same app keeps them; copying only `save` does not copy
them to another device. Profile cloud sync/export is not implemented.

## iCloud continuity

Choose the same iCloud Drive folder in each rebuilt game's launcher. Save in the
game and close before switching devices. The destination checks complete revision
history before play; conflicting progress needs an explicit choice and both
versions remain available. See the [setup, history and recovery guide](icloud-saves.md).

Local history is next to the committed save, in `save.nxe-cloud/`. It contains
`revisions/`, verified `backups/`, retained displaced trees and, only during an
unfinished restore, `restore.json`. These are progress, **not disposable caches**.
Do not delete this directory to repair a sync error or while recovery is pending.

## Future portable server

No cloud host is selected. The API foundation is provider-independent: Python,
HTTP, configurable OIDC identity and SQLite. Its consistent database backup can
move snapshot history and ownership to another server.
[Configuration, backup and relocation](../dm/cloud/README.md#portable-hosting-and-migration).
This separate server prototype is not used by the iCloud feature and does not
receive any saves automatically.


## Export from a trusted iPhone/iPad (1.11)

In **Devices**, choose **Export saves** for a recognized game, save and close it
from the app switcher, confirm and select a new ZIP. Apple-account login is not
required for this read on an already paired/trusted device. **Show save ZIP**
reveals the result for manual sharing.

A separate read-only AFC capability exports only committed `Documents/save` and
optional `Documents/save_device`. It excludes game content, working transactions,
preferences and credentials. Inventories/sizes and a second SHA-256 read must
remain stable before a private ZIP is atomically published without overwriting a
backup. The package contains the same folder names plus
`nxnative-save-export.json` with game identity/version, hashes and source times.
There is no device write or restore operation in this module.

Observed running games stop export. If process inventory is unavailable, manual
export requires the player's explicit closed-game acknowledgement. Symlinks,
special files and `.dm-case-*` aliases are refused because AFC cannot preserve
the engine's case-alias xattr; use a complete device backup for those cases.
Limits are 512 MB and 8192 entries. A forced termination may leave a private
partial temporary file, never a falsely successful final ZIP.

Manual sharing/restoration still needs matching game/version/format and a backup
of the recipient's original files. Control presets are separate. This package
is not yet connected to the provider-independent cloud API or its nxsave schema.
There is no automatic import or universal emulator conversion claim.
