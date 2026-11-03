# Personal library, November 2026

## Brief and direction

Players need to find their own game, see where it is actually installed, and
prepare or update it with confidence. The old global sidebar plus game sidebar
reduced the detail to a narrow column; welcome metrics displaced useful actions.
The replacement is native SwiftUI: horizontal navigation, owned-game covers,
and a full-width detail page with a back action. Keep the existing charcoal/lime
identity, accurate installation evidence, preparation state and original files.
No storefront, social feed, achievements or fabricated play history is needed.

## Research evidence

| Creator / original source | Evidence examined | Adaptation |
| --- | --- | --- |
| [Juxtopposed, Steam Redesign](https://dribbble.com/shots/22983546-Steam-Redesign) | Original shot page and first store image viewed; linked Figma returned an access/robots limit. | Clear top-level destinations; do not copy the store or its promotional content. |
| [Juxtopposed, full redesign video](https://www.youtube.com/watch?v=cDY2p1CTkPo) | Selected browser-played/paused Library frames around 11:32, 12:32 and 12:52. Observed original grid/search criticism and redesigned detailed rows with an action. The complete video was not watched. | Search belongs to the collection; each item has a clear next action. Remove the extra list rather than preserving every Steam panel. |
| [Frank Roodnat, Steam Desktop Concept](https://dribbble.com/shots/14292741-Steam-Desktop-Concept) | Original page, screenshot and creator's explanation viewed. Top navigation, dominant owned-game imagery and a visible update badge. | Library first, generous artwork, scoped rebuild advice. No activity algorithm or update ETA without real data. |
| [Christian Gusukuma, Steam Redesign: Library & friends list](https://www.behance.net/gallery/54558477/Steam-Redesign-Library-friends-list) | Text and project montage examined in browser; text fetch returned 403. The embedded Vimeo was not watched. | Breathing room and fewer enclosing boxes. No friend list. |
| X search / [Untitled UI](https://x.com/UntitledUI/with_replies) | Bounded public searches did not surface a useful original Steam example; direct page redirected to login. | Access limitation, not visual evidence. No sign-in or bypass attempted. |

These are composition references, not copied assets or a pixel-identical screen.
All game imagery still comes from the repository's mapped catalog for folders the
player added. This review does not claim to have watched complete videos or
inspected inaccessible Figma/X content.

## Original artwork

`desktop/NxNativeEasy/Assets/Library/empty-collection.png` was generated with the
built-in image generator, then resized to 768 × 512 preserving alpha. It appears
only in the empty collection and is not a game cover. Source prompt:

> Original premium 3D editorial empty personal game library: a dark charcoal open
> archival case holding three blank rounded game cards, one lifting upward; small
> lime plus on the case. Transparent background, softly frosted smoked glass and
> satin graphite, restrained #CAF15E and turquoise edges, studio lighting, elevated
> three-quarter view, landscape composition and generous margins. No text, logos,
> franchise artwork, numbers or interface controls. Conveys add your own game.

Generation used the built-in tool, not the API/CLI fallback. The project copy is
self-contained; runtime never references a generated-images directory.

## Original motion

`drop-game.json` is an editable, original six-layer Lottie composition (320 × 240,
30 fps, 84 frames). Three cards pause, descend with staggered eased keyframes,
settle behind the archive front and return for a 2.8-second loop. Trigger: actual
file-drag targeting. Resolution: settled cards; this is an invitation, not a claim
that a file was imported. Removing the drag destroys the player, without accepting
or writing a file. Reduced motion uses frame 60. Background pauses playback.

`drop-game.html` receives that same JSON during bundle creation, avoiding duplicate
animation sources and asynchronous file/network reads.
The runtime is pinned to [airbnb/lottie-web v5.13.0](https://github.com/airbnb/lottie-web/tree/v5.13.0),
light/SVG build, with its MIT license beside it. Format checked against the
[Lottie property specification](https://lottie.github.io/lottie-spec/latest/specs/properties/).
No remote fonts, images, expressions or plugins. One temporary player, never one
per game card. The main application remains native; no web navigation or account
flow was moved into a web view.

## Verification

The native desktop target compiled. Rendered English/Spanish collections at
1160 × 800, Spanish at 1000 × 640, and the empty collection with its bundled
transparent artwork. Checked long game names, cover → full-width detail → Back,
search retention, inline Devices and opening/closing installation review without
signing. Native WebKit rendered all six SVG shapes and advanced frames
6.72 → 24.18; paused at frame 60. This is observed playback, not an FPS or memory
benchmark. The temporary animation probe is not part of the application. Initial
probe failures created macOS crash reports; the corrected probe passed and its
executable was retired. No operating-system crash-report settings were changed.
Synthetic accounts, devices and package records are used in screenshots; these
are UI examples, not evidence of game installation or iCloud synchronization.
