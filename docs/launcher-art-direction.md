# Launcher art direction — 1.30

## Brief

A native Mac launcher for a personal collection, usable without understanding
build tools, signing internals or save storage. The first interaction is selecting
a game from the left list. Its page answers where it is playable, what its next
action is, and what progress has arrived. Files, installation identity and save
recovery checks remain unchanged. Cloud-only titles belong in the same list.

## Research and decisions

| Original source | Evidence inspected | Decision |
| --- | --- | --- |
| [Dina Rafikova — Steam redesign](https://dribbble.com/shots/26698011-Steam-redesign) | Original Dribbble image in browser: Ori hero, narrow navigation, prominent action. | Use an immersive gameplay stage and one dominant action; retain the requested game list rather than its icon rail. |
| [Alessandra R. — Redesign Steam](https://www.behance.net/gallery/153349953/Redesign-Steam) | Original long case study, including problem analysis and “Página do jogo” panel: large banner, real screenshot thumbnails and adjacent action. | Prioritize the current game and real media. Do not imitate the storefront, prices, social feed or purchasing features. |
| [Juxtopposed — Steam redesign video](https://www.youtube.com/watch?v=cDY2p1CTkPo&t=688s) | Muted video frames around 11:47 and 12:27: search, dense left game list and the existing Steam cover grid. Video description identifies Library at 11:28. | Preserve stable selection and readable compact rows. The requested selected-game detail replaces the grid as the default. These observations do not claim inspection of the entire video. |
| [Juxtopposed on X](https://x.com/juxtopposed/status/2109643946628722983) | Public post announcing a VLC redesign was readable. Opening its media required sign-in. | Text-only discovery; no visual or motion claim is based on inaccessible media. |

The UX skill's local search covered desktop launchers, persistent navigation,
master/detail interaction, hit targets and back state. Its generic horizontal
journey recommendation did not fit the user's requested game list and was not
adopted. The installed search tool did not support a SwiftUI stack query;
implementation review and native interaction checks supply that evidence instead.

The resulting direction uses graphite, ivory and warm orange, with original
sculptural branding. It does not use Steam/Nintendo logos, third-party UI assets,
store chrome or a handset surrounded by console controls.

## Original generated assets

Builtin image generation produced two raster assets, inspected before use:

- `desktop/NxNativeEasy/Assets/Launcher/app-icon-3d.png`: generated icon master.
  `Assets/draw_icon.swift` exports its Dock sizes. The portable builder uses the
  same master for the in-app brand, so there is no separate stale vector icon.
- `desktop/NxNativeEasy/Assets/Library/portal-3d.png`: transparent 1536×1024 portal
  and save crystal, used in the welcome/destination scene.

Icon prompt:

> Create a premium macOS application icon for nxnative Easy, a powerful native
> game launcher. Brand new direction, absolutely no game controllers, phones,
> console, device collage, typography, letters printed on top, Nintendo or Steam
> logo. Square 1024 composition. A single sculptural three-dimensional ribbon
> forms an abstract angular lowercase n / impossible doorway, with a triangular
> play-shaped negative-space aperture integrated. Warm luminous tangerine-orange
> enamel face, dark graphite thickness, ivory highlights, studio light. Sculpture
> fills 88%, recognizable at 32px. Full-bleed near-black rounded-square tile, not
> an icon inside another icon. Industrial clean bevels; no sparkles or neon
> particles; front three-quarter minimal perspective.

Scene prompt:

> Single original 3D sculptural empty-library asset for a premium desktop game
> launcher. No UI, words, logos, devices, controllers or phones. Floating
> architectural folded orange enamel and charcoal portal shaping an angular n /
> doorway with triangular aperture, ivory translucent save crystal inside.
> Tactile bevels and controlled warm light, industrial render, three-quarter
> centered complete silhouette, wide 3:2, real transparency, no floor, background
> or caption; designed for a gentle float beside native text.

The generated archive identifiers are
`exec-3f577e9b-e4b8-4e61-8659-d3fb6b76c2a9` and
`exec-066f9fe1-bff8-4b26-8a30-a900d87c7d19`. Repository copies are the durable
sources; the user's machine-specific generator archive is not a build dependency.

## Motion contract

`dm/tools/launcher_motion.py` authors `launcher-open.json`. It contains the
original raster sculpture as one embedded layer plus three original vector orbit
lights and seven animated properties. This is a real Lottie composition, rendered
by the already pinned local lottie-web 5.13.0 runtime, not a video/GIF or remote
asset. Eight seconds form a closed gentle float. It starts on the empty welcome
or preparation destination scene, pauses inactive, and uses resting frame 60
for reduced motion. `LauncherPortal` unmounts its web player when preparation
is hidden, without unmounting the compilation workflow. It never announces a completed save/build/installation.

Native selection uses a 180ms opacity transition, disabled by Reduce Motion.
The connection acknowledgement is short and textual after actual discovery;
it does not instantiate an animated phone in every game or stay on screen.

Preflight accepted the composition. Its embedded raster produces a 2.4MB JSON;
only one scene is mounted and no animation is created per game row. JSON validity
alone is not playback or performance evidence. See the PR validation record for
rendered states, observed playback, limitations and the native build checks.

## iCloud boundary

[Apple directory access](https://developer.apple.com/documentation/uikit/providing-access-to-directories)
requires a system-granted folder permission on iOS. Each separately signed game
keeps that grant in its own bookmark. A free signing account does not silently
provide a shared iCloud container. Mac Easy manages its own folder inside the
existing system iCloud Drive and passes it to prepared Mac games. Existing custom
folders, local saves and branch history are preserved.
