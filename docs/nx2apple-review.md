# NX2Apple integration review

Reviewed on 2026-10-27 against
[LNPANDY/NX2Apple at 7ae7ba65cb077f51ed8a153907bc4b2af0712621](https://github.com/LNPANDY/NX2Apple/tree/7ae7ba65cb077f51ed8a153907bc4b2af0712621).
This is a pinned reference review, not an engine merge. It supersedes the earlier
three-file frontend survey for feature planning. Reference files remain outside
our checkout. No third-party source, fonts or new art assets were imported.

## Scope and evidence

The review inventoried the complete checkout and examined the native launcher's
state, collection, build process, settings, device routes, save transfer and
self-update boundaries, their test cases, the Qt/Windows architecture, and the
fork-specific archive integration points. The native frontend has 24 Swift source
files and 15 Swift test files with 129 named test methods at this revision.
This is a static architecture/integration review; it is not a line-by-line
correctness audit of every engine file and does not establish that their tests,
Windows cross-build, physical installation or save restoration work here.
No foreign setup/build/install scripts or device operations were executed.

The existing upstream frontend contract remains the integration boundary:
[frontends.md](https://github.com/seedds/nxnative/blob/ceaf6d6ee21bdfb986e9b6f97cbb1a7ce539991d/docs/frontends.md).
Follow structured build events and metadata provided by the built game. Missing
runtime APIs must not be replaced with guessed state from textual diagnostics.

## Native modules and decisions

Paths below are under `frontend/Sources/NSPortBuilder/` in the pinned reference.

| Source area | What is useful | Decision for this fork |
|---|---|---|
| `LauncherView.swift`, `LauncherStyles.swift` | A persistent collection, selected game, build activity across navigation | Implemented an original list/detail collection with existing artwork; keep our sidebar and shared preparation model. No copied layout, palette or fonts. |
| `Library.swift` | Records source inputs, both-platform outputs, tool revision, launch choices and installed device; validates Mac bundles; bounded discovery | Retain our private schema and explicit folder ownership. Both-platform actions are now visible in detail. A future explicit import can discover completed Mac apps without scanning unrelated drives. |
| `ContentView.swift` | Build orchestration, dependency setup, process groups, structured progress, stdout/stderr, separate source/app updates | Keep our existing JSON timeline, retained logs, process-group cancellation and session-leader fix. Do not import its orchestration wholesale. |
| `LaunchOptionsView.swift`, settings portion of `Library.swift` | Reads `dm/launcher.json`, validates saved values, groups basic/advanced settings, render-size context | Good future feature after implementing the upstream metadata/environment contract. Keep the built game's own launcher authoritative for now; do not duplicate unsupported options. |
| Mod portion of `Library.swift` | RomFS overlays, ordered precedence, marks code-only mods unusable | Candidate for a separate feature with host-support detection, exact TitleID and launch-environment tests. It is not arbitrary source/DLC editing and is not enabled by this release. |
| `OlderTools.swift` | Records build commit; compares relevant shared/profile files; ignores notes/tests | Highest-priority follow-up: explain when rebuilding can help. Record provenance per successful platform build; unknown/shallow history means unknown, not current. Do not force a rebuild for every frontend/docs commit. |
| `KeyCheck.swift` | Checks selected NSP/NSZ NCA headers before a long build; distinguishes old/missing keys from unchecked inputs | Useful follow-up with bounded file reads and synthetic crypto vectors. XCI is explicitly unchecked there. Never bundle, display or log key values. Prefer reusing extraction knowledge over maintaining conflicting parsers. |
| `DropFiles.swift` | Drag/drop folders, base game, update, DLC and keys into preparation | Useful follow-up. Our folder pipeline must validate title relationships before accepting ambiguous filenames; keep explicit external key selection. |
| `BuildNotifications.swift` | Background success/failure notice; click routes to game or build log; suppress cancellation noise | Useful follow-up with opt-in permission at first build and no notification while foregrounded. Not implemented in 1.12.0. |
| `Diagnostics.swift` | App/chip/version/tool/dependency report; last command/log tail; home/key-value redaction | Useful follow-up. Our signing logs require stricter credential/token/account redaction too; never include environment dumps, key bytes or raw provider replies. |
| `FreeSpace.swift` | Surveys disposable build parts off-thread; protects outputs/inputs; refuses active build | Useful follow-up, not an automatic cleanup port. Must protect our source/tools, external RomFS and saves as well as IPA/app. Re-resolve containment and symlinks at deletion time; calculate recoverable bytes separately from protected content. |
| `Devices.swift` | Reads paired devices with devicectl; derives signing teams from certificate OU | A different route: it depends on existing Xcode development identities. Keep our deduplicated device helper, explicit account/team choice and restricted own-game discovery. It does not provide a drop-in Sideloadly login/renewal replacement. |
| `SaveTransfer.swift` | Reads committed save/save_device, compares dates, stages incoming Mac data and backs up replacements | Do not port its write/restore flow yet. It uses `Documents/games/<TitleID>/save`; our working app uses `Documents/save`. Retain our read-only ZIP, stability/hashes and alias refusal. A newer timestamp alone does not resolve a save conflict. |
| `Gamepad.swift`, `PadFocus.swift` | Launcher navigation with controller focus; only acts while app active | Good optional living-room mode later. Our controller test already owns GameController handlers; integrate one input dispatcher first so navigation cannot steal test/game events. |
| `Controls.swift`, `ControlPresets.swift` | Per-launch input environment, standard/by-label/custom/automatic layouts | Review mapping semantics against our current runtime before adding presets. Keep our four touch profiles and controller test. Avoid silently changing a working Xbox/PS mapping. |
| `AppUpdate.swift`, `UpdateSheet.swift` | Release digest/version/identity validation, staging, deferred swap, changelog | Keep our checked updater and source preservation. Binary-release staging is a worthwhile future distribution improvement, independent of engine merges. Do not auto-pull foreign main into our fork. |
| `Localization.swift`, `Typography.swift`, `EmbeddedFonts.swift`, `NSPortBuilderApp.swift`, package/icon resources | Presentation, language and app bootstrap | Keep English/Spanish, original icon and system fonts. No additional font/visual dependency needed. |

## Core, transfer and cross-platform boundaries

- The reference has `dm/host/romfs_arc.*` and `dm/tools/romfs_arc.py` for an index
  plus shards, alongside one-image and directory routes. Its iOS shell recognizes
  per-game `Documents/games/<TitleID>/` data and derives saves from that layout.
  These require coherent host, packer and app-shell changes; they are not a UI
  feature or a safe path substitution. A future proposal needs byte-for-byte
  archive verification, interrupted-transfer tests, preserved save paths and a
  deliberately reversible migration. Our current directory RomFS stays intact.
- `scripts/push_romfs.sh` uses devicectl and a single image. Our existing helper
  uses a staged directory transfer with a recovery journal. A shorter script is
  not grounds to drop recovery/version checks or touch the working phone game.
- The Swift `makeVenv` implementation drains stdout and then stderr separately.
  A child producing enough stderr before stdout EOF can block both processes.
  This is a static risk, not a reproduced failure. Keep our concurrent/combined
  output handling rather than copying that helper as written.
- Qt's `model.py`, `ui.py`, platform utilities, localization and tests cover a
  separate PySide interface. `win/driver.py` loads the pipeline with replacements
  for Apple-only tools; toolchain, SDK fetch, doctor, shims, app builder, IPA modes
  and compatibility C/Objective-C are an independent cross-toolchain project.
  Its own Qt README leaves genuine Windows compilation/link/Metal/IPA validation
  open. Do not advertise Windows build support from a source inspection.
- Runtime, shader and profile changes must continue through our pinned-upstream
  maintenance process. Do not merge this fork's complete `dm/` or profile list
  merely to obtain its launcher. A frontend feature does not prove new game,
  device, network or engine compatibility.

## Licensing

The reference root is MIT and retains the original jhaizhou attribution plus
LNPANDY's archive-subsystem notice. If source is adopted later, preserve the
applicable notice and attribution with the imported code. This release uses an
original SwiftUI implementation and existing fork assets; linking a reference
is not a substitute for license compliance on any future copied code.

## Delivered now and next candidates

1. **Delivered in 1.12.0:** Apple Account is an application page in the persistent
   sidebar, independent of devices; collection list/detail, artwork, both platform
   actions, search and non-destructive library management; current bilingual
   screenshots. Existing build activity and save/content boundaries remain.
2. **Next useful independent changes:** build provenance/rebuild advice,
   diagnostic export, background completion notices and validated drag/drop.
3. **Needs deeper contract/device work:** launch settings/mods, transactional save
   restoration, archive migration and binary release distribution. These are
   evaluated candidates, not features advertised as implemented.

Validation for our delivered change: compiled Foundation library/localization/
sideload-client fixtures, full SwiftUI compilation and ad-hoc bundle verification,
and synthetic English/Spanish visual checks. The screenshots contain example
metadata, no real accounts or game/save payloads. No login, signing, install,
restore or game-content copy was performed. Existing native-signing validation
limits remain unchanged.

## Follow-through in 1.13.0

The independent implementation now includes per-platform rebuild advice from
recorded source revisions, redacted diagnostics, permission-based background
completion notifications, non-copying workspace drops, a guided preparation/
installation flow and scoped cached device presence. These follow the integration
boundaries above; no reference source or runtime/archive/save-write changes were
imported. See [the player flow](frontend-library.md#guided-preparation-and-verified-device-state-1130).
