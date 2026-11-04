# Living iCloud welcome

## Direction

Keep the accepted flat N mark and original adventure landscape. Replace the
static postcard with an interactive landscape that becomes a spatial particle
field and reforms. The story is “Your progress, with you,” supported by one
primary system-iCloud button, optional account guidance, and an explicit local
save choice. The scene is decorative; it never pretends a save has uploaded.

## References inspected

- [Flow Field Particles — Niccolò Fanton](https://flowfield.niccolofanton.dev/):
  opened the live demo, observed the moving teal/blue field and operated its
  morph controls. Chosen reference for continuous spatial motion and pointer
  response. The [author’s catalog](https://demos.niccolofanton.dev/?demo=ig-gallery)
  also describes the GPU/point-cloud experiment. Our WebGL code is original;
  no source or artwork was copied from this demo.
- [Unexpected Time — WebGL Rollover, Niccolò Miranda](https://dribbble.com/shots/21527627-Unexpected-Time-Hero-WebGL-Rollover):
  inspected the illustrated owl hero, textured blue composition and strong
  typography in the browser. This was a visual-frame observation, not a claim
  that its full video interaction was verified.
- [The End of Path — Ricardo Sanprieto](https://www.behance.net/gallery/89272769/Interactive-website-concept-art):
  inspected the project text, artwork and Vimeo poster: a traveller in a
  volumetric cosmic environment. Its linked live demo returned 404. Used only
  for atmosphere and spatial composition.
- [Codrops on X](https://x.com/codrops): public profile and posts loaded, including
  [the shader/design post](https://x.com/codrops/status/2117608020221816886) and
  [the GSAP/WebGL demonstration post](https://x.com/codrops/status/2117557620747690372).
  Read public descriptions; no claim of watching their videos.
- [Bruno Simon — Weather, portfolio devlog 5](https://www.youtube.com/watch?v=C2gDL9Qk_vo):
  inspected metadata and chapters on leaves, wind, lightning, rain and water.
  Browser playback initially showed ads; no claim of inspecting every segment.
  Useful principle: several small environmental motions make a world feel alive.
- [Apple: sign in to your Apple Account on Mac](https://support.apple.com/guide/mac-help/sign-in-to-your-apple-account-mchla99dc8da/mac):
  the system account is managed in System Settings. Easy does not implement an
  independent second iCloud login. A shared iCloud Drive folder is an explicit
  alternative; the app validates that it is really in iCloud.

## Implementation

`LivingCloudScene.swift` loads bundled `continuity-world.html` in a nonpersistent
WKWebView. A restrictive resource policy and navigation delegate limit it to its
local scene. Only playing/reduced-motion/accessible-label values cross into JS;
there is no native message bridge, account data, storage, or network connection.

Original WebGL: one textured plane and two point passes over a 132 × 88 grid.
The image morphs into a rotating sphere on click, Enter or Space and during an
18-second cycle; dragging rotates it. The light/water pass continues between
morphs. DPR is capped at 1.5 and rendering at approximately 30 frames per second.
The warm/teal glow uses premultiplied canvas compositing. Context/shader failure
shows static artwork. Reduced Motion shows one stable frame and disables
interaction. Hidden/inactive views stop their animation loops; destruction frees
GPU and Lottie resources.

`build_living_scene.py` generates an original 8-layer, 8-second Lottie halo with
travelling light points and thin orbit paths. It reuses the previously approved
original landscape as its embedded texture; no additional stock art was added.
The pinned Lottie runtime is bundled. Build-time interpolation embeds JSON locally.

## Verification

- Full native Swift target compiled; Spanish wide and English minimum-size
  layouts rendered from synthetic library data.
- Native isolated app: primary button advanced, account guidance expanded and
  collapsed, skip opened its warning, cancel returned, and the live landscape
  visibly transformed into a bright particle sphere on a held click.
- Browser scene: three render passes at the 30 Hz cap gave about 90 draw calls
  per second with WebGL error 0. This is draw-call instrumentation, not a claim
  of 90 fps or a hardware benchmark. Reduced Motion/inactive behavior is checked
  separately from the animated state.
- Seventeen desktop/cloud/update/localization tests passed. A regression check
  rejects a local folder from the shared-iCloud path without replacing its
  bookmark or starting a scan.
- Lottie preflight: no errors; embedded-raster cost warning is expected for the
  reused artwork. No user account, real game, device install or active save was
  changed by these tests. Cross-device delivery was not re-tested in this UI change.
