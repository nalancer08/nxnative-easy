# Pending upstream review

Pinned head: `f634de70ae1e900a67008fa1b33b5ee478f1cf46`.

Manual conflict resolution required. No engine changes are staged in this proposal. Conflicts: .gitignore, AGENTS.md, README.md, dm/host/Makefile, dm/host/save_sync.c, dm/host/tests/Makefile, dm/ios/Sources/Launcher.swift, dm/ios/Sources/front_ios.m, docs/agents/symptoms.md, docs/development.md, docs/frontends.md, docs/reference/packing.md, docs/settings.md, scripts/build_ipa_from_nsp.py

```text
f634de70 Hollow Knight plays on the Mac; libraries prefetched before the prewarm starts are kept
99947471 The NSP script builds a game from a folder of its files, with no prod.keys
588e01a5 README: acknowledgements keep the projects with a GitHub link, and Ryujinx
97f1514a C lint: t_image_attachment_store checks its DontCare-load program resolved before using it
a1b9a2ae Boot no longer aborts in dispatch_once: the shader map is read once from any thread, the prewarm starts once outside it
caac52fb README: acknowledgements as one item per project, with MacNativeGames; the folder a Switch 2 game is packed from
b99fca20 README: acknowledgements before How to play, a Switch 2 line in the intro, Switch 2 games first in the gallery
0e8503e7 CI lint: the HMMA rewrite's matches are checked, the geometry colour cache compares a byte key, and two tests guard their indices
4de40e62 Donkey Kong Bananza holds 60 fps on the Mac: HMMA on the matrix hardware, mesh geometry, linear run checks, drains only for later writes, SUATOM
c4b0618c Donkey Kong Bananza plays on the Mac: terrain through loaded pointers, Switch 2 device values, decoders, prewarm without a seed list
5251763d Ampere jump tables end at the next table; BRXU and REDUX translate; Donkey Kong Bananza builds 22,850 of 22,852 shaders
5b2d4606 Serve the Switch 2's nn::codec video decoder and sync point events on the host; Donkey Kong Bananza plays its first level's opening with its guide movies
fdb3710d Switch 2 textures untile in the Switch 2's GOB order; Donkey Kong Bananza's rock textures render clean, all of its first gameplay minute's shaders translate
a7bd05f4 Donkey Kong Bananza renders its first gameplay scene on the Mac: tensor instructions for agl's upscaler, NVN2 compute c0 and push constants, mip-chain sampling without the attached level
d3995ca4 Translate Switch 2 (Ampere) shaders natively; Donkey Kong Bananza's menu renders on the Mac; supported Xcode is 27.2
8dd0c98a Donkey Kong Bananza (Switch 2) boots into its frame loop on the Mac; scripts/pack_dump.py packs a dumped game
742c9fb8 Dead Cells: profile, and the split reads the GLSLC outputs in Heaps' shader cache
0e16e0e0 rewriter: a br x18 with code after it is a tail call when its frame is provably gone (#773)
dad38db6 iOS launcher: one tap presents one cloud-save folder picker (#800)
68e8dc23 pso_offline: free disk space is checked before metal-tt and a full disk is named when it fails (#790)
088429f4 ngc: the China-region profanity check and mask are answered on the host (#789)
d56b83ab NSP script: GLSL source files in the RomFS schedule the GLSLC capture (#767)
5ce955ad nvn: concurrent warm tasks prepare each shader key once (#820)
94484212 nvn: DM_NVN_SHDUMP makes its directory; DM_NVN_PASSDUMP prints the viewports a pass sets (#745)
8482873b Mac: the Metal HUD menu's Hide HUD hides the overlay (#692)
f4bfc015 present: DM_PRESENT_LATENCY above 2 asks the display link for 2 (#697)
792df9fb os: the game environment copy is freed when it holds no assignment (#831)
338e2ad5 docs: Xenoblade Chronicles 3 2.2.0 shares the 2.2.1 main build ID (#849)
c0f34133 Mac: the display stays awake while the game window is key (#741)
c1df4dda Mac: game input hides the pointer over the picture until the mouse moves (#584, fixes #675)
0c6c55df nvn: shorter state and single texture bind records keep Super Mario Odyssey's display lists in their heap (#838)
a5281d01 Mac: HID gamepads that GameController does not list get a player slot (#669, #637)
95dc61e2 nfc: Initialize, Finalize, GetState and IsNfcEnabled answered without nfc:user; NFC reads as switched off (#711)
5fd06dd1 fs: a save folder that cannot clone says it needs APFS; recursive deletes never enter symlinks (#661)
d138ee87 nvn: report a command buffer's control memory as free (#660)
9f74a1d6 iOS: the BC device check runs at Play, so the launcher's Performance HUD shows (GitHub issue #840)
8ef752a2 NSP script: merged NSPs and XCIs count as each title they hold; --title-id picks one game of several (#842, #701)
07fc83d4 audren: the renderer keeps its own event; the game's gets a copied read end
70ca6164 nvn: apply a present cap only with a frame step or an engine limit the host writes
28035370 build_ipa_from_nsp: a derived profile without frame step stubs keeps the game's own step (#794)
cadd4be6 Display link: limit fullscreen latency 2 to variable-refresh screens (#822)
ba10db3d ci: install the selected Xcode's Metal toolchain
ffdf67de nvn: clear every layer of bound render targets (#808)
d2a86b05 tests: declare extracted AST functions as statements
aea257b9 nvn: preserve shader image writes from attachment stores (#730)
d76c45f7 Pin the supported toolchain to Xcode 27.2
4a1f6830 fs: close directories when handle allocation fails (#801)
f9eb12e1 save sync: close metadata streams after write failures (#830)
b8ffaf8b audren: validate command lists before capture diagnostics (#802)
c87bb116 Drain GPU completion temporaries on guest waiters (#818)
ecc41fa8 Restore Well Dweller's required GL profile tables (#825)
105f417b Select iOS pipeline archive GPUs from the game profile (#653)
bbc3b737 Add DRAGON QUEST I & II HD-2D Remake port
5474c6f3 Use the build's offline pipeline archive in benchmarks (#792)
63ef3272 Move AudioUnit diagnostics off the callback (#731)
6a787668 Recognize guarded zero-extended jump-table indices (#778)
ec9c3aa6 Restore Vorbis movie audio after Flush (#787)
78c14262 Make polling tests independent of CI scheduling (#779)
c5fe6b5d Find iOS DLC in Documents and replace stale content (#486)
3d247f35 Wait for Mac fullscreen readiness and retire startup retries (#665)
2716f78f Report stale shader caches through build events (#490)
4b5393e5 Show pipeline prebuild only when Metal 4 pipelines are enabled (#644)
89074294 Compile shared host shaders during builds
0b3fa7e7 Parallelize rewriter scans and keep worker controls safe (#761)
635e8008 Keep benchmark captures outside the measurement window (#754)
9508b934 NVN: fix attachment capacity and combined depth/stencil pairing (PR #738)
bfc70881 Specialize render function constants through Metal 4 pipelines
373cc820 tests: assert thread registration before reading poll backoffs
74e31944 Correct offline archive depth for seven confirmed profiles
f5cc73d0 nvn: honor buffer offsets and sizes written by guest ring allocators
1a9145ff Fix Echoes of Wisdom archive depth and detect profile mismatches
2aae9f8c Fix shared Python lint failures in Unreal engine-region rewriting
f11018a1 regress.py: variant reflections hashed without the chain stamps; manifests of the older hashing hashed again
bcb18804 Port Metroid Prime Remastered 1.0.0; little-endian RFRM forms read by the shader split, the pixel sample index and GLSLC's sample position table, and image stores kept under rasterizer discard
703acd69 Port Hyrule Warriors: Definitive Edition 1.0.1; SDK 3's movie::Decoder(type, format) taken over, short timed waits as polls
59df99e7 AudioOut Start / Stop / Close on the big host stack, game call site kept in the log (PR #721)
ef9f9bba Atmosphère cheat codes on the host, with a Mac Cheats panel and cheats carried across game updates (PR #406)
8c0b8083 Port DRAGON QUEST III HD-2D Remake 1.1.2; an Unreal pak key split into two 16-byte literals found in main's code (uepak.py code_keys)
2006d5ed Unreal's engine region given what the alias region has room for by the rewriter (ue_region.py); the 7 game_args rows and Pikmin 4's cut removed (issue #635)
48e8c66f Pokémon Legends: Z-A: depth_mode zero, so the pipeline bases made before the game runs are the ones it uses (GitHub issue #614)
6b0cffbb A cube texture in a slot declared 2D binds its first face as a 2D view
1cb10923 Port Atelier Ryza: Ever Darkness & the Secret Hideout DX 1.2.0; Gust's chunked zlib .gz files read by the shader split
d3f7433e nv::GetGraphicsMemoryInfo writes the record of the game's SDK: 0x20 bytes on SDK 10 and older (GitHub issue #708, PR #709)
f35fe86a NSP script: --work-dir sets the build folder; the IPA, the provisional profile and the NSZ conversions follow it (PR #475)
a5bf542f iOS: the game on a connected TV or monitor (cable or AirPlay), picture capped at 1080p (PR #367, GitHub issue #705)
6fe1927e hid::IsVibrationDeviceMounted answered by the host: mounted when the channel has an output (GitHub issue #715)
fe6d3dfa Bare lock acquires without a barrier made ldaxr by the rewriter: BotW 1.6.0 ran a job twice (issue #251, PR #562)
8bfc3a60 Native-texture movie slots kept until the client's release (GitHub issue #700)
b17bd8a8 Python lint ratchet green again: ue_cvar reads the name's add once, the test binds its loop variable
68db7956 CI coverage of the host, CPU texture and tool tests, with diff coverage per PR (PR #439)
a345f5b0 C and Objective-C lint in CI: a clang-tidy ratchet that only shrinks (PR #425)
195986fa Metal stop message says to select the tested Xcode before downloading its toolchain (GitHub issue #717)
e513bfeb regress.py runs the repository's profile, not a provisional one left in the build folder
602ed115 Unreal console variables found by name by the rewriter (ue_cvar.py); the 13 fixed frame-limit rows removed (issue #635)
6d880d23 GPUs without BC textures refused at start (GitHub issue #704)
51904e70 Unreal's FMallocBinned3 found engine-wide by the rewriter (ue_malloc.py); per-build cuts removed (issue #635)
1c3bbbcd Port Super Monkey Ball Banana Rumble 2.20; a stack region sized for its threads; multisample texture slots read as their own type
ee6648cb SDK rows of 5bcf525f, 2aef2cff and 60751516 removed: the SDK-wide rules give them the 2 MB alignment (issue #635)
fe9dd226 Port Pokémon Violet 1.0.0 as Scarlet's twin profile
db6bb87b IL2CPP address symbolizer: script.json method names bounded by the module's .eh_frame functions (PR #698)
af616f54 Dirty-page protection holds the pool-slot mutex from lookup to its last mprotect (PR #686)
eab25377 Present snapshots: the residency set committed before the copy; a replaced ring texture resident until the slot's next use (GitHub issue #626)
8b06fab7 NSP script: remove the shader libraries of older chain versions after a successful build (PR #682)
17f670a7 SDK-wide 2 MB alignment of large address regions, as SDK 20; locators fail closed; goal "unreviewed"; Gaps ordered by payoff (issue #635)
0c94284e DrawTexture reads the 32-bit handle word; capture layout says ops 53; four small host fixes (GitHub issue #687)
```

Follow docs/agents/07-upstream-maintenance.md before integrating. This workflow never advances integrated_head, bumps releases, signs, installs or merges the PR.
