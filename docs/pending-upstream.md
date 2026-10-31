# Pending upstream review

Pinned head: `63ef3272bcd19d864329cad3444dac6b75d7bef3`.

Manual conflict resolution required. No engine changes are staged in this proposal. Conflicts: .gitignore, AGENTS.md, README.md, dm/host/Makefile, dm/host/save_sync.c, dm/host/tests/Makefile, docs/development.md, docs/frontends.md, docs/settings.md

```text
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
