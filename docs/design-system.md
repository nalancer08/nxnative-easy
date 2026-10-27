# nxnative Easy desktop design system

The canonical implementation is [`DesignSystem.swift`](../desktop/NxNativeEasy/DesignSystem.swift). Use its tokens and components for future account, installation and preparation changes. Extend the shared system before inventing a parallel visual style. This system is original, built with native SwiftUI shapes and SF Symbols; it does not copy another frontend's artwork or layout.

## Foundations

| Token | Value / intent |
|---|---|
| Background | `EasyDesign.background`, RGB 0.065 / 0.075 / 0.07 |
| Primary text | `EasyDesign.ink`, RGB 0.93 / 0.94 / 0.90 |
| Accent | `EasyDesign.accent`, RGB 0.79 / 0.95 / 0.37; main action and confirmed milestones |
| Surface | White at 4.5% over the dark background |
| Border | White at 7.5%, 1 point |
| Page padding | 28 points |
| Content spacing | 20 points; internal groups use 8 / 12 / 16 / 20 / 24 |
| Card radius | 18 points; milestone radius 20; field and action radius 10 |
| Page heading | System rounded, 30 points, bold |
| Milestone heading | System rounded, 24 points, bold |
| Section title / body | Native headline / callout; no custom font download |
| Supporting text | Native caption, secondary; keep essential instructions in callout |
| Technical output | Monospaced 11 points, selectable, bounded scroll area |

Use orange plus an explanatory symbol and text for warnings. Green/accent indicates a confirmed state; never use color alone. Preserve native keyboard focus rings, accessibility labels, disabled semantics and text selection for account identifiers/errors. Do not log passwords, verification codes, key contents or provider responses.

## Reusable components

- `EasyCard`: padded, bordered content surface with one coherent task.
- `EasyMilestone`: a distinct native vector composition and a useful heading/explanation. Device, account, review, transfer and verified completion have separate compositions. Decorative geometry is hidden from accessibility.
- `EasyStepRail`: completed, current and future milestones with labels and checkmarks. It is an indicator, not a shortcut that skips required checks.
- `EasyField`: persistent label above a generously padded native text field. Keep forms at roughly 500 points, even on a wide page. Never rely on placeholders alone.
- `EasyPrimaryStyle`: one dominant action per decision, 44-point minimum height; disabled state is clearly different. `LibraryPrimaryButtonStyle` delegates here.
- `EasyLinkStyle`: quiet accent links with disabled feedback for back, recovery and sign out.
- `EasySecondaryStyle`: supporting actions with quieter contrast. Back, sign out and alternatives should not compete with the primary action.
- `InstallActivityView`: current operation, real percentage if supplied, elapsed time and cancellation. Errors are separate readable cards. Full redacted logs are always available in a **collapsed** disclosure; their history must not overwhelm the action.

Preparation's existing `PreparationIllustration` uses the same accent/text tokens and retains its unique per-step vector compositions.

## Navigation and flow contract

A successful iPhone/iPad preparation continues **inline** in the main workspace: device → Apple account → review → install. Preserve the prepared game and its compilation output. The transition configures/discovers only; it does **not** sign, register a device, install, copy data or authorize a purchase.

Installing later from the library or device management opens the same installer as a modal. Closing the modal returns to the originating context. The account in Settings uses the same account component, embedded as a normal page. There is one shared account/session model for this Mac.

Each installer screen must answer:

1. What game and destination am I working with?
2. What is confirmed, and what is still needed?
3. What single action takes me forward?

Device choice uses cards with actual discovery metadata and a visible selection. Account screens cover saved-session recovery, password login, 2FA, authenticated team selection and unknown membership without changing their authentication behavior. Keep privacy/provider configuration behind a disclosure. Saving the session means macOS Keychain, not password persistence.

The review shows destination, account, existing app identity, full versus split data behavior and actual registration status. Its single install action stays in a safe-area footer, with an actionable explanation while disabled; the scrollable content never covers it. Unknown registration blocks installation. A new device requires explicit approval; slot counts remain labelled estimates and appear only when membership metadata supplies a supported limit. Never infer a free account from `Individual` alone.

Signing/installing happens only on the explicit final button. Keep matching-game/team/identity checks, save preservation, new-device consent and content-version checks in the model/helper. Present automatic renewal as an explicit choice, available only with a remembered session; advanced launch-at-login and app-only options live behind a disclosure. Never silently uninstall an existing app.

A success illustration appears only after a **validated `installed` event matching the current game, account team and device**, not because a progress bar reaches 100% or the helper becomes idle. Failure and cancellation offer review/retry. Progress is real: unknown percentages stay indeterminate with elapsed time. Never invent an ETA or imply a partial data copy is a completed installation.

## Verification before shipping

Compile the whole desktop target and run the synthetic client/workflow fixtures. Render at least: empty and selected device; password form in English and Spanish; saved-session recovery; 2FA; authenticated team/slots; new-device review; progress; verified success and failure. Check the minimum desktop content width (760 points), long names, scrolling, focus, one primary action and collapsed log history. Keep decorative artwork static so reduced-motion settings need no exception.

Use fake accounts, helper messages and devices for screenshots/tests. Do not initiate real account login, registration, signing or installation during agent validation. Real-device testing remains a separate user action.
