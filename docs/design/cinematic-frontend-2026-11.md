# Cinematic desktop frontend, 1.25

## Task and direction

The personal library needs to feel like a game launcher, with useful actions and
installation evidence at the centre of the experience. The previous frontend
retained an administrative grid/card hierarchy after removing its sidebars. This
revision changes the composition across the desktop workspace while preserving
its build, signing, identity, save and controller models.

The library opens on a full-width selected-game stage. Covers form a compact
shelf; selecting one changes the artwork, title, state and available actions.
Play is offered only for a discoverable Mac app. An iOS action opens the existing
installation review, never a fictitious remote-play session. Details separate
Where to play, Files & options, and Saves. There are no made-up play hours,
achievements, game downloads, online services or cloud-synchronization states.

The desktop palette is midnight navy, ice cyan and restrained violet, paired
with default SF Pro display text and monospaced section labels. Edges, type scale,
fields, disabled buttons and step rails share the updated design system. The
native title bar is hidden; navigation leaves room for the Mac window controls.
Preparation has destination cards and an original device illustration. Build
artwork uses the actual current-stage fraction, labelled accordingly; unknown
progress shows a CPU/dashed ring, without an invented percentage. Settings uses
workspace tabs, and Apple Account uses an illustration/introduction beside the
existing form. Devices prioritizes real discovery and scoped installed games.
Compatibility uses an artwork grid of profiles, distinct from the owned library.

## References and actual evidence

| Source | Examined | Applied |
| --- | --- | --- |
| [Foundation Lab, Game Launcher](https://www.behance.net/gallery/234134061/Game-Launcher-UIUX-Design) | Original page, project text and desktop screen image viewed in the browser. | Full-width game backdrop, action hierarchy and a compact shelf; no fictional social or download panels. |
| [Behzad Pashaei / Zeinab Ameri, Oniex launcher](https://dribbble.com/shots/20436904-Game-launcher-App-Design) | Original desktop concept image and author credits viewed. | Layering and artwork-led focus; no imported avatars, trading information or artwork. |
| [Darshan Shah, Game Launcher](https://dribbble.com/shots/17727529-Game-Launcher-UI-Design) | Original mobile launcher image viewed. | Distinct subject/illustration over a dark surface, rather than boxed statistics. This is not a desktop layout reference. |
| [Oniex on X](https://x.com/OniexAgency/status/1547871453122482178) | Public profile/posts viewed; logo GIF played and a wordmark pose observed. No claim to a complete frame-by-frame analysis. | Restrained brand presentation. No logo/animation asset copied. |
| [Juxtopposed's Steam redesign video](https://www.youtube.com/watch?v=cDY2p1CTkPo) | Library keyframes around 11:32, 12:32 and 12:52 examined during the immediately preceding library review. Not re-watched in full. | Search in context, a coherent selected-game action and fewer competing navigation regions. |
| [Valve's library introduction](https://store.steampowered.com/libraryupdate?l=english) | Primary text examined. | Collection/shelf vocabulary; no adoption of Steam-only services. |

The [earlier research record](library-2026-11.md) remains available. Those concepts
were references, not downloaded UI assets. Game artwork continues to use the
repository's catalog mapping and the player's own library entries.

## Original resources and movement

`desktop/NxNativeEasy/Assets/Library/play-destinations.png` was generated with the
built-in image tool, copied into the repository and resized to 960 pixels wide
with alpha preserved. Prompt:

> Original premium 3D cutout illustration for a desktop app's Choose where to play
> screen. Refined graphite desktop display on a thin pedestal at rear left, and
> landscape smartphone at front right with original lime/turquoise grip sides,
> linked by a slim ice-cyan ribbon. Blank screens show an abstract cyan/violet
> portal gradient. Smoked-glass and satin graphite, studio lighting, midnight navy,
> #75EBF5 cyan and #8F78FF violet. Real transparent background, generous margins,
> wide 3:2 framing, elevated three-quarter perspective, recognizable at 260 pixels.
> No text, logos, game/franchise imagery, numbers, labels or interface controls.

The existing original archive illustration remains in the empty collection and
Add game tile. Its [prompt/provenance](library-2026-11.md#original-artwork) is retained.
Both resources are decoration surrounding real native controls, not bitmap forms.

The original six-layer `drop-game.json` remains a real bundled Lottie composition,
with this release's cyan palette and local background. Its pinned MIT runtime,
nonpersistent local-only player, background pause, teardown and meaningful static
frame 60 remain unchanged. No new GUI probe executable is shipped or restarted.
Selecting a game uses a native 0.28-second artwork crossfade; shelf hover uses a
2-point lift. Reduced motion disables these transitions. The stage meter follows
actual fractions with a short native interpolation; animation never completes a
build, confirms an installation or decides which save to use.

## Review contract

Render English/Spanish collections, minimum 1000 × 640, long names, empty/filter
results, preparation, account, devices, progress and compatibility. Test cover
selection separately from actions, preserve query/filter when returning from
details, retain device proof separately from local outputs, and keep the live
preparation view mounted while navigating. Synthetic visual fixtures are not
proof of gameplay, signing, cloud delivery or installation.

Source/domain regressions and final release identity are recorded in the PR.
No user game files, keys or saves are used for frontend verification. Runtime
performance/FPS and a physical iCloud round trip are not established by screenshots.

## Verification recorded for 1.25

Native SwiftUI views were rendered in both languages for the collection,
preparation, stage progress, account, devices, compatibility and detail screens.
The collection was also reviewed at the 1000 × 640 minimum, with empty/filter
results and long names. README and website screenshots use synthetic library
state, not claims of installation on the owner's devices. The progress fixture
uses 420/1000 shader counters and a reported stage estimate; it does not invent
a whole-build completion time.

Twenty desktop checks passed, including catalog discovery, controller input,
localization, updater and drag/drop/source-file preservation. The isolated
sideload client and launch-options checks passed. The portable app must still
pass release identity, source hashes, signature and updater compatibility gates
before publication. No user game, save, key, installation or Apple login was
modified during these checks.

The catalog gate verified all 130 profiles and both galleries, the documentation
suite passed 11 checks, and Astro built and checked both public-language routes.
This frontend release does not change the host or save format. Its portable
package must contain `play-destinations.png`, the local Lottie runtime and embedded
animation data; publishing a preview executable is not a substitute.
