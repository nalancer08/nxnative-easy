# nxnative Easy launcher design system

The canonical tokens and controls live in `desktop/NxNativeEasy/DesignSystem.swift`
and `LauncherShell.swift`. The current direction is a desktop game launcher:
one persistent game list and a selected game's detail. This replaces the previous
grid-first workspace and global cloud/device connection strip.

## Structure and hierarchy

- A 60-point header starts at a 16-point inset: the system already reserves its
  titlebar controls. Do not add a second traffic-light gutter. Back exists only
  when navigation history is non-empty. Keep Library, Compatibility and Add game
  labels readable at the 760-point minimum; use the entire visible button bounds.
- The header's engine chip opens a full history screen. Its revision is the latest
  integrated runtime commit, independent of cosmetic Easy releases. Regenerate
  `desktop/engine-history.json` with `scripts/sync_engine_history.py` after engine
  integration; retain upstream identity and exact dates/titles. Show prepared
  per-platform revisions and preparation timestamps in each game detail.
- Library has a 228-point game list with real artwork, search and selection.
  Settings sits at the bottom. There is no second global navigation sidebar.
- Keep the selected game when returning from another page and remember it across
  launches. A game selection never launches, signs or installs anything.
- The selected game uses a 300-point gameplay image, a clear title, one primary
  play/install/maintenance action and a destination menu. Show installation
  evidence, cloud revisions and screenshots within that game.
- Show only repository-provided screenshots. When there is only one, use it as
  the hero and omit a redundant one-image gallery. Never invent more screenshots.
- Keep the preparation view mounted while browsing, so a build is not reset.
  Clip its drawing and hit testing to its content region. Header navigation must
  remain interactive when another screen is mounted underneath it.

## Visual tokens

| Token | Value / use |
| --- | --- |
| Background | RGB 0.065 / 0.075 / 0.098, graphite |
| Sidebar | RGB 0.047 / 0.055 / 0.075 |
| Panel | RGB 0.09 / 0.105 / 0.135 |
| Accent | RGB 1 / 0.43 / 0.25, warm orange |
| Primary text | RGB 0.94 / 0.95 / 0.98 |
| Borders | White at 7.5%, 1 point |
| Spacing | 8 / 12 / 16 / 20 / 24 / 28 |
| Type | System font; game title 36 bold; body 13–14; metadata 10–12 |
| Primary action | At least 44 points; orange gradient, dark label |
| Supporting actions | Quiet links or low-contrast bordered buttons |

Use native focus, disabled semantics, keyboard actions and accessibility labels.
Native navigation buttons accept the first mouse click in an inactive window and
use the entire control bounds, not only the text. Avoid full-page status bars,
large dashboard counts and promotional text competing with Play.

## Saves and device evidence

Easy prepares `iCloud Drive/nxnative Easy/Saves` when the real system iCloud Drive
is available. It never creates a pretend iCloud root. Existing custom bookmarks
stay in place; opt-out is respected. Advanced folder controls are in Settings.
The system iCloud account and the Apple account used for signing are independent.
On iOS, each separately signed game needs a one-time system folder permission.
Do not imply that a free signing account grants a shared iCloud container.

A local IPA means ready to install, not installed. A cloud save's origin is not
installation proof. Device rows distinguish a current scoped query from an older
installation record. A short connection notice may appear after real discovery;
it must not obscure the game's actions or become permanent chrome.

A local save is local progress; received archive revisions are cloud copies.
Conflicts keep both branches and require a choice before restoration. Do not
select a winner from timestamps. Manual export creates a checked copy and never
replaces active saves. Keep history and technical explanations in disclosures.

## Preparation, account and installation

Use shared `EasyCard`, `EasyMilestone`, `EasyStepRail`, `EasyField`, primary,
secondary and link styles. Keep password, 2FA and account recovery forms compact,
with persistent field labels and collapsed redacted logs. No credential is logged.
A saved session is in Keychain; the password is not persisted.

The preparation flow remains destination → files → keys → review → build.
Successful mobile preparation continues inline into device → signing account →
review → install. Installing later from a game opens the same guarded installer
as a modal. Close returns to that game. Navigation never authorizes signing.

Only the explicit final install action can register a new device, sign or copy.
Retain game/team/bundle identity checks, registration disclosure and unknown-slot
blocking. Never uninstall an existing app automatically. A success state requires
a matching validated installation receipt. Progress uses actual stages and real
fractions, with elapsed time when a percentage is unknown. No fabricated ETA.
Completed build notices can be dismissed without deleting output or logs.

For an existing game, iCloud maintenance opens an update review for that library
entry, never the Add game entry point. A ready IPA carrying save-continuity v2
continues to the guarded installer instead of requesting another compilation.
Successful preparation metadata takes precedence over older library revision
stamps. Unknown or legacy metadata must not claim that the runtime supports sync.

Use **Back up save** for a checked ZIP export. Use **Copy game content** only for
the large romfs content needed to play; keep that operation in the device's more
menu and explicitly distinguish it from a save backup. Both require a confirmed
closed game and current scoped device evidence, but no signing-account login.
Offer backup in the existing-app installation review before final consent.
Starting a new scoped game query clears an earlier operation's displayed error;
retain the redacted activity history in its disclosure. Show readable build stage
names while keeping detailed tool names and linker symbols in the logs.

## Art and motion

The header uses a 24-point flat N monogram with a single-baseline wordmark.
`Assets/Launcher/brand-mark.svg` is the editable source of truth;
`Assets/draw_icon.swift` exports both the transparent header mark and Dock sizes.
No miniature physical details, bevels or layered textures belong in the mark.
Rich imagery belongs to the game or the separate welcome illustration.

The iCloud welcome uses a two-column composition on wide windows and a vertical
layout at narrower sizes. “Use this Mac’s iCloud” is the sole primary action.
Another-account guidance expands only on request: manage the system account in
Settings, or explicitly choose an iCloud Drive shared folder. Reject ordinary
local folders in this path before changing any bookmark or starting a scan.
Continuing without iCloud shows a local-save warning. The signing account stays
independent. Never add a pretend embedded iCloud password form.

`LivingCloudScene` hosts an original interactive WebGL landscape, using the
approved adventure artwork as its texture. Pointer movement gives depth, dragging
rotates the scene, and click/Enter/Space dissolves it into 11,616 particles before
reconstructing it. Ambient water/light motion and an 18-second morph cycle make
the resting scene visibly alive. The surrounding light orbits are an original
8-second Lottie composition generated by `desktop/design/build_living_scene.py`.
This visual does not report save-transfer progress or advance business state.

Use only bundled resources and the pinned local Lottie runtime. The scene has
no network, account, file or native-message access. Cap rendering at 30 Hz and
pixel ratio at 1.5. Pause when inactive/hidden, free GPU resources on removal,
and show static artwork on context loss or unsupported WebGL. Reduced Motion
renders a stable landscape and removes the interactive canvas from keyboard
focus. `LauncherPortal.visible` still removes its separate decorative players
when preparation is hidden. Never create players for every library row.

Reference observations and access limits are recorded in
[living-cloud-2026-11.md](living-cloud-2026-11.md); the flat brand remains documented
in [brand-motion-2026-11.md](brand-motion-2026-11.md).

## Verification

Compile the entire desktop target. Check English and Spanish, minimum 760-point
width, long titles, cloud-only games, empty library, saves absent/present and
conflicts. Verify actual coordinate clicks, keyboard navigation, inactive-window
first click, Compatibility → back/Library and settings return. Observe the
animation in a visible native window and its reduced-motion frame.

Use synthetic accounts, devices and saves for tests. Agent checks never sign,
install, launch a real game or change the owner's active progress.

## Storage and updates

Storage offers only fingerprinted regenerable caches, including Xcode
intermediates. Compiled products, originals, keys, romfs and saves are protected.
Never automatically delete NSPs or substitute archives for originals. Show the
space reclaimed and that a later preparation may need to regenerate caches.

Update discovery runs from the visible workspace and on foreground, throttled
for automatic checks. Follow the latest published release and verify its tag
and metadata rather than treating unreleased main as a distributable version.
Manual checks show their result and time in the engine screen.
