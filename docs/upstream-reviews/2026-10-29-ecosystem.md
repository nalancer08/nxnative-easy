# Ecosystem review and iCloud save continuity — 2026-10-29

Status: source audit, synthetic fault reproduction and implementation decisions.
No cloud runtime, sibling frontend or new engine commit is integrated by this
review. The released v1.20.0 includes upstream through `8e0916bf04f6`, with cloud
sync explicitly reverted. Existing games, keys, saves and packages were untouched.

## Owner decision and player experience

The owner now wants to play on iPhone/iPad and continue on Mac through iCloud,
and accepts substantial changes or recompilation when the benefit warrants them.
This supersedes the earlier local-only preference; it does not authorize silent
selection of a save to overwrite when two devices have different progress.

Recommended flow once implemented and validated:

1. Prepare updated Mac and iOS game apps once, preserving their existing bundle
   identities and local saves. Choose the same shared iCloud Drive folder in
   each game's launcher. The Easy app can guide the choice, but updating Easy
   alone does not update the runtime inside an already built game.
2. Save in the game on iPhone. A committed local save becomes a checked snapshot
   queued to the selected folder. Show local success separately from cloud
   availability. iCloud propagation may take time; an offline save stays local.
3. Before the Mac game starts, check and download the available revision, back up
   the current local save, validate compatibility and restore the whole snapshot.
   Show the source device and save date. Reverse the same flow to return to iPhone.

This needs no custom save API/server: upstream uses a selected folder and iOS
security-scoped bookmarks, not a private CloudKit container. Access to iCloud
Drive belongs to the device's iCloud account; the Apple account used to sign an
IPA in Easy is a separate concern. A signing-identity change may require picking
the folder again. This code path still needs physical iPhone/Mac testing under
our actual installation modes before claiming end-to-end support.

Only saves go through this path, not RomFS or game packages. Recompilation is a
one-time requirement to gain the runtime feature, not a step for each save.
Use the same title and compatible game versions/content on both sides; a shared
title ID alone does not prove save-format compatibility. Keep different players'
progress separate. Friends' save sharing should remain an explicit import, not
several people automatically overwriting one shared latest save.

## Upstream save code: useful foundation, two reproduced hazards

Inspected initial commit `123c7ff0ddcc188319da5bd035ac2cb2a86e1213` and current
code through `17f670a77e4faa3512c1441ebeedcbccb2deb3b3` (latest save-file change:
`0c94284e9f9a21418ac28d299d7fcc05a5c44335`). Sources:
[save_sync.c](https://github.com/seedds/nxnative/blob/17f670a77e4faa3512c1441ebeedcbccb2deb3b3/dm/host/save_sync.c),
[save_sync.h](https://github.com/seedds/nxnative/blob/17f670a77e4faa3512c1441ebeedcbccb2deb3b3/dm/host/save_sync.h),
[CloudSaves.m](https://github.com/seedds/nxnative/blob/17f670a77e4faa3512c1441ebeedcbccb2deb3b3/dm/ios/Sources/CloudSaves.m).

Good existing pieces: opt-in folder selection, one `<title ID>/save.dmsync`
snapshot containing `save` and `save_device`, integrity checks, local/cloud backup
retention, committed-save hooks, a short quiet period and bounded initial fetch.
The snapshot records title, device and time; it has no game-version field.

The isolated [probe](../../scripts/audits/cloud_save_probe.c) includes the pinned
upstream implementation in a temporary build and creates only synthetic files.
It does not open a game, real save or iCloud folder. Both hazards reproduce with
the initial and current implementation:

| Case | Observed result | Required change |
|---|---|---|
| Fail the second `renamex_np` in `pull()` | Pull returns an error, but `save` contains remote bytes while `save_device` retains local bytes. Each swap is atomic individually; the pair is not. | Recoverable transaction/journal covering both folders, including rollback and process-death recovery. Never start the game on a half-restored pair. |
| Diverged local snapshot has an older modification time than a diverged remote snapshot; call `send_save()` | Sender backs up the remote snapshot, then replaces shared `save.dmsync` with the older local snapshot. The mount-time newer-wins decision is not applied here. | Preserve both branches and pause automatic replacement on divergence. Do not resolve conflicts by device clocks alone. |

The second case does **not** mean every copy is permanently lost: a backup is
made. It means the shared latest save is displaced without a conflict choice.
These results do not imply that ordinary sequential play always fails.

Reproduce on macOS from this checkout (the pinned Git object must exist locally):

```sh
python3 scripts/audits/probe_cloud_saves.py \
  --upstream-ref 17f670a77e4faa3512c1441ebeedcbccb2deb3b3 \
  --output /tmp/nxe-cloud-review-new
```

Exit status 1 means at least one hazard reproduced, 0 means neither reproduced,
and 2 means setup/compilation/execution was inconclusive. JSON and logs are
written to a newly created output directory. This is an audit probe of excluded
upstream code, not a passing fork-runtime test or a promise that no other bug exists.

### Integration requirements

- Keep an active local save on each device. Publish immutable revisions with
  parent-revision identity; preserve concurrent branches. File coordination on
  one device is not a distributed lock between devices.
- Restore a validated complete revision before play. Validate title, player,
  format, file inventory/hashes and game/content compatibility; record the game
  version and relevant content identity in new metadata. Do not edit opaque game
  saves to force them to match. Legacy snapshots need an explicit compatibility
  path rather than an assumed match.
- Keep verified pre-restore backups and both conflict candidates. Publish backup
  and transaction state before swaps; retain recovery state until all steps and
  durability checks finish. Prune only after a successful transaction.
- Show actionable states: saved locally, waiting for iCloud, available in the
  shared folder, imported on this device, or choose between two saves. Do not
  equate a local file write with delivery to every device.
- Turning sync off leaves the last committed local save usable. Missing iCloud,
  stale permission, quota/full disk, cancellation or timeout must not delete it.
  If play continues offline, retain divergence for later resolution.
- Test clock skew, simultaneous play, first use with two existing saves,
  interrupted upload/restore, corrupt/truncated snapshots, unavailable iCloud,
  full disk, re-signing/bookmarks and mismatched game versions. Run synthetic
  failure tests first, then opt-in physical iPhone/Mac tests with test saves.

## Sibling implementations inspected

All five repositories report MIT at these pinned revisions. Copied components
still require original notices and their bundled third-party license review;
MIT at repository level does not license game art/content. This was a targeted
source review of the features below, not execution of their installers or a
line-by-line verification of every vendored engine file.

| Source and pin | Worth adapting | Limits and decision |
|---|---|---|
| [NX2Apple](https://github.com/LNPANDY/NX2Apple/tree/46ea54c6e2cf543cae3c88577692626669c73a58) | Real controller-first full-screen library, controller identification/player assignment, actionable build failures, and explicit fork-patch provenance. `LiveConsoleDriver.swift` launches real library games; it is not only a mock. | Reuse our library/preparation model. Their `BuildFailure.swift` parses errors for explanations; retain our structured progress events as the source of progress. Their patch queue is a useful ownership/status model, not a reason to replace our merge history. |
| [NXPlay](https://github.com/varyform/nx-native-wrapper/tree/eac0fb51819566cc3c76e550731056eebf1f29b1) | Clear two-direction manual save transfer with a backup of the replaced save, plus controller navigation and battery reporting. | `SaveBackup.swift` uploads to the player's own Git repository; this is an alternative backup product, not the automatic iCloud experience requested. `SaveTransfer.swift` handles `Documents/save`; our integration must include `save_device`, exact identity, closed-game checks and recoverable replacement. |
| [nxnative Launcher](https://github.com/rennan101/nxnative_Launcher/tree/5dc672687bf09d95fbcb9b444a49d9e43ce4c4da) | Discoverable save actions, before-sync snapshots, and simple mod on/off organization. | Do not port `SaveSyncService.swift` migration: it copies with ignored errors and removes the local directory to replace it with an iCloud symlink. Device sync assumes dates within two seconds mean equal and pushes Mac data when dates are unavailable. Neither is sufficient conflict handling for our saves. |
| [LumaNX](https://github.com/Xc1Ym/LumaNX/tree/56c794538d02bf9a04fab0898b66f740702f25c7) | `Worker/recovery.py` verifies snapshot inventories/digests, takes a pre-restore backup, locks against gameplay and atomically switches a prepared runtime. `milestones.py` learns durations from successful uncached runs. | Our logs, counters, incremental stages and rebuild provenance already exist. Add a recovery/version history and better labelled time estimates instead of a duplicate build engine. Their single-directory atomic exchange is not by itself a fix for our two-directory save transaction. |
| [MacNativeGames](https://github.com/ly05010419/MacNativeGames/tree/f1d00772df1ac3230268f3124bdeb6b7cc81a61c) | Version-bound mod manifests, original/replacement hashes, patch-overlap checks, separate overlays, and Metal/memory diagnostic recipes. | Different per-game runtime layout. Adapt contracts/tests, not entire runtimes. `mod_applied.py` uses size/mtime for its applied key and explicitly accepts missed equal-stat changes; our verified content identity should hash bytes. |

Key source entry points:

- NX2Apple: [live console](https://github.com/LNPANDY/NX2Apple/blob/46ea54c6e2cf543cae3c88577692626669c73a58/frontend/Sources/NSPortBuilder/LiveConsoleDriver.swift), [build failures](https://github.com/LNPANDY/NX2Apple/blob/46ea54c6e2cf543cae3c88577692626669c73a58/frontend/Sources/NSPortBuilder/BuildFailure.swift), [patch ownership](https://github.com/LNPANDY/NX2Apple/blob/46ea54c6e2cf543cae3c88577692626669c73a58/patches/README.md).
- NXPlay: [manual save transfer](https://github.com/varyform/nx-native-wrapper/blob/eac0fb51819566cc3c76e550731056eebf1f29b1/Packages/NXPlayKit/Sources/NXPlayKit/Model/SaveTransfer.swift), [Git backups](https://github.com/varyform/nx-native-wrapper/blob/eac0fb51819566cc3c76e550731056eebf1f29b1/Packages/NXPlayKit/Sources/NXPlayKit/Model/SaveBackup.swift).
- Launcher: [cloud migration](https://github.com/rennan101/nxnative_Launcher/blob/5dc672687bf09d95fbcb9b444a49d9e43ce4c4da/gui/Sources/Services/SaveSyncService.swift), [device sync](https://github.com/rennan101/nxnative_Launcher/blob/5dc672687bf09d95fbcb9b444a49d9e43ce4c4da/gui/Sources/Services/SaveSyncService%2BDevice.swift).
- LumaNX: [verified recovery](https://github.com/Xc1Ym/LumaNX/blob/56c794538d02bf9a04fab0898b66f740702f25c7/Worker/recovery.py), [time estimates](https://github.com/Xc1Ym/LumaNX/blob/56c794538d02bf9a04fab0898b66f740702f25c7/Worker/milestones.py).
- MacNativeGames: [mod pack contracts](https://github.com/ly05010419/MacNativeGames/blob/f1d00772df1ac3230268f3124bdeb6b7cc81a61c/docs/merged-mod-pack.md), [applied-state key](https://github.com/ly05010419/MacNativeGames/blob/f1d00772df1ac3230268f3124bdeb6b7cc81a61c/tools/builder/mod_applied.py).

## Bigger compatibility changes that merit separate trials

- NX2Apple's [CPU BC texture decoder](https://github.com/LNPANDY/NX2Apple/blob/46ea54c6e2cf543cae3c88577692626669c73a58/patches/0008-bc-cpu-decode.patch)
  targets GPUs without native BC compression, with a profile gate and format
  tests. This is a worthwhile older-iPhone compatibility trial, not a blanket
  compatibility promise. Measure decoded texture memory, startup cost, frame
  performance and image correctness on actual target hardware; preserve the
  native path where supported and the decoder's third-party license. Upstream
  declined this out-of-matrix feature, so ownership would remain ours.
- NX2Apple's [Atmosphere-format cheat engine](https://github.com/LNPANDY/NX2Apple/blob/46ea54c6e2cf543cae3c88577692626669c73a58/patches/0028-cheats-engine.patch)
  is a pending upstream proposal, not an accepted compatibility fix. Useful later
  with per-build matching and clear on/off state. Do not automatically carry
  fixed addresses across game updates or equate a cheat toggle with DLC support.
- RomFS images are worth an end-to-end packaging migration, rather than a
  one-line extraction toggle. Update splitter, preparation records, packer,
  native copy capability and both boot paths together. Preserve directory-mode
  packages and external data. The user accepts the work; current deferral is a
  dependency requirement, not a product rejection.
- NX2Apple's [old-chain pruning patch](https://github.com/LNPANDY/NX2Apple/blob/46ea54c6e2cf543cae3c88577692626669c73a58/patches/0032-nsp-script-remove-the-shader-libraries-of-older.patch)
  addresses real disk growth. Adapt it to our explicit cleanup preview/locks
  and rollback references; do not import automatic deletion of older artifacts
  that our recovery/history may still need.

## New original commits since the released baseline

Fetched original main and froze `17f670a77e4faa3512c1441ebeedcbccb2deb3b3`.
There are two newer commits and no added game profile directories in this range:

- [`0c94284e`](https://github.com/seedds/nxnative/commit/0c94284e9f9a21418ac28d299d7fcc05a5c44335):
  texture-handle bit width, capture operation-layout stamp, thread-safe audio
  offset caching, Frostbite cache scanning, and bounded cloud-fetch failure.
  Recommended for the next integration candidate. Some fixes are credited to
  LumaNX's author: taking them via upstream avoids duplicate fork patches. Its
  small cloud-fetch fix does not address either reproduced save hazard.
- [`17f670a7`](https://github.com/seedds/nxnative/commit/17f670a77e4faa3512c1441ebeedcbccb2deb3b3):
  generalizes large-region SDK alignment to 2 MB and improves patch review
  metadata/matcher behavior. Worth a candidate with rewriter/SDK tests and
  representative game rewrites/regressions; existing prepared games need a new
  preparation to gain changed rewrite output. It is not just a frontend update.

These are recommendations, not newly integrated commits. Keep `integrated_head`
at the released baseline until candidate checks and builds pass. Continue the
catalog/artwork/bilingual website gates for future accepted game changes.

## Recommended implementation order

1. Harden and integrate optional iCloud continuity, with verified save recovery,
   conflict choices and visible delivery state in the built game launchers.
2. Add prepared-runtime history/rollback and actionable recovery diagnostics;
   reuse existing provenance and incremental compilation rather than rebuilding
   everything after each interruption.
3. Add a controller-first library mode, battery/identify/player assignment where
   the device reports/supports them. Keep input handlers out of running games.
4. Add version-aware mod/DLC management and better local-history time estimates.
   Retain actual work counters and label estimates honestly.
5. Trial older-iPhone textures and the coordinated RomFS-image migration on
   separate candidates before broadening published device support.

No cloud feature is enabled or advertised as shipped by this review. The owner
approval and these safety requirements are standing instructions for future work.

## Review validation

- Native synthetic probe compiled and reproduced both hazards against initial
  `123c7ff0` and current `17f670a7` source. Expected audit exit: 1, with all four
  recorded observations true. No real iCloud or save directory was accessed.
- Documentation suite: 11 tests passed. New local report links resolve.
- Catalog gate: 114 profiles; artwork and bilingual galleries remain current.
- Python lint/type ratchet: 392 existing baseline findings, zero new findings.
- No game-runtime release or gameplay validation is claimed for this audit.
