# nxnative Easy launcher design system

The canonical tokens and controls live in `desktop/NxNativeEasy/DesignSystem.swift`
and `LauncherShell.swift`. The current direction is a desktop game launcher:
one persistent game list and a selected game's detail. This replaces the previous
grid-first workspace and global cloud/device connection strip.

## Structure and hierarchy

- A 60-point header starts at a 16-point inset: the system already reserves its
  titlebar controls. Do not add a second traffic-light gutter. Back exists only
  when navigation history is non-empty or a maintenance review can be closed. Keep Library, Compatibility and Add game
  labels readable at the 760-point minimum; use the entire visible button bounds.
- The header's engine chip shows the integrated engine's dotted version, such as
  1.0.1, independently of the Easy app version. A game compares its own engine
  version with the current one. Hashes stay in technical help/links. Never show
  ordinal build counters as the engine version or guess order from dates/hashes.
  `scripts/sync_engine_history.py` creates stable offline source-to-version lookup
  from the first-parent integration history. `desktop/engine-versioning.json`
  defines the baseline and explicit major/minor overrides. Each later runtime
  integration advances the patch; cosmetic Easy releases keep the engine version.
- A 44-point profile button stays at the right edge. Its initials belong to the
  local Mac user and are explicitly labeled as this Mac's profile, never as a
  verified iCloud identity. Its cloud badge opens connection status, last successful
  scan, the selected folder, and the system account settings shortcut. At narrow
  widths, collapse branding/Add game to labeled icons before removing status.
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
  `RetainedPage` keeps its hosting view and local state alive, but sets the native
  view hidden when inactive. Opacity and SwiftUI hit-testing alone do not remove
  represented AppKit controls from accessibility. Present shared installation,
  save help and analysis sheets from the visible workspace root. Header navigation
  remains interactive and the titlebar is the window drag region; content is not.

## Visual tokens

| Token | Value / use |
| --- | --- |
| Background | RGB 0.065 / 0.075 / 0.098, graphite |
| Sidebar | RGB 0.047 / 0.055 / 0.075 |
| Panel | RGB 0.09 / 0.105 / 0.135 |
| Accent | RGB 1 / 0.43 / 0.25, warm orange |
| Primary text | RGB 0.94 / 0.95 / 0.98 |
| Decorative borders | RGB 0.27 / 0.31 / 0.38 |
| Control fill / outline | #272E3A / #75839A (3.56:1) |
| Supporting text | #B6C0D0 (at least 7.4:1 on control fill) |
| Disabled text | #98A4B6; legible, without an active outline |
| Keyboard focus | #9ACBFF, 2-point outer ring |
| Spacing | 8 / 12 / 16 / 20 / 24 / 28 |
| Type | System font; game title 36 bold; body 13–14; metadata 12; compact uppercase eyebrows 10–11 |
| Primary action | At least 44 points; orange fill, dark label |
| Supporting actions | Quiet padded actions or filled, clearly outlined buttons |

Use native focus, disabled semantics, keyboard actions and accessibility labels.
All interactive styles explicitly accept window activation events. Native navigation buttons accept the first mouse click in an inactive window and
use the entire control bounds, not only the text. Avoid full-page status bars,
large dashboard counts and promotional text competing with Play.

## Interaction contract

`EasyPrimaryStyle`, `EasySecondaryStyle`, `EasyLinkStyle`, `EasyIconStyle` and
`EasySelectionStyle` own the complete padded interaction rectangle. Do not put
padding outside a button and expect it to be clickable. Icon controls and back
have a 44 × 44 point target. `EasyMenuStyle` uses button-backed native menus with the same control styles
and minimum geometry. A borderless native menu flattens its SwiftUI label and
discards custom label backgrounds; do not style only that label. Decorative overlays cannot intercept input. Use hover/pressed feedback
without scaling the hit region; respect Reduced Motion. Keep system keyboard
navigation preferences and provide Cmd-1 Library, Cmd-2 Compatibility, Cmd-F
search, Cmd-N Add game, Cmd-[ back and Cmd-comma Settings.

The label and handler of a game's primary action come from `GamePrimaryIntent`.
An expired/expiring signature takes priority over an optional iCloud upgrade:
show **Renew signing**, open the existing renewal review, and keep recompilation
separate. Disable actions for operations that actually conflict. A disconnected
phone shows “Connect to back up your save” instead of an inert backup link.
Search has an explicit empty result and a large clear control.

A control boundary needs at least 3:1 contrast and normal text 4.5:1 against its
actual fill. These are measured palette checks, not a certification of every
photographic pixel or system-provided control. Test real native screenshots too.

## Saves and device evidence

Easy prepares `iCloud Drive/nxnative Easy/Saves` when the real system iCloud Drive
is available. It never creates a pretend iCloud root. Existing custom bookmarks
stay in place; opt-out is respected. Advanced folder controls are in Settings.
The system iCloud account and the Apple account used for signing are independent.
macOS does not expose the iCloud account's email/photo through the supported
Drive identity API. Do not scrape preferences, Contacts, private frameworks or
Keychain to invent a profile. Provide “View account in macOS” for the actual
account. Initial setup waits for a successful folder scan and shows a confirmation
with the actual selected folder before entering the library; access is not proof
that another device has received a save. On system identity change, drop cached
account evidence and require reconnecting; never delete or move save files.
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

Compile the entire desktop target. Run `scripts.tests.test_desktop_interaction`
for resolved color contrast, native corner hit tests, hidden-page isolation,
retained form state and maintenance intent precedence. The test throws and exits
on failure instead of creating crash-report dialogs. See the detailed
[interaction audit](ui-ux-audit-2026-11.md) for evidence and limits.

 Check English and Spanish, minimum 760-point
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
