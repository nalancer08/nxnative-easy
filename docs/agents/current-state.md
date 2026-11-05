# Maintainer handoff — 2026-11-05

Read this file when resuming, then check Git status and public release metadata. It is a compact record, not evidence that pending work has shipped.

## Product and owner intent

nxnative Easy is a Steam-like personal launcher, with a game list on the left and the selected game's detail on the right. Add an owned game, choose Mac or iPhone/iPad, prepare, install/play. No games or keys are included or downloaded. The compatible-games catalog is an in-window page, distinct from the owned library. Avoid separate administrative Devices/Save tabs: device presence, installation/renewal, save history and manual export belong inside each game.

Saves are central. The owner wants automatic iCloud continuity across Mac/iPhone/iPad, immutable history and both copies retained on conflict. Adding a game without saves also creates a library entry; cloud saves can identify a game whose files are not present yet. iCloud uses the device's system account and is separate from the Apple account used to sign apps. Drive APIs do not expose the owner's Apple email/photo: never invent identity from the local Mac profile. Stock/unmodified Switch consoles cannot import/export arbitrary SD saves; do not promise otherwise.

Preserve originals, RomFS, working signed apps, lightweight unsigned IPAs, code, keys and progress. Never uninstall an existing game to update it. Keep bundle/team identity, backup-first recovery gates, explicit device registration and signing consent. Agent tests never sign/install on owner devices. Copy game content means RomFS, not save backup. Local/manual export works without signing login.

## Shipped milestones and evidence

- Easy 1.31.6/build 57, main/tag/source c20bf0e05bdd7cbb462186793a3a6538e540b825; release PR #27 merged. Canonical app: ~/Applications/nxnative Easy.app.
- Engine display version 1.0.1; dotted versions are required, not hashes or Motor 1/2. Engine integration was still 4a2a81a64f029d0a75ade9523c8ffc6c89465375 (2026-11-02). A reviewed/draft upstream proposal is not integrated code.
- The owner reported successful Zelda and Metroid gameplay on Mac/iPhone earlier. Do not turn that into fresh physical validation of later code.
- Custom iCloud runtime: docs/icloud-saves.md; append-only revisions, parent/conflict checks, two-folder recovery, backups and pre-play gates. Synthetic tests and unsigned builds do not establish a real iCloud round trip. Already installed games need runtime recompilation for new sync hooks; updating Easy alone cannot add them.
- Four named touch profiles, controller detection/testing, scoped connected-device inventory, account/session persistence, native ARM64 installer, optional full/light iOS output, complete Mac apps, structured build progress/logs and portable self-updates exist. See maintenance guide for exact invariants.
- 1.31.6 changed layout only: single native unifiedCompact toolbar; navigation left, engine/Add/profile right; conditional Back; shorter game hero; action/version/reason grouped; manual backup/import in Manage saves; compact device rows; real hover/pressed states. All desktop Swift compiled; interaction/local-save/docs tests passed; eight applicable CI jobs passed. Current, installed 1.31.5 and legacy 1.20 updaters staged the actual portable ZIP. Owner library/install metadata hashes matched across bundle replacement.

## Errors and lessons to preserve

- Fixing contrast/hit regions did not fix layout. The owner correctly rejected the oversized second header, duplicated actions and wasted vertical space. Judge the actual running app; compilation is not visual QA. Styles remain open for later owner review.
- Full button padding must be interactive (contentShape plus activation-click policy). Avoid hit-test overlays and text-only targets. Secondary states must actually change fill on hover/press; test contrast on hover too. Respect Reduce Motion.
- Use docs/design-system.md and shared DesignSystem.swift. Native toolbar controls are 32pt, secondary desktop controls 36pt, primary 40pt; fields may be 44pt. Do not restore tablet-sized toolbar spacing, stacked titlebar/header, or pill plus underline selection.
- SwiftUI native toolbar: ToolbarSpacer(.flexible, placement:.primaryAction) is required to align the trailing group. Label.titleAndIcon plus lineLimit(1)/fixedSize keeps engine/Add readable after asynchronous version loading. Keep navigation buttons direct ToolbarItemGroup children: nesting them in an HStack caused duplicate accessibility labels.
- Button-backed native Menu uses EasyMenuStyle. Avoid a custom chevron alongside a native menu indicator; it produced duplicate AX menu buttons. Native menus can be visibly open while CUA reports no AX diff.
- An isolated QA app under Documents hung reading its synthetic catalog at startup. A process sample identified open/contentsOfDirectory blocking, not a product animation loop. Moving only synthetic fixtures/public metadata to an agent cache restored QA. Do not grant privacy permissions or modify production code to hide that fixture issue.
- Never run verify-motion again: earlier probes crashed repeatedly and opened system crash reports. Use noncrashing checks and isolated synthetic fixtures.
- Native desktop compilation needs every shared dependency in Swift test harnesses (DesignSystem.swift was once omitted from the local-save check and fixed).
- Keep legacy updater metadata under 128KiB: finish releases with a small notes commit; /commits/vTAG for 1.31.6 was 5,081 bytes. Freeze one source revision/package; verify archive/source hashes, ad-hoc signature, old-updater staging and public download digest. Draft release creation does not create its tag; push an explicit full-SHA tag. GitHub ZIP uploads around 475MB took about 19 minutes.
- Portable bundles are ~1.35GB unpacked. Clean only agent-owned staging after public verification; retain canonical app/rollback and source caches needed by user builds. Last release removed ~4.66GB of staging, not games.
- Eight applicable CI checks ran for the Swift-only 1.31.6 change. Python lint is path-filtered; local ratchet had zero new findings. Do not wait for a nonexistent ninth job, or claim skipped checks ran.

## Current authorized work

Owner explicitly requested: preserve this condensed knowledge; resolve all open fork PRs/issues and publish; integrate all new original-main commits without losing Easy; recheck Mario Kart World against supplied files. Styling is postponed.

Initial inventory: fork open PRs #7/#14/#20/#26 are successive automatic upstream proposals with no engine changes staged because merge conflicts remained. Issue #19 reports an Apple SMS loop fixed locally by consistent Mac GrandSlam client identity; shipped vendored source still needs review. Do not close reports merely to empty the queue.

Latest original frozen at 865cc35fad7034d17c2190f8ce349f61f5bcaba1. Integration candidate is isolated at ../upstream-review-20261105/candidate, based on c20bf0e0, currently with deliberate merge conflicts. Main remains the shipped baseline until validation. Report and logs sit in ../upstream-review-20261105 and ../maintenance-20261105.

Mario Kart World's earlier 2026-11-03 pending assessment is stale: current original main contains profile 0400C3F00006E000 for base v0, main build 9e244438c3d8ef1c703a6a85ef99c4f0, matching the previously inspected owner's base dump. Original reports Mac races, iOS untested; 1.8.0 is derived, not tested there. Import complete shader/host/tool dependencies, not a profile alone. Owner input path is ~/Downloads/Mario Kart World NS2 + Emulator; use game dump only, never execute adjacent Windows emulator/DLLs. Verify present bytes and exact modules again before build claims.

Update this section with integrated revision, release, tests, unresolved facts and file paths before pausing. Read docs/agents/07-upstream-maintenance.md for required merge, catalog, regression and release gates.


## Integration checkpoint (not released yet)

Candidate now resolves the initial merge conflicts and includes all 193 original commits at the frozen head. Catalog generation passes with 143 application entries plus two internal All-Stars program profiles. The older Mario Kart World pending-proposal entry was removed. Read-only inspection recognizes the owner's base v0 as ready. All 11,561 Mac shaders translated and the Mac host/pipeline archive compiled; app signature/boot checks remain.

Preserved custom cloud/transfer code instead of resurrecting upstream save_sync. Integrated new iOS layout/menu while retaining editable controls/four profiles, full-bundle RomFS priority and no external deletion. Added one parent application save-compat identity covering every All-Stars program on both platforms. Default build cleanup remains opt-in, including new work-folder archival. Added read-only NUP identification/Mac input without keys, stale/mixed/corrupt refusal; UI Mac-only guard stays for keyless inputs.

Issue #19 fix is provider-scoped: legacy Mac 10.12.6 client identities normalize once to the existing Mac URL-bag identity for all GrandSlam/SMS requests; modern/other providers stay unchanged. Two dependency tests pass without Apple requests, and the CI helper job now runs them. Use the cached Rust 1.99.1 toolchain under ../../sideload-integration-20261027/build-cache, not system Cargo 1.84 (edition2024 unsupported).

Validation so far: unsigned production iOS project compiled/linked after restoring the new in-game-menu bridging-header setting; host unit tests and full GPU make run passed. Native cloud suite passed 23 cases. Isolated upstream Python sweep ran 101 modules: old automatic-cleanup expectations and a UTC Z/+00 fixture failed initially; fixes are under focused recheck. Nso-match test typing narrowed; lint baseline shrank from 387 to 384 with zero new findings. Isolated fork sweep ran 35 modules; the new eager pack_nup import broke importlib-only metadata tests, now changed to a lazy import and under recheck. The earlier one-process fork run did not retain a trustworthy final report; use per-module results under ../../maintenance-20261105/checks-scripts-tests.

Still required: finish input/cleanup test fixes; regression-check existing Dread/Zelda shaders/runtime from copied saves; boot/race-test Mario Kart World with a new scratch save; generated engine history/version and release bump; review/record integration metadata; fold the bot proposal commit into the reviewed branch, update PR #26 without force-pushing; close superseded #7/#14/#20 only after integration; finish CI, portable/old-updater checks and publish. Keep final legacy updater commit small. Main/canonical remain shipped 1.31.6 until the reviewed release.
