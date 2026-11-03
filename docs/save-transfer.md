# Your saves, between devices

Open **Saves** in nxnative Easy on Mac. Choose the same iCloud Drive folder used
inside your rebuilt games. This grants folder access; it does not use the Apple
account that signs your apps. The desktop lists all received revisions by game,
source device, version and date. Select one to check its complete archive before
preparing a copy. Dates identify revisions; they never decide a winner.

## Bring a console backup to Mac, iPhone or iPad

1. Keep an untouched backup from your console save manager. Choose the actual
   save-data folder or ZIP, not the console's encrypted NAND/SD storage. No game
   files, ROMs or keys are needed or accepted.
2. Prepare your game with save continuity, choose your iCloud folder inside it,
   and save once. A checked first snapshot identifies the game's save layout.
3. In Easy, choose **Saves → Bring a backup**, then the folder or ZIP. Select the
   game from your own library and confirm the same version, update and DLC. Raw
   console files do not universally identify their title, user or version; Easy
   does not infer these from a folder's name.
4. Choose **Add to iCloud**. Easy verifies the selected
   build's content identity and publishes a new independent revision. Existing
   revisions, the source and active local saves are kept.
5. Wait for iCloud delivery. Open the matching Mac/iPhone/iPad game; its existing
   save panel checks the revision and offers a choice when progress differs.
   The game's recovery journal and backup perform any active restore.

Mac and iOS outputs must contain the same verified `dm/save-compat.json`. If an
old build lacks it or the platform contents differ, Easy asks you to prepare
matching builds. Updating Easy alone cannot add continuity to an installed game.
See [iCloud setup, conflicts and recovery](icloud-saves.md).

A game that uses personal and device/shared saves needs both committed roots,
`save/` and `save_device/`, from the same backup generation. A single account
backup cannot discard a known shared root. A device-only game uses the engine's
primary `save/` root too; imports use the checked runtime layout. This is file
interchange, not conversion between different games, editions or save schemas.

## Take an iCloud revision to Switch

1. Select the game/revision in **Saves** and let verification finish.
2. In **Prepare for Switch**, acknowledge that a console restore tool is
   required, then click **Prepare backup** and choose your SD card or an ordinary destination folder.
3. Easy makes a new `Easy-<title ID>-<date>-<unique suffix>` folder. It contains
   separate `save/` and, where needed, `save_device/`, a metadata report and plain
   English/Spanish instructions. Existing backups and iCloud history are kept.
4. On the console, first make a fresh backup with your compatible save manager.
   Match the game, user, version, DLC and save type. Copy the contents of the
   corresponding root into a **new** backup in that tool's expected layout and
   restore there. Never merge the two roots or copy Easy's instruction files into
   the game's payload.

The result is labelled **backup prepared, not restored**. Easy does not claim
installation on a console, format an SD card, change console software or access
Nintendo's cloud service. An SD copy alone cannot restore a save on a stock
Switch 1 or Switch 2. Nintendo's [data-management FAQ](https://www.nintendo.com/en-gb/Support/Nintendo-Switch/Data-Management-FAQ-1508495.html)
explains that saves are held in internal memory, rather than the SD card.

[JKSV](https://github.com/J-D-K/JKSV) exports/restores game save data on a Switch
that can run it. Switch 2 access has separate prerequisites. The independently
reviewed [ns2-savekit](https://github.com/dougchansan/ns2-savekit) describes a held
ns2jb session, firmware **23.0.1** and **SmileBASIC 4**; it is not a general stock
console USB/SD importer. Its own [hardware report](https://github.com/dougchansan/ns2-savekit/blob/main/docs/RESULTS.md)
describes its tested titles and limits. Easy neither bundles nor runs this
exploit/session tool. Do not infer access to an arbitrary console from an exported
folder or a successful desktop test. The owner's consoles are currently stock;
physical console restore is therefore not validated in this release.

## Preservation and limits

`scripts/save_transfer.py` is a bounded JSON helper using the bundled Python. It
reads the native `DMSYNC1` archive and immutable `.nxsave` revision format; native
engine fixtures check actual interoperability in both directions. User-confirmed
raw imports record that compatibility confirmation and create a branch with no
parents, so they never pretend to descend from another device's progress.

The source is checked again after review. Symlinks, traversal, duplicate paths,
unknown roots, changing files, damaged hashes, keys/game packages and working
transactions are refused. Transfer limits are 256 MiB and 8192 entries. Filename
alias metadata is preserved while reading native archives. Raw SD export restores
logical guest names and refuses case/Unicode collisions instead of silently
renaming or merging progress. No active Mac/iOS save directory is written by this
helper. The repository and standard active-save roots are refused as copy destinations. Failed exports retain a private partial directory and do not publish a
successful backup. Immutable cloud revisions use new-file-only publication.

Tests use synthetic saves and an ordinary temporary shared folder. They verify
the native engine imports a prepared revision, native snapshots export back to
identical console files, divergent progress remains a conflict, and a missing
second save root is refused. Actual iCloud delivery and physical console restore
are separate from these tests.


## Backups directly from your game detail

Open **Library → your game → Saves and backups**. To copy from iPhone, first save
and close the game. Easy makes a fresh scoped query for that exact device and app
identifier before offering a new local ZIP destination. It does not sign, log in,
copy RomFS or restore device progress. After a successful copy, choose **Add this
backup to iCloud** to enter the existing content/layout review; this never skips
compatibility checks or chooses a conflicting version automatically.

**Back up this Mac's save** reads only committed `save` and `save_device` roots
under the game's standard Application Support directory. A known running game
blocks the action; the user confirms it is closed. A second read detects changed
source files before publication. Working roots are excluded. Filename-alias
metadata that a ZIP cannot retain is refused. The destination must be new.

A checked cloud revision also offers **Save a local copy**, retaining its complete
`.nxsave` file inside a shareable ZIP. The canonical checksum filename is retained
inside; Easy can inspect/import that ZIP again without weakening integrity checks.
This is a backup, not an active local restore. No destructive
replace or console restore is added.
