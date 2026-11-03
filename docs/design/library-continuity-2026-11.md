# Library continuity — November 2026

## Product direction

One personal library, with a game as the unit of navigation. The same title can
have Mac files, an iOS IPA, known device installations and received cloud saves.
A cloud-only record stays useful: it explains that files are missing and starts
the existing destination-first preparation flow. Files, installed presence,
provider delivery and compatible progress are separate facts, not one Ready flag.

The collection uses the existing navy/cyan palette, native SF typography and game
artwork. Covers lead to one focused detail page. Destinations come first, saves
second, version history last. No second sidebar, internal game tabs or global
Saves/Devices pages. Signing-account recovery is compact and isolated from iCloud.

## References actually inspected

- [Darshan Shah, Game Launcher UI Design, Dribbble](https://dribbble.com/shots/17727529-Game-Launcher-UI-Design):
  original page and image inspected in the browser after the CDN failed. Cover
  selection leading to focused game content informed the grid/detail relationship;
  its composition and illustrations were not copied.
- [Alexander Sarkisyan / wannabe rozov, Steam UX/UI Redesign, Behance](https://www.behance.net/gallery/210047539/Steam-UXUI-Redesign):
  web extraction returned 403; the browser showed the original project introduction
  and profile-editing panels. Clear task grouping and a distinct Save action were
  observed. A library-detail interaction was not verified from this project.
- [X Engineering, Overhauling mobile.twitter.com from the ground up](https://blog.x.com/official/en_us/a/2012/overhauling-mobiletwittercom-from-the-ground-up.html):
  original text read as a fallback after the Hydra Launcher X profile was blocked.
  Progressive hierarchy and testing complete user tasks informed the flow.
  This is written research, not a contemporary animated launcher demonstration.
- [JM6, Save files on Steam: local and Steam Cloud, YouTube](https://www.youtube.com/watch?v=V_jTqaGjLA8&t=477):
  the original video was opened at its 07:57 cloud-access chapter; after buffering,
  playback and a paused frame at 09:03 showed Steam Cloud's per-game file list.
  The separation of game identity from file copies informed the save detail.
  No motion timing or performance claim is based on this video.

Platform constraints were checked against Apple's primary documentation:
[directory access](https://developer.apple.com/documentation/uikit/providing-access-to-directories)
and [iCloud capabilities](https://developer.apple.com/documentation/xcode/configuring-icloud-services/).
A developer signing session cannot grant another app access to the user's cloud
folder or silently change the system iCloud account.

## Original assets

`desktop/NxNativeEasy/Assets/Library/cloud-library.png` is a generated transparent
illustration for the first iCloud connection. Direction supplied to the generator:
a graphite MacBook, iPad and iPhone arranged around a cyan save crystal, with a
cyan/violet connecting light ribbon, generous dark-compatible negative space,
no text, no logos, no embedded controls. It is decorative; native labels and
controls carry all account/provider facts. The delivered source is 1536×1024 RGBA
and remains bundled at its existing raster resolution.

Generation source:
`01a1790c-9af7-7482-98cc-c3925de3cad5/exec-134f721a-61ee-4a9a-99ce-692f873110b5.png`
in the session's generated-image archive. Game artwork continues using repository
catalog mappings; generated decoration is never presented as gameplay evidence.

`device-connected.json` is an original local Lottie: 220×160, 30 fps, 61 frames.
A phone appears, then its confirmation ring/check resolves. It starts only after
actual discovery adds a ready device, plays once for about two seconds and ends
at frame 60. The five-second notice can be dismissed independently. Inactive
motion pauses; reduced motion uses a native checkmark. The same pinned offline
Lottie runtime, strict resource policy and teardown as the existing drop/transfer
motion are retained. No device name, account, filename or save data enters its
web view. Its structural preflight requires local assets and actual keyframes.

## Verification scope

Native SwiftUI fixtures render the real production components in English/Spanish
at 760 and 1120 points. Their accounts, devices, game outputs and save headers are
synthetic. They demonstrate layout and state handling, not real installation or
iCloud delivery. The existing native continuity fixtures exercise delivery,
conflicts, foreground retry and final Play checks; the new Mac fixture covers
selected-folder adoption and refusal to replace an earlier game's folder.

The library test covers two local platform sources merging with cloud records,
cache/offline recovery, changed-folder response isolation, transport deduplication,
scoped discovery during authentication, disconnect history, fresh absence and
legacy-helper refusal. No test reads real Keychain credentials, signs or installs
an app, exports a real device save, changes a user's iCloud folder or runs a game.
A real iPhone→iCloud→Mac→iPhone round trip still requires user gameplay validation.
