# Desktop interaction and accessibility audit — November 2026

Scope: the SwiftUI/AppKit launcher, library detail, compatibility, preparation,
installation/account flow, save actions, settings, diagnostics and storage.
The accepted brand, artwork, game runtime and engine version are retained.

## Findings and corrections

| Priority | Evidence / cause | Correction |
| --- | --- | --- |
| High | The inactive preparation page used opacity, hit-testing and accessibility modifiers. Its represented native destination controls still appeared in the library and compatibility accessibility trees. | `RetainedPage` physically hides its retained hosting view. Its native descendants leave interaction and accessibility while local form state remains alive. |
| High | Installer, save-help and analysis sheets and the current-version alert belonged to that hidden preparation subtree, although library buttons could request them. | Present them from the visible workspace root. Closing returns to the same selected game. |
| High | An installed game with an expired signature and a legacy save runtime showed “Update” and routed toward iCloud preparation before handling signing expiration. | A single primary-intent resolver controls both title and action; renewal takes precedence. It reuses the renewal installer instead of requesting shaders/recompilation. |
| Medium | Button implementations mixed plain text, small icon labels and custom padded styles. Shared styles had no explicit activation-click policy or hover/focus treatment. | One control body owns the complete padded interaction rectangle, explicit activation policy, hover, pressed and disabled states; icon/back targets are 44 points. Native header/game-list controls retain full-bound hit testing and gain persistent selected feedback. |
| Medium | Borderless native menus flattened SwiftUI label backgrounds, so styled labels still rendered as bare text. | Use button-backed menus with the shared button/icon styles so appearance and hit geometry belong to the actual control. |
| Medium | Faint supporting-action borders did not clearly identify control bounds. Supporting and disabled text relied on contextual system opacity. | Opaque shared text/fill/outline tokens, resolved contrast tests, 12-point metadata, visible focused fields and a focus-ring treatment. Decorative overlays do not intercept events. |
| Medium | A disconnected device offered an inert “Back up save” control. | Explain that the phone must connect, then offer the real action only with current scoped installation evidence. |
| Medium | Navigation/search had inconsistent shortcuts, and a filtered game list could appear empty without explanation. | Shared navigation model; Library, Compatibility, search, Add game and Settings shortcuts; padded clear-search action and explicit no-results state. |

The earlier header did respond to an ordinary click, and the isolated old primary
button also accepted an activation/corner click. Therefore the reported dead
clicks are not attributed universally to a single missing `contentShape` or to
window activation. The native hidden-page leakage is directly reproduced; the
shared control and presentation fixes remove separate interaction hazards.

## Contrast measurements

Measured from resolved sRGB SwiftUI colors using relative luminance:

| Pair | Contrast |
| --- | --- |
| Primary text / supporting button fill | 12.21:1 |
| Supporting text / supporting button fill | 7.44:1 |
| Disabled text / supporting button fill | 5.41:1 |
| Control outline / supporting button fill | 3.56:1 |
| Orange action text / panel | 6.21:1 |
| Keyboard focus / page background | 10.93:1 |

These are token-level checks. System pickers, photographic artwork, all possible
localized strings, VoiceOver operation and every display configuration are not
claimed to have a complete accessibility certification.

## Verification

An isolated native app uses the production views/styles with synthetic library,
cloud folders, disconnected/connected device records and an expired installation
receipt. The helper rejects real installation/authentication operations and logs
only operation names. No owner's credentials, active games or progress are used.

Coordinate clicks in padded corners of primary, supporting, quiet, icon and
native controls incremented visible counters exactly once. The disabled action
remained at zero. English and Spanish layouts were inspected at 760 and 1120
points; long titles wrap and supporting panels stack without hiding actions. The manual current-version check displayed its alert from the engine screen.
The updated primary action opened the renewal sheet, and Close
returned to the same Zelda detail. Destination and save menus opened and closed
without starting an operation. Compatibility search, Library return, all four
Settings sections and destination → files preparation were exercised. Browsing
away and returning preserved the preparation step; hidden preparation controls
were absent from the library/compatibility accessibility trees.

Automated native checks cover palette contrast, native full-bound hit tests,
activation acceptance, disabled focus eligibility, retained state after hide/show
and primary-intent precedence. Existing launcher, game-health, cloud-library,
workflow and localization suites guard surrounding behavior. Release packaging
and updater validation use separate staging folders.

Physical Tab traversal follows the Mac's Keyboard Navigation preference; the
audit does not silently change that system setting. Keyboard shortcuts and text
search were verified independently. Signing, installation, save restoration and
cache deletion were deliberately not performed on real user data during this
UI audit.

## References

The local `ui-ux-pro-max` skill supplied the audit checklist. Native platform
decisions follow Apple's [buttons guidance](https://developer.apple.com/design/human-interface-guidelines/buttons),
[accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility),
[interaction content shape](https://developer.apple.com/documentation/swiftui/contentshapekinds/interaction),
[window activation event policy](https://developer.apple.com/documentation/swiftui/view/allowswindowactivationevents(_:))
and [window background dragging](https://developer.apple.com/documentation/swiftui/scene/windowbackgrounddragbehavior(_:)).
