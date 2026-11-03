# Save continuity and game maintenance, November 2026

This extends the original native 1.25 workspace. It does not replace the engine,
copy another frontend, or infer a successful installation/restore from an animation.

## References actually inspected

| Source | Observation | Applied decision |
|---|---|---|
| [SM Rubel ✦, cloud storage concept on Dribbble](https://dribbble.com/shots/27689388-Cloud-Storage-App-File-Management-Backup-Secure-Cloud-UI) | Original page and visible mobile compositions: file thumbnails, clear action groups and a numbered rail. Search attribution differed; the original page credits SM Rubel. | Recognizable game art in the revision list, one explicit next action and a short review rail. No screen or brand copied. |
| [Fernando Bertuolo, NUVRA on Behance](https://www.behance.net/gallery/247103153/NUVRA-Cloud-Storage-App-Branding-UI-Design) | Original project text, navy/violet branding, type and small mobile applications. Not a detailed restore demonstration. | Existing midnight/cyan system with restrained violet in original archive art; readable native type. |
| [WeTransfer on X](https://x.com/WeTransfer/status/2003166941431890416) | Public text distinguishes previews from downloads. Opening the media prompted login; no media or motion inspection claimed. | Checking a revision is separate from publishing/copying it. A prepared backup is explicitly not a restored console. |
| [Quick Tutorials, Time Machine setup and restore](https://www.youtube.com/watch?v=6ZU9IMG_JeE) | Actual player inspected around 1:32 setup and paused at 3:22, the restoring-files/history section. The full video was not watched and no physical restore was performed. | Destination setup, revision history and an explicit restore prerequisite remain separate steps. |

Research informed hierarchy and state clarity, rather than a copied layout. The
implementation uses SwiftUI, the existing design tokens and original artwork.

## Original art and motion

`desktop/NxNativeEasy/Assets/Library/save-vault.png` is original generated artwork,
960 × 640 with alpha, made with ImageGen for this feature. Prompt:

> Create an original premium 3D transparent cutout illustration for nxnative Easy’s save-transfer center. A refined satin graphite archive capsule holding two small luminous cyan and violet crystalline save tokens, with a small landscape phone and slender desktop display behind it, plus one simple unbranded graphite memory card standing to the right. Suggest two preserved versions, not a destructive overwrite. Devices have abstract cyan/violet portal screens, no games. Matching a midnight-navy desktop app with ice cyan #75EBF5, violet #8F78FF, subtle lime detail. Isometric three-quarter composition, archive is the clear main subject; objects grouped compactly, beautiful restrained studio lighting, clean silhouette, generous transparent margins, horizontal 3:2. No text, letters, numbers, logos, Nintendo or Apple symbols, no arrows indicating automatic console access, no UI controls. This is decorative artwork; all statuses and steps will be real native interface outside this image.

`save-transfer.json` is an original code-authored Lottie composition: seven shape
layers, two animated properties, 3.2 seconds at 30 fps. Two retained tokens pulse
inside an archive between device outlines. It is packaged with the existing
pinned MIT lottie-light 5.13 runtime and a local, network-denying HTML wrapper.
No external animation was downloaded. Preflight reports no errors; it is not a
performance benchmark. Decorative playback occurs only during a real helper
operation, pauses outside the active scene and uses frame 60 for reduced motion.
Completion comes from the helper result, never from an animation loop.

The native WKWebView fixture loaded eight SVG paths, accepted play/pause, changed
SVG geometry between frames 0 and 60, returned to frame 60 when paused and made
no network requests. Offscreen wall-clock frame advancement was not observed
(WebKit throttles the hidden fixture); continuous visible playback and frame
rate are not claimed by this check. The fixture catches its own failures and is
not shipped or registered as a background task.

## Interaction contract

- **Saves** is a normal workspace page. It reads an explicitly chosen folder,
  remembers a scoped bookmark and never uses the signing account for iCloud.
- Inspection reads the entire selected archive; a listing alone is not a claim
  of integrity. Raw console data requires explicit game/content confirmation
  and a checked first native snapshot to learn the actual root layout.
- Imports create independent immutable revisions. Console exports create new
  backup folders with separate roots and bilingual instructions. Neither action
  writes active game progress or declares a stock console restored.
- Renewal and rebuilding are different intents. Renewal reuses the recorded
  IPA and pins account, team, device and app identity through the existing helper.
- Primary review actions stay in a safe-area footer, including at 1000 × 640.
  Logs/history stay available without overwhelming the next action.

## Validation and limits

Native SwiftUI captures use synthetic libraries, account records and save files,
in English/Spanish at 1160 × 800 and selected states at 1000 × 640. The same
production components are rendered in an offscreen CLI bundle; no real signing,
installation, cloud selection or gameplay is triggered by that fixture.

Synthetic native-engine tests exercise imports, exact-byte exports, conflicts
and missing-root refusal. They do not prove Apple iCloud propagation or physical
Switch interoperability. The owner's Switch consoles are unmodified; stock SD
copying is not a restore path. Mario Kart World's separate proposal record is
informational and never enters the supported-profile catalog/compiler gate.
