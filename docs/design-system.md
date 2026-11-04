# nxnative Easy launcher design system

The canonical tokens and controls live in `desktop/NxNativeEasy/DesignSystem.swift`
and `LauncherShell.swift`. The current direction is a desktop game launcher:
one persistent game list and a selected game's detail. This replaces the previous
grid-first workspace and global cloud/device connection strip.

## Structure and hierarchy

- A fixed 64-point header contains back, Library, Compatibility and Add game.
  Reserve 82 leading points for macOS window controls. Back restores the prior
  route. Re-selecting the current route does not push another history entry.
- Library has a 228-point game list with real artwork, search and selection.
  Settings sits at the bottom. There is no second global navigation sidebar.
- Keep the selected game when returning from another page and remember it across
  launches. A game selection never launches, signs or installs anything.
- The selected game uses a 300-point gameplay image, a clear title, one primary
  play/install/maintenance action and a destination menu. Show installation
  evidence, cloud revisions and screenshots within that game.
- Show only repository-provided screenshots; one image is a one-image gallery.
  Opening the image uses a dismissible viewer, not an invented screenshot set.
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

## Art and motion

The new original orange 3D portal replaces the handset/controller branding.
`Assets/Launcher/app-icon-3d.png` is the source for both Dock and in-app branding.
`launcher-open.json` combines the generated 3D portal with original keyed vector
orbit lights. It decorates the first-game welcome and destination step; it never
advances build/install state. Native opacity transitions accompany selection.

Use the pinned, local Lottie runtime. Pause when inactive, remove players off
screen and show the meaningful resting frame 60 for reduced motion. Never create
a player for every game row. Reference provenance, prompts, access limits and
verification notes are in [launcher-art-direction.md](launcher-art-direction.md).

## Verification

Compile the entire desktop target. Check English and Spanish, minimum 760-point
width, long titles, cloud-only games, empty library, saves absent/present and
conflicts. Verify actual coordinate clicks, keyboard navigation, inactive-window
first click, Compatibility → back/Library and settings return. Observe the
animation in a visible native window and its reduced-motion frame.

Use synthetic accounts, devices and saves for tests. Agent checks never sign,
install, launch a real game or change the owner's active progress.
