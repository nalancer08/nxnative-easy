# Personal library and structured build activity

## Reviewed references

The owner requested a library inspired by the organization of
[NX2Apple](https://github.com/LNPANDY/NX2Apple/tree/0313148688ec6e7954e4d299d26a9a91d19fe7dc)
and the upstream [frontend contract](https://github.com/seedds/nxnative/blob/ceaf6d6ee21bdfb986e9b6f97cbb1a7ce539991d/docs/frontends.md).
The review covered NX2Apple's Swift library/launcher, progress model, screenshot
and MIT license. The library, navigation and timeline here are our own SwiftUI
implementation: no source, fonts, artwork, layout or visual assets were copied
from that frontend. Cards reuse this fork's existing catalog artwork.
These are reviewed reference revisions, not new integrated engine revisions.
No upstream runtime merge or unsupported game announcement is implied.

The useful separation is a persistent collection, a preparation workspace and
activity visible while browsing. Upstream's JSON stream, not human log wording,
is the interface for stages/counts/ETA. A Mac game is opened as its built app;
its own launcher remains responsible for supported settings and stored choices.
We do not set DM_LAUNCHER=0, synthesize settings for missing launcher metadata or
write another preference store. Game-runtime text logs remain diagnostics rather
than an API for live game/controller state.

## Player flow

1. **Add game** selects one existing game folder. The same preparation form asks
   for Mac or iPhone/iPad and the user's own keys. This is not a downloader.
2. The personal library remembers folders across launches, including the previous
   game folder from an older launcher. It only links paths and small metadata;
   it never moves game inputs, build caches, keys or saves.
3. Each entry resolves its title/art from the local accepted profile catalog when
   possible and shows the outputs actually found: complete Mac app, iOS IPA or
   unprepared/unavailable folder. A prepared IPA means ready for installation,
   not proof that the game is installed or plays on a phone.
4. Selecting a game shows its artwork, actual platform outputs and actions.
   **Play on Mac** opens its existing Mac app. **Install on iPhone / iPad** opens
   our native installer for an existing iOS output. When both outputs exist, both
   actions remain visible. **Prepare or update** returns to the common form and preserves
   existing preparation identities. Native authentication/install validation
   limits in [sideloading](sideloading.md) still apply.
5. Browsing and searching remain available while a build runs; switching the
   active folder, rebuilding, removing entries, signing or updating the launcher
   waits for the current operation. There is one active build, not a hidden queue.
6. **Remove from library** removes only the shortcut after confirmation. Source
   folders, outputs, save data and caches remain. Unavailable external drives or
   deleted outputs stay listed honestly; refreshing/reopening rechecks readiness.

The compatibility catalog is a separate action. An accepted game profile does
not automatically appear as an owned game, and the library supplies no game files.

## Devices navigation

Since 1.10.1, Devices is a page beside Library and Prepare, never a navigation
modal. Its game list uses local preparation IDs and exact installation records;
it does not show other user apps. Legacy discovery uses only the minimal ID
index before querying matched game metadata, as described in
[restricted discovery](sideloading.md#inline-devices-and-restricted-game-discovery-1101).

## Persistence

`~/Library/Application Support/nxnative Easy/library.json` is a schema-1 private
index of item IDs, canonical folder paths and dates. No game bytes, encryption
keys, Apple credentials or cloud-save packages are stored there. Writes are
atomic with a private directory and 0600 file. Symlink aliases deduplicate to
one folder. Invalid/unsupported metadata is preserved and disables overwriting
that index; the app does not silently replace it with an empty library.

Output discovery reads our per-folder `nxnative-mac.json`/`nxnative-ios.json`,
bounded metadata and Mac bundle identity/host/embedded-data presence. It does not recursively
scan drives or open packages from unrelated folders. Both platform outputs can
coexist; a missing output is no longer offered as ready. The library adds no
new game settings or cloud synchronization.

## Build activity

The dock stays visible on the library and preparation pages with the current
game/platform, stage, counters, current-stage fraction and callback ETA. A fraction
is explicitly for the current stage, not a fabricated overall percentage. Unknown
work is indeterminate. Finished/cancelled/failed results stay reachable through
**View activity** until a new build begins.

The preparation timeline uses `stage`, `step`, `progress` and `stage_end` events;
`n` may grow and a new step resets counters/ETA. Only reported completions are
marked done while running. Process exit/cancellation closes the remaining active
stages appropriately. Non-finite/out-of-range fractions and unsafe ETA values are
ignored. Retained log-tail replay merges the known timeline, rather than forgetting
earlier stages. The existing worker still captures stderr, forwards cancellation
to the whole process group and preserves original compiler logs. No new inferred
runtime events or game-log text parsing were added.

## Validation boundary

Foundation fixtures cover private index persistence, folder alias deduplication,
both platform outputs, missing output/folder handling, metadata-only removal and
malformed-index preservation. Structured progress fixtures cover growing totals,
actual ETA, resets, retained history, invalid values and failed/cancelled exit.
Offscreen visual checks use synthetic folder/output metadata and existing artwork;
they do not build, install or play a game. Production compilation/signature checks
validate the launcher bundle, not Apple login or game/device compatibility.

## Collection detail and application account (1.12.0)

The library uses a searchable game list and selected-game detail: large existing
artwork, platform readiness and play/install/update actions. Search selection
falls back to the first matching result; unavailable folders remain listed.
An iOS output is described as prepared, not as installed or tested on a phone.
No input paths or save locations migrate in this presentation change.

Apple Account is an application-level destination in the persistent sidebar,
reachable from Library, Prepare and Devices. It shows the authenticated email
or an explicit signed-out state. The account page is inline and contains no
device picker or installation action. Device installation still uses the shared
session and retains each app's account/team/device identity. Devices contains
no account card and explicitly explains that save export and RomFS copy require
connection/trust, not Apple sign-in. Account changes are disabled while the
helper is busy. This does not change login persistence or sign-in validation.

See the [expanded NX2Apple review](nx2apple-review.md) for the pinned source
inventory, useful features, integration decisions and validation limits.
