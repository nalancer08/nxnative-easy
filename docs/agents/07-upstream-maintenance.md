# Maintaining this fork against upstream

This is a standing repository-owner instruction for every future upstream update.
The owner requested that code updates reach our main and that accepted new games
appear everywhere without being forgotten. No recurring schedule is implied.

## Preserve the working fork

1. Inspect status, current revision and remotes first. Preserve user edits. Fetch
   `seedds/nxnative` main and freeze its SHA. Record reviewed versus integrated
   revisions separately in `docs/upstream-sync.json`. Use the previous integrated
   head as the next comparison base; a reviewed head is not an integrated head.
2. Prepare a detached candidate using `scripts/sync_upstream.py --merge-main
   --output <new-external-folder>`. Selected cherry-picks remain available through
   `--stage`. Never reset our main to upstream or replace it with their README.
   Conflicts stay in the candidate until deliberately resolved.
3. Retain English/Spanish UI and documentation, automatic app updates, Mac/iPhone
   target selection, controller detection/test, shared touch editor and its four named per-game profiles, live build
   progress/persistent logs and optional original-code REA analysis, the native
   ARM64 signing/install helper and explicit personal-team selection, explicit
   external key selection, unsigned/lightweight iOS output and complete Mac apps.
   Keep personal commit attribution, original upstream authors and licensing.
   Preserve the personal folder library, both-platform output discovery and
   metadata-only removal. Keep one shared preparation model alive while browsing.
   Use structured build events for stages/counts/ETA; never guess overall progress
   or runtime state from diagnostic log wording. Retain history on log-tail replay.
   Follow the optional launcher-metadata contract; keep game settings delegated to
   the built app unless implementing that contract explicitly.
   Preserve the isideload exact-identifier patch, signed/profile identity checks,
   Keychain session storage, redacted stdio and RomFS-only transfer capability.
   Preserve UDID deduplication (USB preferred), device metadata/search/update
   selection, separate connected/registered inventories and logs without raw
   credential/provider payloads. Full/light packaging must retain the bundled
   RomFS priority flag and legacy-record rebuild gate; never delete external
   content or saves to switch modes. Show actual registration results, not an
   invented remaining free-account quota. Devices remains an in-window page.
   Device game discovery requires local preparation IDs/exact install records;
   no unrestricted app Lookup, display-name matching or broad inventory fallback.
   Legacy discovery may read only the minimal identifier index before targeted
   game metadata queries. Keep helper capability checks and client-side filtering.
   Never add automatic certificate revocation, account/team changes, save-folder
   writes or password logging. Helper tests use synthetic credentials and no device;
   compilation never counts as successful Apple login or physical installation.
   Preserve read-only committed-save export as a separate capability from
   RomFS transfer: no restore, save-folder writes or silent metadata loss.
   Keep duplicate hash/inventory checks, new-backup-only publication and alias
   refusal. Source/installed game versions must agree for app-only renewal and
   standalone content copy; version equality does not prove asset equality.
   Keep local saves and control preferences separate from the optional save API;
   cloud login/export/restore must not be advertised until native integration and
   recovery are configured and device-tested. Never package a private save database.
   Preserve saves, bundle identities and working game packages. Never sign with
   an Apple account or ship games/keys. Do not carry unrelated open PRs into a
   main merge without their own review and dependencies.

## Every accepted game, everywhere

4. Compare profile directories and versions, not only README names. For every
   added/changed profile, retain its build IDs, SDK, shader tables, engine fixes,
   game note and `dm/games/README.md` row together. A profile alone may depend on
   renderer/service/translator changes. Removed profiles must disappear from
   generated inventories too. Never announce a game merely because it is in an
   unmerged PR or builds successfully.
5. Import existing upstream screenshots, then run:

   ```sh
   python3 scripts/sync_game_catalog.py --write --upstream-ref PINNED_SHA
   python3 scripts/sync_game_catalog.py --check
   ```

   This generates `game-artwork.json`, `game-catalog.json` and the marked galleries
   in README.md/README-es.md from the installed profiles. The desktop carousel,
   View all, search and notes already discover live profiles; ensure all mapped
   images exist. Missing/ambiguous images stop the release; resolve the mapping
   using the title ID, never substitute a different game's art or silently hide it.
   Do not hand-edit generated galleries or hard-code a profile count in Swift.
   Refresh app screenshots when visible labels or counts change.
   Keep compatibility evidence attributed: upstream Mac testing does not prove
   iPhone gameplay, and a build does not prove online support. State limitations
   in game notes; all users still supply their own game files and keys.

## Validate, integrate and release

6. Run the catalog check, documentation tests, fork tests and affected upstream
   tests. Compile the Mac host and unsigned iOS app when runtime/input changes.
   Run host/GPU regressions for graphics/service changes. If the shader chain
   changes, regenerate its header, check the locked translator and rebuild a
   representative game's Mac/iOS shaders in separate output folders, then its
   host. Keep shader/header/translator/profile inputs coherent; do not reuse old
   libraries under a new chain. Preserve existing working game caches/packages.
   Test game/device behavior where available; document untested platforms or
   modes honestly. Failed checks stop integration/publication until resolved.
7. Integrate the reviewed candidate into our main, update `integrated_head` and
   review evidence, and bump `desktop/release.json` for changed functionality or
   accepted games so the in-app updater offers it. Verify checkout cleanliness,
   build/ad-hoc signature, commit/push and remote synchronization when publication
   is authorized. Explain what was integrated, what remains pending and whether
   users must prepare their existing game again. A documentation-only commit
   needs no release bump. Update this guide if the maintenance procedure changes.

The CI catalog gate prevents incomplete game lists from silently shipping.
The tools stage and check updates; they do not auto-approve unreviewed engine
changes, erase conflicts, install on devices or overwrite a user's game files.
