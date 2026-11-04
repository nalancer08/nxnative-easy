# Brand and welcome revision, November 2026

The brief is a recognizable small launcher mark and an expressive welcome without
miniature hardware details or an empty device diagram. The N is a single flat
silhouette derived from nxnative's name. It occupies 24 points in the header, with
a single-baseline wordmark. Only the Dock version has a dark rounded tile.

## Research inspected

- [Graphéine, JVFR on Behance](https://www.behance.net/gallery/134971241/JVFR-Brand-identity):
  the original project was opened in the browser and its first artwork inspected.
  Bold geometric lettering contains gameplay imagery against a single red field.
  Adopt the separation between compact brand geometry and rich game art; do not
  copy the mark or its characters. The [studio case study](https://grapheine.com/en/portfolio/identity-logo-video-gaming/)
  supports the geometric identity rationale.
- [Khabib Khandakar, minimal play mark on Dribbble](https://dribbble.com/shots/26417575-Minimal-Gradient-Play-Icon-Logo-Abstract-Tech-Media-Logo):
  the original full symbol was inspected by scrolling the browser. Its large
  silhouette and open negative space remain legible without miniature details.
  Our mark is an independent flat N; the third-party symbol is not included.
- [Juxtopposed on X](https://x.com/juxtopposed/status/2113725633054351767):
  the author's public profile text criticizes hiding useful controls in menus.
  Keep setup actions visible, with no decorative interaction blocking them.
  The linked VLC redesign post was found, but opening its media required login;
  no claim is made about inspecting that demo.
- [sheikh sohel, Minimal Logo Animation workflow](https://www.youtube.com/watch?v=SfTPlAoaGZo):
  native browser playback exposed the intro poses at 00:00 and 00:05: sparse
  strokes assemble into a stable mark. Adopt arrival followed by rest rather
  than a perpetual illustrative loop. Only this short fragment was inspected.
- New Level Up and Spaceplay Behance projects were found in search; direct page
  requests returned 403. Their images were not used as visual evidence.

## Original assets and reproduction

`desktop/NxNativeEasy/Assets/Launcher/brand-mark.svg` is the editable mark.
`Assets/draw_icon.swift` reads its polygon and exports transparent header art and
all Dock sizes, without image generation, bevels or tiny physical details.

The built-in image generator produced the original adventure world. Prompt:
wide original game-world artwork, an anonymous traveler following a pale-stone
path from a shadowed midnight-blue floating landscape toward a warm apricot sun;
muted jade trees, sculptural cliffs, painterly cinematic depth, broad silhouettes,
few objects; edge-to-edge composition; no typography, devices, controllers,
clouds, logos, recognizable existing scenes or characters. This is decorative
original art, not a screenshot or a newly supported game.

`Assets/Library/adventure-world.jpg` is a 1024-pixel optimized derivative.
`desktop/design/build_continuity.py` rebuilds `ecosystem-sync.json` from it.
The pinned local Lottie runtime is unchanged. Three layers and six animated
properties introduce the art; poses settle by frame 42 and playback ends at 180.
Frame 60 is the complete reduced-motion pose. Navigation and save state never
depend on completion. The composition is not looped.

The layer declares `hasMask` so lottie-web normalizes relative mask tangents;
omitting that flag produced malformed curves in early inspection. The actual
rendered SVG clip path was inspected to identify and correct the cause.
