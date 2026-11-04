# Launcher clarity, November 2026

The task is a personal game library with one selected game, visible save continuity,
installation evidence and engine provenance. The revised header aligns to the
window content rather than reserving traffic-light space twice. The logo is a
physical game cartridge; the new six-second Lottie travels between three screens
and a cloud checkpoint. A native entry/hover tilt and selection transition support
that narrative without determining any build, install or save state.

## References and access limits

- [Dina Rafikova, Steam redesign](https://dribbble.com/shots/26698011-Steam-redesign):
  the original page description was accessible, emphasizing a personal library
  and seamless journey. Its image CDN timed out; no image detail is claimed.
- [Connor Shea, Steam Redesign Concept](https://www.behance.net/gallery/18931105/Steam-Redesign-Concept):
  search-index text describes neutral supporting actions and an emphasized primary
  action. Direct Behance requests returned 403, including an alternative case study.
- [Juxtopposed, Steam UI video](https://www.youtube.com/watch?v=cDY2p1CTkPo):
  indexed video metadata and chapter markers identify Navigation at 02:29 and
  Library at 11:28. Direct playback was unavailable; this was not video observation.
- [Juxtopposed on X](https://x.com/juxtopposed): direct access returned 403;
  focused public searches did not provide an accessible original game-library demo.
- [Valve's library presentation](https://store.steampowered.com/libraryupdate):
  contextual reference for grouping a game's updates and information inside its page.

These are research limits, not a claim of complete visual inspection. The implemented
geometry follows the actual app's observed problems and native macOS constraints.
No third-party screen, icon or video was copied into the app.

## Original assets

`desktop/NxNativeEasy/Assets/Launcher/app-icon-3d.png` was generated with the built-in
image generator. Prompt: a graphite physical game cartridge, clipped upper-right
notch, four copper contact pins, orange pixel-cross blocks, lavender rim light,
frontal 3D product render on a charcoal macOS tile; no text or third-party logo.
The full generation prompt is retained in the task conversation. Its optimized
256px variant is embedded in `Assets/Library/ecosystem-sync.json`; native header
art and Dock icon share the original asset. The Lottie is original keyed geometry
and an embedded bitmap, with a local runtime, no remote dependency and a meaningful
resting frame for reduced motion.

## Safety contract

Cloud onboarding uses macOS iCloud Drive and never asks for signing credentials.
The skip warning changes sync preference only, never local game or cloud files.
A legacy app still needs an update and the existing in-game iOS folder permission.
Engine history records actual integrated commits; build metadata falls back to
the preparation record's file date when old records have no explicit timestamp.
No device signing/installing or active progress restoration is part of agent QA.
