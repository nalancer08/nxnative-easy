# Pending upstream review

Pinned head: `c7ba23df0872b5511141649776a80c8eff61db46`.

Manual conflict resolution required. No engine changes are staged in this proposal. Conflicts: README.md, dm/gfx/tests/t_geometry_hazards.m, dm/host/Makefile, dm/host/tests/t_fs.c, dm/ios/Sources/DmGamepad.m, dm/ios/Sources/DmIOS-Bridging-Header.h, dm/ios/Sources/Launcher.swift, dm/ios/Sources/front_ios.m, dm/tools/nx_extract/Program.cs, docs/settings.md, scripts/build_ipa_from_nsp.py

```text
c7ba23df Indirect-count multi-draws of more than 1,024 draws are recorded as one range and replayed whole: MIO's GPU-driven scene (maxima 4,594 and 8,192) lost every draw past the first 1,024 (#1062)
56e4577b Snapshot acquires paced by the display link, an upsample pass reads the level its sampler pins, and a submission's segment count starts with it (from #1073)
641d1480 The barrier moves around warp shuffles (Ampere 0xf55 / 0xf56) are no-ops: two of Hyrule Warriors: Age of Imprisonment's pixel shaders translate (chain 95ba69b5403e)
b2bdcbc9 Hyrule Warriors: Age of Imprisonment: its playtests' 15,445 shader keys for a partial Mac library, and why every boot starts at the first-run settings
e2fadf22 iOS: portrait, a half-folded iPhone Duo and iPad windows lay the picture above the controls, the picture can Fill the screen, and a gear opens an in-game menu whose settings take effect at once (#683, #1083)
48888df5 Holding a controller's Home button for 2 s quits a Mac game after a prompt: A quits as ⌘Q does, B or Home goes back, so a player on the couch needs no keyboard (#1084)
84ec307f Mesh geometry draws gathered into one dispatch: Donkey Kong Bananza's depth prepass, 480 mesh draws 1.50 → 0.67-0.72 ms on an M1
db8acc5c The offline archive builder streams its pipeline script and key and drops the descriptors before metal-tt: Python holds 0.06 GB, not 1.8 GB, during Mario Party Superstars' 140,036-base build (#1024)
85468b6c A game's own upscaler drawn by MetalFX, the player's choice in the launcher: Donkey Kong Bananza's NDSR network 3.5-5 ms → about 1 ms a frame on an M1 (#1086)
16a90a77 Same-pass feedback draws that sample their attachment at gl_FragCoord times 1 / its size read it from the tile: Splatoon Raiders' ink stamps take no whole-map snapshot (#1063)
8c80f39a The NSP script reuses its extracted DLC only while aoc/ holds what it wrote: a NUP or dump build packing its DLC there in between no longer leaves the next NSP build with the wrong images
cfcef15a README: a .nup file as the first way to build a Switch 2 game, with the profile requirement stated for both routes
b64a5ff0 README: Hyrule Warriors: Age of Imprisonment in the gallery and among the Switch 2 games, with a Mac screenshot from its first field
3ace3df3 A dedicated c1 constant block is a 64 KiB slice of a shared bank, not a Metal buffer of its own: Hyrule Warriors: Age of Imprisonment's first field from 10 fps to a 16.6 ms median frame
d70ee900 Hyrule Warriors: Age of Imprisonment reaches its first field on the Mac: GameChat, the language selection limit and the target frame rate answered for Switch 2 games
aa9fa765 Reject unsafe ExeFS filenames in NUP archives
07ca3efc lint-c and lint-python pass again: t_queue_origin checks the composite exists before reading it, pack_nup passes n.copy itself
df60f631 README: Fire Emblem Fortune's Weave at 60 fps, the four Switch 2 games in the intro, captions for five more 60 fps games
423a6745 The NSP script builds a game from one NUP container, with no prod.keys: Hyrule Warriors: Age of Imprisonment's 47 GB NUP unpacks in under five minutes (#1048)
e70fd69d The shader builder reads each record from its package when needed instead of keeping 4.4 GB of packages in memory: Pokopia's builds run their workers in parallel again (#1036)
379e885e The TXQ type test checks its InstTable match before indexing it: lint-python's pyright no longer finds a subscript of None
6a16b7d3 An uncompressed 3D texture the CPU wrote is taken from its storage at first use (#1050)
b5910377 The strap guide's SDK 22 overload, with a StrapGuideArg, is answered like the other
0a05fb10 Fire Emblem Fortune's Weave: 60 fps through the game's own target frame rate, found by its readers
f5d5327f A read-only image load of a colour attachment reads the same-pass snapshot: Xenoblade Chronicles 3's cutscenes no longer alternate brightness every frame (#1025)
7ef2aaf5 An AudioOut keeps releasing buffers on the silent sink while a host worker starts its device: a blocked AudioOutputUnitStart no longer freezes the game (#1030)
1440a736 A finalized program leaves every queue's bindings: Fire Emblem Fortune's Weave crashed in keys_hash at the title's hand-over to the opening demo (#1046)
fa681f94 The watchdog launches sample without a shell: an apostrophe or shell syntax in DM_WATCH_SAMPLE stays part of the path (#829)
869b9423 A partial Mac shader library for Pokopia from its playtest's 8,157 keys, built in about 20 minutes instead of the whole map (#1038)
aa94702d Snapshot textures taken by format and size, readback buffers kept for reuse: no texture or buffer made per use (#931)
d145b956 A size query takes its texture's type from the shader's other instructions (chain 09e6fcbd87b8)
7db7ff09 The bundled translator loads on Intel Macs again: its dll is AnyCPU under any runtime ID
c3e66245 The NSP script removes per-shader cache entries the current chain's build did not use: 70 GB on Tears of the Kingdom
2c35f7b3 The Xcode preparation fixture's run writes its log, as the real run does
bd688163 A daily triage report on open pull requests and issues (#770)
4d3a9a53 dmsh_wide.py maps to every NVN game in regress.py impact; its doc says what the packed read compiles to
1b9fbea4 Storage words the translator split are read whole again: Splatoon Raiders' lit pass 70 → 16 ms on an M1
5f96f901 Area labels on pull requests from the paths they change (#408)
3fe755a2 LDSM keeps its mode in the stride's bits: Donkey Kong Bananza's upscaler read its transposed matrices four times too far along
8c10c011 Princess Peach: Showtime! plays on the Mac
12915a31 Donkey Kong Bananza: GPU timestamps per segment, so its dynamic resolution sees the GPU and the heavy areas hold 30 fps (#1003)
34459c91 Same-pass feedback draws that sample their attachment at their own pixel read it from the tile (#737) (chain 3050244a6ff1)
7d260eef The encode thread records the depth plane copy's blits with options
3104c0af Keys older than the game stop the NSP script at once, naming the key and its firmware
de23ae82 nn::nfp::GetState answers the amiibo library's own state: 0 until Initialize
50675d51 An odd present interval goes back to the 60 Hz display link: interval 3 ran at 15 fps instead of 20 (#1001)
73f4a48b nn::fs::Unmount releases a mount held in the SDK's own table
e58e4467 Sampled depth attachments read through red texture views of the same depth storage (#988)
6136418b fs::ReadFile with read options and no byte count is hooked, and must read in full (#947)
f1766444 Unreal's host heap keeps 64 KiB alignment for span-sized blocks (#1006)
f714e138 CI lint: the logic operation rewrite's joined text has its own name, a LINKDATA job stops when its index is gone, the geometry hazards test checks its readback buffer (chain 16dec73a79e7)
03d92a9f Pokémon Pokopia plays on the Mac
dac4a433 The shader split reads each SARC member's name up to its own NUL (#968)
b1dee89c The Legend of Zelda: Skyward Sword HD plays on the Mac; logic operations on normalized targets; encrypted .vert / .frag files are no run-time GLSL
65501fbb AV1 movies decode with dav1d where VideoToolbox has no AV1 decoder
bd41cf77 dav1d 1.5.4 vendored: the arm64 sources, unmodified, for AV1 movies where VideoToolbox has none
fefb16d1 Primitive ID pipelines: a GPU test, and their pairs left out of the prebuild and the offline archive
694ea914 Loader: the image the game's module sections are read from can be set (#729)
fa4c3566 Front ends: an app that hosts the game view can draw the prepare step's progress itself (#742)
```

Follow docs/agents/07-upstream-maintenance.md before integrating. This workflow never advances integrated_head, bumps releases, signs, installs or merges the PR.
