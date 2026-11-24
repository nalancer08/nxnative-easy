# Pending upstream review

Pinned head: `5dfc86ae80c53a62262c3b3c66eab043f1fc574a`.

Manual conflict resolution required. No engine changes are staged in this proposal. Conflicts: .github/workflows/tests.yml, README.md, dm/gfx/nvn/nvn_geometry.inc, dm/gfx/nvn/nvn_mtl.m, dm/gfx/tests/t_pfv.m, dm/gfx/tests/t_pso_archive.m, dm/gfx/tests/t_pso_bundle.m, dm/gfx/tests/t_pso_stall.m, dm/gfx/tests/t_res_commit.m, dm/gfx/tests/t_sparse_copy.m, dm/gfx/tests/t_upload_src.m, dm/gfx/tests/t_vk_swapchain_life.m, dm/gfx/tests/t_wline.m, dm/gfx/tests/t_zero_depth.m, dm/host/Makefile, dm/host/hle_audio.c, dm/host/hle_fs.c, dm/host/save_sync.c, dm/host/save_sync.h, dm/host/tests/Makefile, dm/host/tests/t_pollwait.c, dm/host/tests/t_save_sync.c, dm/ios/Sources/CloudSaves.h, dm/ios/Sources/CloudSaves.m, dm/ios/Sources/DmIOS-Bridging-Header.h, dm/ios/Sources/Launcher.swift, dm/ios/Sources/SaveSyncReport.swift, dm/ios/Sources/front_ios.m, dm/ios/Sources/main.m, dm/ios/tests/launcher_storage_check.swift, dm/mac/Launcher.swift, dm/mac/launcher.c, dm/mac/pack_app.py, dm/tools/impact_map.tsv, dm/tools/lint_c_baseline.tsv, dm/tools/nx_extract/Program.cs, dm/tools/nx_extract_bin/nx_extract, dm/tools/tests/test_nsp_mac.py, dm/tools/tests/test_nsp_mac_app.py, docs/agents/symptoms.md, docs/frontends.md, docs/reference/frame-rate.md, docs/reference/packing.md, docs/reference/services.md, docs/settings.md, scripts/build_ipa_from_nsp.py

```text
5dfc86ae game: port Apollo Justice: Ace Attorney Trilogy to Mac
288803ae packing/regions: make address region verdicts target-aware for Mac-only builds
d83c32ec opengl/shaders: add missing es profile on #version 310/320 (#3292)
551228c9 gfx/nvn, tools: honor acquire sync deadlines, fix movie texture handoff/aliases, zxnb reader table, nx_extract literal opens, and provisional marker reuse
fb3ca11a nvn/present: filter minified presents with a separable tent kernel
a0d1b2f6 nvn/tests: check pool-residency kernel lookup
953e8927 nvn/tests: check movie readback buffer allocation
2746806f packing/profile: type decoder archive scan results
c07a3cc5 chain/split: report invalid PACx LZ4 chunks
4be2de4a chain/split: share the zlib header check across archive readers
ba15f55d game: port XCOM 2 Collection to the Mac
9b2ee6c7 tools/packing: discover decoder-backed archives in DLC for Oodle host (PR #1403)
9e889a86 game: Captain Tsubasa 2 World Fighters defaults to 60 fps
bd3fc779 game: BioShock Remastered plays on the Mac + shadercache.nx reader (PR #3247)
69b618b3 host/threads: enforce Horizon SetThreadActivity and GetThreadContext3 rules
f5c5a823 host/web: end an offline HTML page that calls window.close() (PR #3262)
fb0a0d3b gl/sync: treat a GLsync as a name, not a pointer to read (PR #3282)
557f1954 host/threads: initialize yield and spin settings in svc_thread_main_init (PR #2031)
48bc8536 nvn/shaders: keep missing shader keys for the next partial build (PR #3288)
9f0aa547 nvn: resolve registered textures at pool slot zero (PR #3256)
b6336876 gfx/nvn: copy-on-write pool updates and cross-submission residency checks
2cc4cda2 packing/nup: scope provisional romfs_marker to the packed program
ffb06d60 nvn/textures: stage native-texture movie frames linearly for GPU blit
dcba0ba1 game: Captain Tsubasa 2 World Fighters on Mac
7972b110 packing/extract: preserve literal RomFS archive paths
af9b70ea host/uemalloc: preserve Unreal allocator RTTI
7e7e55fd nvn/rt: retire stalled acquire threads to standard policy (PR #3285)
be38b7da nvn/upscaler: retire evicted MetalFX scalers at their fence and evict LRU
4561f442 host/nvn: borrow shader library file mappings on macOS
e41e8a96 game: port Mortal Kombat 11
ed1cf496 packing/shaders: keep partial builds in the shared cache directory
be172acd nvn/sparse: track buffer-backed textures across run replacements
73150dd9 chain/atomic: keep float atomic adds out of the constant program
01439b0f gfx/nvn: recover interrupted archive captures during offline packaging
549324da host/input: read 8BitDo Ultimate 2 Wireless Bluetooth motion (#2997)
f708540f packing/mac-app: keep existing app icon on in-place rebuild (PR #3148)
2fcf7e8c opengl/shaders: strip legacy precision statements after preprocessing (PR #3269)
1cd57e6a gfx/nvn: add opt-in DM_NVN_ANISO surface-sampler anisotropy floor
2c0682e7 gfx/present: support DM_PICTURE_FIT=fill on Mac
900e11ca host/uemalloc: keep each thread's recently freed small blocks intact (PR #3265)
37512993 host/hid: route JoyDual vibration handles to FullKey and Handheld pads
8e0a772b host/mem: place thread stacks deterministically in the stack region
3f6b304d docs/readme: link the prewarm lists discussion
1f64cee7 game: port Story of Seasons: Friends of Mineral Town
67e67146 host/audren: clear renderer event on Update and remove catch-up queue (PR #3272)
002724b8 game: default Assassin's Creed III Remastered to 60 fps
e148dca9 host/audio: choose surround from the Mac device's speaker layout (PR #3264)
3b882993 nvn/vertex: declare slot 30 stride 32 for absent attributes (PR #3258)
110868ee nvn/queue: a wait on an in-flight write carries the writer's fence (PR #3276)
49aee453 game: add It Takes Two 1.0.3 profile (PR #3101)
fd4d1134 docs: refresh translator line links in the patch index
c2badd9f game: Assassin's Creed III Remastered reaches its Mac opening
5e907fb8 packing/forge: read Scimitar v27 shader archives
12e0a177 nvn/device: read older NVN minor versions from the SDK
f856c78d chain/tools: include vendored Ryujinx sources in xlate_source_sha
ca4ffed4 packing: read Unity shaders in CRI CPK archives
2f0210db chain/spirv: keep nested Else/If blocks for SPIR-V (PR #3253)
3e3e18fd games/010013C00E930000: offer 120 fps for Hollow Knight: Silksong (PR #2479)
7f015ff8 nvn/residency: release committed queue objects under g_res_commit_mu
208b699c ci/lint: fix NVN table growth and test diagnostics
44c5500c host/tests: supply the SDK probe in memory fixtures
c7e74a1f nvn/replay: cache view type and pixel format on treg_t, add bench.py submit metrics
4015ce2c gfx/nvn: keep resolution families compressed with valid-geometry tracking
39123f79 games/0100633007D48000: offer 120 fps for Hollow Knight (PR #2478)
c56ec4d7 host/memstat: add DM_MEMSTAT_WALK=<N> to throttle region walks
0293739d game: Guacamelee! 2 1.0.4 reaches its opening on Mac
2398cf78 gfx/tests: update pso_get callers and dual-source main0_u assertion
973f2d73 nvn/mtl: add opt-in bounded depth-write snapshot copies (DM_NVN_FB_DEPTH_RECT)
685d2aec gfx/nvn: Metal 4 mesh pipeline bases, mesh_pairs.tsv prebuild, and prefetch
61e97458 nvn/latch: gate on GPU deadline and exit on late GPU or skipped ticks
df20cc25 packing/shader_split: parse DrinkBox SHADERS containers (PR #2810)
4f4d23a8 gfx/nvn: read texture serials lock-free in passdump bind logging (PR #3245)
f3cbbd72 game: Shredder's Revenge 1.0.9 runs offline
fe138ad5 game: Oceanhorn 2 defaults to 60 fps
3bcf8213 gfx/tools: read MGFX v10 effects and raw-DEFLATE .zxnb assets (PR #2546)
d58f8a79 packing/uepak: read shared v8 shaders and port Oceanhorn 2
d18b4bc5 ios/tests: define DM_GAME_MEM_ALIAS in DuoHarness fixture
90edd532 ios/menu: accept localized labels for the in-game menu (PR #3057)
6724d64d host/audio_input: select and unmute matched DualSense USB mic
e22fe575 game: record Baba Is You IPA and Mac verification
d2939c1e packing/shaders: report post-compile phases through DMSH_PROGRESS (PR #2684)
410f0c9e gfx/tools: drop clock stamps from c1_full and cb_extent headers (PR #3172)
811091e7 packing/ue3: read wide chunks, small-window zlib, and control-first records (PR #2808)
62f65f70 host/audio: default Mac microphone gain to 1x and guard AUHAL render buffers
3f37dd3d host/album: save nn::album::SaveScreenshot buffers as local PNGs
a694f179 host/memory: default Switch 2 to 128 GB Mac alias and pool limit (PR #3188)
1ac47a87 host/loader: validate linked swforce table at build time (PR #2702)
de5b17e8 game: port Oceanhorn 1.0.1
63bfc863 game: Mario + Rabbids Kingdom Battle defaults to 60 fps
ba82ccb9 nvn, packing/shader_split: validate WriteTexels bounds and parse VFS2 archives (PR #2906)
bf8d4ade host/friends: open the notification queue offline (PR #3224)
bb576f18 game: Mario + Rabbids Sparks of Hope defaults to 60 fps
00f98d5d nvn/images: avoid relocking the registry for buffer writes
90fc507d ios/packing: use the selected Python via DM_PYTHON (PR #3219)
c58270ff tools/tests: type exec namespace in test_nso_match.py
b9a3364d host/nvn: guard edge-snapshot OOM and add crash/VA diagnostics
5205e2bb chain/build: narrow fu before concatenation in finish()
40d4091e mac/launcher: open Advanced settings with a button, not an empty DisclosureGroup (PR #3228)
65b1523b rewriter/spin, host/fpslock: clear decode cache per head; discover Frostbite frame regulator (PR #3234)
7d38c8e0 host/loader: restore iOS-only alias cuts on Mac (PR #3218)
cdd91f0a tools/regress: ignore Metal InstalledDir mount path in toolchain fingerprints (PR #3232)
ef8b25d2 nvn/vertex: supply default W=1.0 for absent attributes (PR #3237)
82cad791 host/fs: release cache storage mount names at Unmount (PR #3217)
0b09b66d nvn/replay: tighten fb_view serial check, pso_get_ return type and docs
019a1f69 game: Donkey Kong Bananza waits for translation on Layer 1400
5ccb82ad nvn/replay: drop per-draw retain/release in the draw helpers
a7821cfe nvn/geometry: set the mesh argument table only for a lone mesh draw
3a7e53d3 nvn/replay: cache same-pass feedback views
e49e4814 nvn/replay: walk only a shader's texture and buffer bindings per draw
c1bd080a nvn/replay: bind only the vertex streams the shader reads
a359f9e6 nvn/replay: look up pool addresses by 64 KB region first
c22289c0 packing/shader_split: unify Ubisoft Anvil and Scimitar forge readers (PR #3238)
15a67252 host/settings: preserve the legacy 15-language list (PR #3235)
38507975 gfx/tests: update t_missing_src1 and test_dmsh_logic for recent blend and build changes
c17a5498 gfx/nvn: defer acquire pacing and present-ticket wait to nvnSyncWait
c25a8670 chain/dual-source: move dual-source blending into main0_u and drop dual_want.tsv (PR #2736)
bd28b4c4 tools/docs_patches: scan game.header_one profile switches
b78d7e8e host/input: read unclaimed USB Xbox One (GIP) controllers on macOS (PR #2666)
ee63b843 packing/profiles: fix registered-update shader coverage and status; register Mario Kart World 1.8.0
e575e812 tools: document DM_NVN_SPARSE_COPY and fix pyright checks
9ad1670b game/010063100B2C2000: add Cytus α profile in handheld Normal mode (PR #2811)
cac1293b host: load exlaunch mod code plugins (PR #3178)
4add5fbb gfx/nvn: adopt newly prebuilt p*.mtl4a archives before frame 0
3e8f1ce5 host/haptics: drive 8BitDo Ultimate 2 Wireless through HID report 0x05 (PR #2763)
be3b8bf8 host/mac: automatic passive HID stick fallback for Switch Pro Controllers
2fc4e70a chain/nvn: pool runtime-selected NVN2 storage images
7153c4fe game/0400A3A01EE4C000: add 14 later-session Pokopia shaders to shader_seen.tsv (PR #1892)
48781edc nvn/chain: sparse misaligned shadows, bounded c[0] storage buffers, and Anvil shader split (PR #3126)
4066c402 game/0400A3A01EE4C000: add 5 Pokopia Pokedex and world shaders to shader_seen.tsv (PR #3171)
85b222bb games/010099801C4FA000: add Peace Walker Master Collection profiles and render-thread sync fix
e8460ebc tools/cheat_anchor: bound .bss by the module's end, not the loaded image
7130d4db host/oe: pick default language from control.nacp when DM_LANG is unset
d9a70339 chain/split: read the shaders of Monolith's DMPA model packages and NDSR packs (PR #3135)
5fc927d5 nvn/fstep: 40 fps in ticks of 1/120 s (Ocarina of Time)
24346dac games/01008CB0156BC000: target 60 fps in Trails into Reverie
3a2a62f7 gfx/nvn: clear relaxed draw-pass barrier state on NVN queue switch
3cf75061 gfx/dmsh: specialize the blend fix-up away when both blend words are 0 (PR #3176)
dc75d1fc host/hid: fix handle metadata and bring up Trails into Reverie
3d186f2b nvn/present: put a retried display link on probation
dbefe889 games/0400486024DEC000: update sead::PerspectiveProjection in place for Vert+ screen shape
610baa4d gfx/shaders: build mesh libraries for every shader variation's geometry pair (PR #3191)
54c602f2 game: BRAVELY DEFAULT II defaults to 60 fps
033793f0 chain/vertex: share dm_vs_body_o with capture entry main0_gs (PR #3186)
1ed3e12a chain/atomics: translate RED.ADD.F16x2, the half-pair atomic add (PR #3200)
184847c5 host/gates: grow the dispatch index during module preload (PR #3121)
8d888054 host/nvn: freeze guest clock and park clock reads during prepare and archive open
12c98ed0 ci/tests: supply Xcode fixture capture-table paths
fbee62f1 ci/tests: account for Ocarina render-scale hooks
9c2ad512 ci/opengl: size uniform readback buffers for matrices
8cc63cc9 packing/shaders: accept mutable NXSH input
65dfeb33 rewriter/layout: preserve read-only jump table offsets
b2d41ac5 host/audren: leave explicit CPU/manual renderers to the game (issue #3212)
1a1d5124 game: port BRAVELY DEFAULT II 1.0.0
388befdf ios/rotation: add Rotation setting (DM_ROTATION) to launcher and in-game menu
f75a85aa opengl/shaders: promote desktop GLSL 1.10-1.30, honor layout(binding) and swizzle, and recover GL capture
3f852b8c ci/coverage: install SPIRV-Tools for Vulkan tests
36c09285 host/haptics: drive Switch Pro Controllers through their HD rumble report (PR #2607)
7ff0aef4 gfx/nvn: publish coherent presentation-time and display-link history snapshots (PR #2194)
acbb26c3 chain/meshstage: spill task payloads past Metal's 16 KB through a device buffer (PR #2264)
58272b4a ci/lint: fix FFT replay and matcher test typing
d08d7da6 gfx/nvn: trim on memory pressure and evict idle spares and uploaded textures
c36551c3 host/front_mac: guard fullscreen mode switches against re-entry and bounces, and settle before display link
ef393b7e games/pragmata: reserve a 40 GiB iOS alias region and note the entitlement on failure
6ef18a1f nvn/fstep: ignore pauses and window switches for hold steps and payback (PR #3174)
3dd1f7a6 gfx/nvn: keep CPU_NO_ACCESS texture pools out of gmem_map and chunk from 256 MB
e3f2d21f chain/shader_lib: clean up partial outputs and stop cleanly on a full drive (PR #2610)
b3d287fe games/0400486024DEC000: support launcher Render scale (DM_RENDER_SCALE)
38a787a0 host/save-sync: ask before sending over a missing cloud save (PR #3197)
e531be81 tools/regress: run each revision's pso_offline.py in its own process (PR #3190)
3c4e06aa game: port Ultra Street Fighter II 1.1.1
9143b6ff nvn: keep shader-code pools out of gmem_map, pre-wire guest files, and pace late 30 fps frames (PR #1971)
5e098c8c rewriter/fft: match job-pool wake-up stub across updates
a95c91f4 game/digimon: select 60 fps in Time Stranger startup
977f5cab host/friends: hook blocked-user availability, no-Uid forms, and cut-object methods
b3e0d8c5 packing/uepak: use raw size for single-block Unreal pak entries
a3d58526 gfx/nvn: verify kernel writability before claiming PG_NONE faults
c12000da games/ocarina: scale dynamic-resolution threshold to target fps (PR #1954)
930e9195 packing/shader_split: read Falcom .pkg/.pka archives and Phyre RYHP GLSLC shaders
b768913f host/streamplay: serve the supported HID feature query (PR #3162)
c5d9c7eb ci/lint: restore the C and Objective-C lint ratchet
fa59a0a7 gfx/nvn: resolve mismatched-size MSAA Downsample and add Time Stranger profile
131bd013 packing/shader_split: read wide MVGL archives and NXVS/NXFS/NXCS containers
22222648 packing/unreal: decode Zstandard pak blocks directly
602ad87d game: FINAL FANTASY VIII Remastered runs on Mac (PR #3139)
17454fc3 rewriter/layout: give module data a 16 KB page of its own (PR #3138)
0cf3a702 nvn/geometry: order deferred updates before mesh-stage buffer use (PR #3120)
da242230 nvn/textures: partition packaged-texture and CPU-written tables by pool
194da5fb nvn/submit: track segment commits with shared event and encode-thread gating
a67583a4 nvn/gw: make running-write tables set-associative and grow sbw
b4588a53 nvn/vconv: index cached index ranges by page for GPU write invalidation
ae7c1023 host/mac: revert fullscreen hard-hide of the menu bar (PR #2850)
a41f0270 host/codec: queue registered video decoder buffers until filled
d294f3a5 rewriter: fix Pikmin 4 cutscene fade timing
cb126758 docs/pragmata: record the iPhone startup and memory results
15f8f6fb docs/ocarina: document the Xcode install fallback
983a9ab2 docs/frame-rate: record fixed-rate fullscreen stutter
74c9fd7c docs/playing: explain Xbox button remapping on Mac
73f23d41 docs: clarify game build and reporting instructions
584b10a9 docs/games: list frame-rate targets and modes
0c39549c docs/nba-2k26: record the player lighting prototype
90dab9b8 docs/rendering: record an iPhone residency commit freeze
6e12b9f8 docs/ocarina: record Saria cutscene GPU hang tests
32ff5eef docs/ocarina: document save fields and live game data
22d84b12 docs: record Ocarina of Time peak-memory diagnosis
f41613f7 packing/shaders: keep registered sources across RomFS files
c8d312c0 docs/ocarina: record base M4 and M1 Max benchmarks
692c8047 docs/games: record Mario Kart World and base M4 Ocarina results
5b315037 docs: list nxnative Easy and record an iPhone archive rejection
6dc27632 chain/mesh: pass subgroup inputs by value (PR #3169)
4cc27d10 ci/tests: update SDK patch and NVN opcode checks
a706ddef docs/ocarina: record debugging and save findings
d0556e77 docs/guides: correct CI Xcode and Pro Controller gyro guidance
930fbff2 nvn/mem: keep sparse memory reports in long sessions
74c9b1fd opengl/framebuffer: honor sRGB conversion on the window
6c50d74e host/svc: release unmapped stack pages (PR #2720)
54569e82 nvn/present: honor an explicit display link at 30 fps (PR #2730)
de348580 nvn/pso: drain autoreleases after each background build (PR #2714)
f76fe0c1 game/factorio: port Factorio 2.0.76
a6c4f687 game: default Hitman Absolution to 60 fps
25ef427e host/gl: implement glGetShaderSource, exact NACP display version, and Fate/hollow ataraxia profile
d69a37c5 opengl/shaders: expose only active default uniforms
806fabe1 host/svc: make native SDK module enumeration work (PR #3023)
656f8844 host/offline: register friend-ID and network Result hooks (PR #3119)
75a588f5 opengl/framebuffer: honor sRGB conversion state (PR #3117)
3e1ada5b nvn/texture: check dimensions before making linear views (PR #2908)
1364b89a host/prepo: report idle transmission offline (PR #2908)
a63ca651 packing/shader_split: read NXSD shader containers (PR #2706)
47578ded game: Ocarina of Time renders taller screens natively (PR #3037)
6b5c177d docs: update the NxNative Launcher links (PR #2994)
ded77fda docs: sort the depth bounds environment switch
5b7dad03 gfx/nvn: depth bounds test on Apple10+ GPUs, for NVN and Vulkan
cddba4e9 game: default South Park to 60 fps
79555b67 nvn/vertex: bind the mapped bytes of indexed draws
e74c3fa7 game: South Park: The Fractured But Whole runs on Mac (PR #843)
c96c45e9 nvn/vertex: bind the mapped bytes a draw reads
294572de docs: list two packing environment switches
9a3eb02e host/audio: make callback bounds and test timing explicit
fdfbaf9d packing/romfs: keep resource staging compatible with Python 3.9
953c5a90 chain/build: make shader output modes explicit
67736c99 game: South Park: The Stick of Truth runs at 60 fps
1487bca8 game: Star Fox prewarms the tutorial ring course
fc09c9bc game: South Park: The Stick of Truth runs on Mac
072cb3fd packing/nup: accept explicit DLC image directories (PR #2905)
f7ae8a3a game: Ocarina of Time increases the alias region to 8 GiB
16608f83 docs: record Kakarot's iPhone playtest
88360118 game: EA SPORTS FC 27 PRMT shaders build without warnings
8b966e2a game: Persona 5 Royal uses near-zero archive depth (PR #2880)
098f76ab game: Star Fox builds its archive for near-zero depth (PR #2882)
246b4b08 game: Donkey Kong Bananza document M4 iPad signing
ae5d8f51 packing/shaders: recover shaders compiled during play (PR #2869)
ff18e88a nvn/texture: retain CPU upload data when it is recorded
33b0cf51 chain/maxwell: implement PRMT byte permutations (PR #3072)
ad0115fa packing/uepak: read untagged Unreal shader archives (PR #3022)
2e6f6fd0 chain/vertex: lower draw-uniform viewport masks (PR #3074)
4381b10c host/hid: expose whole pads as single Joy-Cons (PR #3086)
d7191d83 game: DRAGON BALL Z: KAKAROT support for update 1.70
f9e00f44 mac: start the game activity once
e8ab5f35 host/input: use the Taiko Drum's HID button map (PR #3061)
da63a9ee rewriter/engine: repair Unity 2018 stream buffer wakeups
67ba927a nvn/ctl: retire bufsnap buffers after writing the file (PR #2865)
1f03e2fd nvn/owner: log texture sharing allocation failure (PR #2883)
b061578e nvn/mem: handle vertex cache edge allocation failure (PR #2883)
71a9a829 host/svc: start guest-file watcher after memory setup (PR #2870)
d1d126e3 host/movie: fence deferred video output across Flush (PR #3073)
6d0ee04a nvn/sparse: honor descriptor lifetime in mapping scans (PR #3091)
9b03dee5 game: Nintendo Switch Sports Resort refreshes its shader map
db970cc0 game: Splatoon Raiders refreshes its BAHS shader map
c9b12271 packing/shaders: preserve verified registered duplicate sources
4c278799 vulkan: clarify descriptor generation cache checks
f539b2dc nvn/pso: defer timed archive writes during play (PR #3060)
7d3d893b ios/cloud-saves: balance the selected folder security scope
6aaf73ba packing/shader_split: decode zstd frames in process (PR #3002)
588a5d72 packing/shader_split: share archive probes (PR #3002)
caccf926 chain: compile the Mac shaders in Metal's relaxed math mode
3ec5b785 chain/ampere: preserve runtime per-texel gather offsets (PR #2831)
e30aca5e host/audio: recover from stalls after an output route change
dd19334e opengl: silence unsupported fixed-function disables (PR #2995)
a1a81f7e packing/nup: normalize shifted metadata and validate NACP size
d2fd78b4 gfx/tests: supply shader functions to the pending PSO fixture
18a96b32 mac: keep the menu bar off fullscreen games (PR #2850)
c4f12d24 nvn/residency: retire upload staging off Metal feedback (PR #2868)
6df16dbe nvn/suspend: bound the graphics wait on backgrounding (PR #2864)
8e06d235 nvn/sampler: model the reserved pool slot zero (#3049)
8997e195 ci/checks: fix lint and test failures on main
742e959e packing/nup: prefer the selected build's display version
78bd42b9 host/vi: share Switch 2 display resolution tiers
9df3c09f nvn/compute: keep NDVE running after compiler death (#2920)
f3f73320 packing/nup: preserve selected package display versions
2e86b714 host/audio: stage short AudioOut tails for large callbacks (PR #2989)
040c3ae4 packing/nup: inherit missing update icons from the base game
8c94bd1e host/nvn: release shader library file mappings after loading
75863bdd host/time: avoid false clock changes across restarts (PR #3065)
5588e99d nvn/queue: replay completed submission nodes while copying
99224562 textures: reuse the row copier for sparse tile uploads (PR #3052)
d0824312 nvn/pipeline: reject missing required render functions
fdbb359d host/hid: keep stick diagonals within the Switch radius (PR #3053)
72e81a32 packing/tables: avoid redundant shader scans (PR #3001)
32fe34ef chain/mesh: keep subgroup helpers out of line (PR #3069)
6fc64d8a games/witcher3: add opt-in histogram ordering repair
e59c910a nvn/bind: keep vertex stage when binding non-vertex graphics programs with 0x1f (PR #3055)
2edad182 host/audren: give the audio producer a real-time deadline
ff2d3efe game: add FIFA 23 Legacy Edition profile (PR #1696)
a3e25ed4 nvn/dispatch: skip empty direct grids (PR #1696)
bbacc45c nvn/residency: retain placed texture parents (PR #1696)
81e22cca nvn/views: compose nested view offsets (PR #1696)
c9aceb29 nvn/copy: store compressed IMAGE copies in guest storage
4508f894 host/oe: handle crash-report switches (PR #1696)
cb6eb28b packing/easf: read EA shader archives (PR #1696)
acd6bd02 host/loader: run module initializers dependencies first
fa549e08 nvn/present: complete startup display-link rescue (PR #3004)
74abcae5 games/vanillaware: refresh checked shader representatives
981161a3 game: Pokémon Legends: Arceus refreshes its shader map
34fa4691 host/movie: re-arm deferred video output events
c9ef5e74 game: Sonic Frontiers Definitive Edition refreshes its shader map
c43a1f7a game: FINAL FANTASY XII refreshes its shader map (PR #3016)
3b7580bc game: Pikmin 4 refreshes its shader map (PR #2992)
82367f3f game: Persona 5 Strikers keeps patch labels private (PR #3054)
c075ab26 game: Ocarina of Time refreshes its BAHS shader map (PR #3010)
7ebb76ed game: run Skywalker Saga at 60 fps by default
733ecb83 vulkan/clears: honor partial attachment rectangles
d43d4355 game: Skywalker Saga 1.10.0 plays on the Mac
ce41059a nvn/blend: write source-only float blends directly
d43a3790 nvn/image: bind integer buffer storage through float views
5cd38d39 packing/ttdat: decode DFLT add-on shader members
8a06d255 game: correct Minecraft graphics mode reachability
57174ec5 game: Minecraft records the ForwardPBR capability gate
7b9c59b9 vulkan/shaders: load complete resource tables
f3950c50 packing/sharc: read GIANTS shader archives (PR #1962)
220bbc0e game: Twelve Minutes fits its uncapped allocator (PR #2947)
aae41c11 opengl: compile missing shaders during capture
b526a50b vulkan/shaders: repair RenderDragon bone inputs before translation
ee998ae6 game/sam-max: seed validated opening pipelines
04e3a49b opengl: support legacy GLSL and FNA rendering (PR #1864)
5c198742 rewriter: preserve 32-bit bounds across guard refinement (PR #1864)
c714bb92 engine/telltale: read archives and add provisional Sam & Max profile
66f51684 vulkan: lower passthrough geometry viewport selection
905de42a vulkan: support Minecraft 1.26.62 RenderDragon on Mac
81f8e8ce rewriter: distribute branch hops between reachable patch areas
14f54e4c vulkan: implement ordered replay and compute for Re:ZERO
130ef293 game: L.A. Noire 1.2 runs on the Mac
b95a6b24 nvn/present: wait for the frame producer before screenshots (PR #2805)
80075911 vulkan/tools: detect loader-only games and translate DXC shaders
2149d856 host/irs: match disconnected processor control replies
46c67335 opengl: draw with the legacy fixed pipeline (PR #2805)
92a61243 game: Bloodstained: Ritual of the Night defaults to 60 fps
0ec204f5 game: add the TSUKIHIME 1.0.2 profile
79868f86 host/irs: accept valid processor starts with a disconnected camera
950212b9 nvn/texture: track CPU writes to sparse-layout textures
087faba9 host/irs: validate the clustering camera handle and gain
a018d6a7 game/persona5strikers: select native 60 Hz timing
6c24c65c docs/shaders: record the Bloodstained full split
19c5379d packing/shader_split: read RAGE WAD shader arrays (PR #2861)
2cc128ac host/irs: serve disconnected IR cameras to direct clients
6c554b56 game: add the Persona 5 Strikers 1.0.0 profile
9f4c3c57 game: add Bloodstained: Curse of the Moon 2 1.3.2
cd0cf744 game: add Bloodstained: Curse of the Moon 1.1.1
637f1dfe packing/uepak: read short v8 paks and v1 shader archives
34ace8cc game: default Persona 5 Tactica to 60 fps
8fa1b0c1 game: add the Persona 5 Tactica 1.1.0 profile
e689cb71 game: add the SNES Classics 6.0.0 profile (PR #2165)
09af1a6b ci: make the mock audio route channel count atomic
58e709bc ci: reuse the compiled launcher in Mac app tests
57ecdf85 ci: account for launch QoS clamps in the task-role test
760c7fe8 packing/shaders: validate PACx 403 root table bounds
c70c242d ci: repair host and tool test failures on main
56371f8b game: Resident Evil plays on the Mac (PR #2894)
c931e584 packing/shader_split: read MT Framework ARC v9 / headed SPK (PR #2894)
9f834e41 packing/shader_split: extract TT Games DAT and executable shaders (PR #2785)
f35ebba7 game: add Wonder Switch 2 Edition Program 1 (PR #2957)
d5e6a529 game: run Borderlands at 60 fps by default
8d44bd6a rewriter/catherine: enable the game's 60 fps mode
02614c26 chain: read padded UE3 packages and paired vertex constants
a6aaf66d opengl: implement active attribute queries after linking (PR #2322)
f07b1dba packing/gl: discover managed loaders and standalone shaders (PR #2322)
a67c884f docs/mkw: record v0 duplicate shader control checks
c311523c chain/rewrite: skip impossible guard scan positions (PR #2970)
a4c82979 game: add The Witcher 3 and its REDengine shader cache readers
e0c30043 packing/shader_split: read UbiArt IPK v5 archives (PR #2976)
54e57a7c packing/shaders: refresh Mario Kart World v0 map
b989137a chain/vertex: compile shader variants together (PR #2951)
31fdefeb nvn/upload: bound zero-copy sources per batch on opt-in
1d1c5b4a nvn/clears: fit zero fills in the shared buffer
943a6111 nvn/heaps: cap render-target recycle slack at 4 MiB
93c76c1c nvn/upload: trim completed idle staging on opt-in (PR #1491)
538da5d9 host/threads: keep replay clock out of relative waits (PR #2027)
4815cbbf ios/staging: clone changed resource images on rebuild (PR #2949)
18617ba3 packing/shaders: refresh the Smash Ultimate 13.0.5 map
4b92e232 host/hid: read Npad style under the bind lock (PR #2878)
3d8fc824 ios: apply the saved Metal HUD choice before UIKit (PR #1966)
398fc046 packing/survey: skip AppleDouble NRO sidecars (PR #1667)
ac3fc4d7 packing/mac: preserve shader image names (PR #1790)
51d804cd opengl/tests: compare RGBA32F upload values directly
e22744db tools/fonts: accept TrueType collections as sources (PR #2845)
74d17535 nvn/geometry: check live mesh argument addresses (PR #2938)
ce152fd2 docs/mkw: record driver and vehicle pipeline prewarm
79ac8c89 host/settings: support Polish and Thai (PR #1508)
7dacea9c opengl/textures: unpack 32-bit packed pixels by word (PR #1224)
99074948 docs/mkw: trace the Grand Prix race-entry hitch
985ea6cf ios/input: route lone Joy-Cons through GameController live input
0b5fd602 rewriter: avoid guest stack spills for x18 conditional selects
7493ce8c packing/shaders: refresh Fortune's Weave and Z-A maps (PR #2948)
831b22bb docs/mkw: record cold pipeline rerun on main
c84297cf host/movie: report NV12 keys for the loaded movie SDK (PR #2955)
501df0e2 opengl/textures: expand RED and RG uploads (PR #2955)
5df3dbe8 packing/shaders: reject stray BAHS descriptors (PR #2943)
e7dc2d9a host/account: return cancellation for offline network accounts
8da8081e game: Orbitals packs with the checked first-copy shader map
79f28b06 host/audren: pace burst refills and preserve PCM order (PR #2983)
48f6bd3b nvn/tests: stop swizzle image case when texture setup fails
b83913bc host/codec: forward C Opus calls on C++ decoder objects (PR #2974)
8da15b21 lint/c: clear geometry and haptics ratchet failures
cf4ff071 docs/mkw: record cold pipeline benchmark
736a2ecb chain/gmem: shorten raw load pool checks (PR #1833)
c48a98d5 host/input: select the Steam Link Xbox 360 HID layout (PR #2958)
5012821e nvn/pso: keep texture resolution out of pipeline lookahead
313f226c nvn/tests: use the wait counter in geometry replay
42d02fa8 packing/shaders: refresh Wonder and Mario Tennis Fever maps
5d101030 nvn/mdx: invalidate indirect masks after primitive barriers (PR #2945)
66cd8d8c host/input: restore left in the raw HID hat table (PR #2933)
a3663659 chain/ampere: translate VABSDIFF (PR #2053)
31b537f1 packing/uepak: read version 9 frozen pak indices (PR #2476)
2dacca8d chain/ampere: translate IDP dot products (PR #2052)
3984f5aa nvn/present: clamp early acquire lateness to zero (PR #1041)
c25d4011 host/audio: capture opt-in Mac microphone streams (PR #1822)
c379a903 chain/f2fp: honor packing modifiers (PR #2046)
64a1b8f6 nvn/present: hold queued frames by display link ticks (PR #1045)
6a4e3215 chain/i2f: round 64-bit inputs once (PR #2045)
c22f30a3 chain/rounding: honor directed f32 arithmetic (PR #2051)
3443d482 nvn/mtl: attach only existing residency sets
50bdfe87 chain/minmax: preserve NVIDIA signed-zero ordering
cd8c97e4 nvn/render: track color stores with the draw write mask (PR #2771)
4f4bfb6a nvn/mtl: serialize shared Metal initialization
4df29405 nvn/textures: borrow replay lookup results (PR #1473)
be4c103c chain/ampere: round packed HFMA2 once to half
50bb4ba1 mac: set the default task role for windowless games (PR #2876)
efd1bddd nvn/textures: cache Metal texture conformance per thread (PR #1467)
461a5f9f chain/rewrite: skip source scans that cannot match
a3e5ec1e nvn/texture: use the owning device's GOB order (PR #1257)
083c5e4f chain: promote read-only fragment storage buffers (PR #2889)
391c68f9 chain/ampere: translate HFMA2.MMA and preserve RELU NaNs (PR #2049)
a739027a nvn: continue render passes across independent depth and stencil use
631ceb39 host/threads: notify same-core handoffs when peers block
6212f018 chain/spirv: compare proven uniform bounds by row
eaf327a7 nvn/compute: honor guest barriers for unknown ranges
30d89215 nvn/mtl: merge face-split draws with independent accesses
2a67900b nvn/queue: grow command buffers geometrically
5ca161f2 nvn/pso: normalize NVN2 mesh stages during prewarm
2ddea510 nvn/queue: read replay timing through the pthread port
5916c3b5 nvn/mtl: scan compact binds when merging render slices
e4b0d9b7 packing/extract: reject truncated PFS0 payloads (PR #2122)
f15d6585 nvn: discover raw pointer pools at binding time
376adca5 packing: tolerate optional base lookup failures (PR #2701)
7124b0ad host/movie: recover invalid VideoToolbox sessions (PR #2877)
e27effd5 packing/ipa: resolve entitlement paths from the caller (PR #2698)
0bd40f9f chain/ampere: flush half subnormals for FTZ (PR #2048)
bd072733 chain/spirv-cross: preserve ordered not-equal in MSL (PR #2042)
44661163 mac/input: threshold controller triggers (PR #2504)
fb18e83a chain: mask register SHFL lanes (PR #2044)
e953b5b8 host/haptics: preserve Joy-Con actuator routing (PR #2472)
0afeb5b8 vulkan/clear: interpret values by attachment format (PR #2450)
6dbccfc9 nvn: treat an empty DM_NVN_TSV as off (PR #2733)
3f54c610 host/sf: serve mnpp:app offline (PR #2164)
8f51289d nvn: retain viewport recording origin (PR #1763)
fa2ed14d nvn: publish buffer flushes and preserve API contracts (PR #1285)
1af88aad host/audio: preserve surround across output route changes
607a5329 packing/heap-check: preserve the pool while capping StandardAllocator
a2c731e3 nvn/dirty: preserve first-match range lookups (PR #1227)
c4c1ffda gfx/shaders: keep raw searches inline in final mesh stages
cc7a9df5 host/friends: hook play history key without a Uid (PR #2162)
2925d7af games/dream-buffet: order dependent module initialization
bf93977b nvn: accept small guest command-memory grants (PR #826)
fbf08e7b rewriter: accept NOP padding after pointer tail calls
760ef393 game/ocarina: record GPU hang regression isolation
db07cbde game: Tropical Freeze refreshes stale SNVN shader tables
82c354b0 gfx/shaders: verify representatives and refresh two profiles
23427a7b nvn: order texture uploads after buffer copies (PR #2919)
3fe574df nvn/arena: share submission tails and retire idle blocks (PR #2862)
015fed3a nvn/pipelines: persist demand before background compilation
1db4bcb2 nvn/dlss: preserve alpha through MetalFX (PR #2898)
9bd8bb38 nvn/archive: discard periods after compiler death (PR #2901)
b04c42b0 host/fs: propagate child failures before parent cleanup
42c91e1c host/tests: drive HID timers with synthetic deadlines
2a3c453a ci/opengl: separate hardware rendering from CPU checks
87d3a47a chain/control-flow: preserve constant jump-entry conditions
97a19f21 nvn: express the fill pattern buffer size in KiB
a710f08d tools/abi: include the ray-tracing reflection writer
3f7fd466 nvn/tests: pass pool ownership metadata in feedback fixtures
20b59b6e nvn: bind logic state for typed-output shaders (issue #928)
e99583c9 gfx/shaders: refresh duplicate maps and bound NVN2 stage reads
60896b35 host/friends: accept offline presence (PR #2903)
bb574c70 chain/compute: contain runaway loops and report capped kernels
233e68b8 game: Cozy Land profile with matching pipeline depth (PR #2167)
b3fe7770 nvn: preserve live BUFFER source ordering (issue #2247)
a2b819fd game: track Minecraft Dungeons II account validation (PR #2846)
9e6acda6 host/account: persist users and offer explicit selection (PR #2846)
48808752 host/movie: order AVC output by codec buffer occupancy (PR #2166)
1467219c host/motion: qualify controller gyro reports (PR #1877)
e3230cc1 host/hid: keep vibration capabilities valid before routing (PR #2859)
1073e98b nvn/args: an arena allocation returns its own addresses
f3e53afe game: Donkey Kong Bananza record submission-copy measurement limits
b2e52b37 host/input: verify GameController delivery for virtual pads
0c134641 packing/ios: allow profiles without prewarm seeds (PR #1706)
f67a9e88 nvn: guard private buffer CPU-access fallbacks (PR #2230)
47c210f1 tools/bug_report: preserve redaction across log cuts (PR #2325)
d6585a2d nvn/pool: a patched pool table takes a finished spare of its own and the logged entries, not a whole copy (PR #2663)
19d159c0 chain/rewrite: preserve float-add loop retry flags
854a5967 nvn/tests: fix fixtures rejected by C lint
422ec240 packing/pso: bundle prewarm pipelines in IPAs (PR #2674)
d6bb5894 nvn/timestamps: NVN2 counter reports record nanoseconds
4cda80ea docs/rendering: the cached-view entry's check names DM_NVN_RT_RECLAIM as never on main
1015aedf nvn/latch: keep the drain's early-present rule inside the latch's wait (PR #2757 review)
b7e4b982 docs/env_switches: rows for DM_GL_RENDERPROGS and DM_NVN_UNBIND_DEFER
1b3ff73e docs: measure corrected prediction against current main (PR #2677)
d664d317 nvn/textures: inspect each overlapping alias once (PR #2677)
c3efaa90 host/gs: answer the application GPU scheduling time query
8d62601f nvn/raytracing: run Welcome Tour's native ray modules on Metal
24e007be nvn/pso: admit archives within the task's address space
edc7eff9 nvn/pipelines: wait for archive lookup completion (PR #2770)
9d3a5836 nvn/pipelines: look up predicted bases in background (PR #2677)
44d67fbe nvn/args: preserve GPU addresses across arena rollover (PR #2847)
60284e79 gfx/nvn: the display-link callback latches the present of the acquire it woke (#2648, PR #2757)
be46dc4c host/registration: declare contiguous linker tables (PR #2856)
9d316360 ci/tests: document the CPU graphics target list (PR #2856)
7f62966a host/tests: pass complete SVC register frames (PR #2856)
913fe496 gfx/tests: run t_refl's real-shader cases from inline fixtures
87422462 nvn: decouple handle checks from unbind deferral
6c079578 docs/rendering: document the EGL single-context limit
9537d92f opengl: bind shader resources through argument buffers
d6b5fc1b nvn: continue passes across redundant target unbinds (#2806)
5d54b885 opengl: preserve validation, context ownership and clear semantics
2d601a4d packing: reuse unchanged build inputs safely (PR #2820)
02789106 tools/tests: the solver bounds 1- and 2-entry tables masked before a bit test (#2562)
aca80c31 host/input: read DualShock 4 Bluetooth motion (PR #2087)
b396df3a host/input: handle Nintendo HID protocol and fallback (PR #989)
ba9ce212 gl/shaders: a GLSL ES 1.00 name that later GLSL takes is renamed for the compile and given back in the table rows (#2818, PR #2819)
58ab54a5 gl/loader: extension names by the registry's aliases, EGL's current binding per thread, and the GL calls Fate/hollow ataraxia REMASTERED makes (#2818, PR #2819)
bf1e4edd nvn/blend: bind the blend words under the draw's map (PR #2463, #2329)
d92b54da nvn/tests: validate storage-pair readbacks and compare sample values
5cb0806b host/time: run the SDK's UTC localtime and mktime, not host local time
25cb950e host/nsd: answer the server environment type without the nsd service (PR #1199)
27ae7736 games/typed-outputs: the six profiles' hand-written integer output rows go; main0_u serves those shaders
80ad3e7a nvn/tests: check census capture I/O and close failed captures
9423f7db nvn/tests: check the lazy-clear readback allocation
4619a14d nvn/owner: document the pool index's retained set for clang-tidy
17ab7888 opengl/uniforms: require a buffer before returning its Metal storage
c75f0126 chain/typed-outputs: every pixel shader gets main0_u, typed per target with the alpha test and logic operation in it (#2760, PR #2807)
d1b58260 games/metro-2033-redux: add Metro 2033 Redux's profile and note (PR #2743)
89e00cda nvn/alias: clears, CPU uploads and late-made sides reach a compressed-alias pair's other side
c8744e4f ios: report the game screen's frame rate, so 120 fps can run on ProMotion (PR #2792)
2acc593b nvn/pend: index large queued writes by granule, with no limit on their count (PR #2801)
3d795fec nvn/alias: a compressed texture and its uncompressed alias stay equal through every GPU write (PR #2802)
d941a6dc host/movie: the SDK's own graphics allocator setter runs, native textures need no byte capacity, Flush resets audio history (PR #2798)
c25315f5 nvn/textures: a 4-sample target and the single-sample image over its pool bytes share one heap, whichever is made first (PR #2789)
2da2c145 chain/ldc: a lone LDC immediate is the address; beside a register it stays signed (PR #2800)
3ce43e2a games/ocarina-of-time: held submissions do not raise memory at an area load on the iPhone 17
d8cfcf27 nvn/census: a census with no texture of its own says so, and t_rt_recycle runs the census
fa20b6a1 games/mmlc: add Mega Man Legacy Collection's profile and note, with the audio, GL and shader fixes it needs
8b830abb nvn/census: mem_census retains the textures it reads
13c35e90 nvn/owner: a memory pool's Finalize ends every texture made on its storage, so a texture object finalized after its pool no longer keeps the pool's memory
8950f2ea tools/rewriter: prove jump tables by dataflow over each function (#2562)
84e63860 host/account: GetUserId copies the Uid of any handle, as the SDK does
e6a358f5 gl/textures: GL_TEXTURE_LOD_BIAS is the sampler's lodBias
6dad3406 chain: MSL 3.2 for every shader, so a BAR.SYNC after a MEMBAR is kept
85897523 games/doom3: add DOOM 3's profile and note, with the GL calls and the run-time shader capture it needs
c3afe786 nvn/clears: every pass takes the waiting lazy clears, not only a draw's (PR #2780)
0de2ac2e nvn/vis: draws count for occlusion queries only while a later report can see them (PR #2574)
a0cad7e0 tools/env_switches: enum constants are no switches either
52ca101d packing/nup: pack one program of a Switch 2 Edition NUP, with the others' RomFS beside it (PR #2692)
33c734f6 lint/c: the clang-tidy ratchet passes again: seven new findings fixed, the baseline shrunk to 188
cb994686 gl/textures: upload compressed 2D arrays (PR #2704)
b4b1c8d7 packing/shader_split: read Phyre shaders from split KIT archives (PR #1939)
c8c58e6c chain/pull: pulling libraries read NVN2's attributes 16-31
e5e6b9cb gfx/tests: t_vk_desc watches a plain object for the pipeline's depth-stencil release
4b50e432 games/burnout: add Burnout Paradise Remastered's profile and note
9cc20e64 ci/tests: the CPU-only gfx tests no longer name t_rt_depth_ro
43e816d8 chain: build the raw global lookup's search once per shader (PR #2769)
25b9d2fe packing/shaders: read Bundle 2 version 2's three-block layout (PR #1883)
69e7b11b nvn/vertex: layouts the vertex fetch cannot read draw with their pulling pipeline (PR #1129)
7b586ac6 gfx/tests: t_dlss_scaler passes the bias mask argument, and checks the mask in the scaler's key
d20e9e7e chain: Maxwell ATOM.CAS, and signed displacements of 40-bit global addresses
12778f80 docs/env: DM_OBSOLETE gets its row
83a74d7d nvn/residency: every command buffer names the residency sets, none is attached to a queue (PR #2715)
063fd073 games/ocarina: movie update takes up to three pictures a frame
af286190 games/ocarina: movie player takes two pictures a frame, its frame counts pictures (PR #2456)
6f7e196f chain: retain compute uniform origins for texture handles
75758b94 host/nvn: no two archive captures of one vertex-stage function at once; prebuild puts such pairs back (PR #2758)
74181da8 nvn/stand-in: textures in a sparse pool get stand-ins read through the page table (PR #2477)
89ea16e3 host/os: the guest object map deletes by backward shift, so a key put again keeps one entry (PR #2711)
23790f8d nvn/dlss: pass the game's bias mask to MetalFX as its reactive mask (PR #1904)
7b67bfe0 game: Sid Meier's Civilization VI reaches the Mac map
bc36ee25 packing: read NVBC-wrapped CIVBSF shader records
4e1d7394 nvn: resolve descriptor handles against the execution pools
44b8ab17 chain: preserve both words of buffer texture handles
6229bbd1 packing: another edition's files keep a RomFS marker they hold (PR #1882)
94a09447 gfx/nvn: return stored sampler builder state from five getters (PR #2115)
c91dc47a nvn/fault: name every GPU address below 1 MB the host hands Metal (issue #1289)
f21855e3 packing: one obsolete/ folder for unused build and pipeline archive files
7c8dc0e6 packing: one compile cache file per shader chain version
eb2e27f8 host/audren: serve audren:u for SDK 1, whose renderer is only its client; Rayman Legends: Definitive Edition plays with sound (PR #1540)
40270c08 rewriter/jump: guarded runs proved over control flow; Tied Together's masked tables rewrite (PR #1937)
fb26adfc host/svc: count the host's memory beside the pool when choosing guest files
addbe8d6 host/memstat: start DM_MEMSTAT and DM_THRCPU after the iOS env files
730738e7 packing: key Mac prewarm pipelines on packed shader inputs
b6baa5d2 packing: port Civilization VII on the Mac with CIVBSF shaders
7b5d6310 rewriter/jump: one recognizer for guarded dispatch tails; ULTRA STREET FIGHTER II's main rewrites (PR #2108)
edc07d34 nvn/fstep: one stall is not a rate: the 30-frame average leaves out its longest frame
48ec04dd vulkan/draw: triangle fans drawn as lists, indexed ones converted before each stretch of a pass (PR #2708)
2da518bc game: TUNIC record iOS build and Mac validation
5c3f9052 host/codec: hardware Opus class members bind to the software class's by guest alias (PR #2746)
5facb9cb host/sf: serve notif:a, the reminder alarms, with an empty answer (PR #1974)
5e62b189 game/warhammer-survivors: profile, and oe::SetPerformanceConfiguration(int) hooked (PR #2318)
6336a359 host/oe: EnableStartupLogoDisappearedMessage queues message 95 (PR #1973)
a68978a7 packing: a build that allows damaged files reuses its split and shaders (PR #2683)
0ace41d4 host/hid: touch samples on a 4 ms grid, with a history of 16 (PR #2766)
d7877c50 chain/meshstage: mesh stage memory of 6 KB and more in a leased device slice (PR #2308)
b827a3b9 gfx/tools: tex_census.py counts the TEX LOD clamps and residency predicates the translator drops (issue #2350)
409be941 host/thread: guest thread wakes are signalled after G is released (PR #1466)
fb4da077 nvn/owner: the memory line gives the size and idle age of textures only the sharing table keeps
293b1d4d nvn/fstep: a scene that fits hold 1 is tried there up to 0.95 vsyncs
ad1ee5bf nvn: remove the TBDR mode and other dead switches
aa9e0ff7 game/xcx: run at 60 fps with native engine timing
b32d0bf3 packing: support Xenoblade Chronicles X: Definitive Edition
ae3f1699 nvn/pso: ask Metal whether a run can capture before leaving Metal 4 (PR #2688)
1d8e5feb game/kirby-air-riders: depth_mode zero, so the Mac app's pipeline archive is built for main0_z (PR #2287)
f91979ba packing: free-space checks count what APFS frees on demand (PR #2257)
bac9f821 host/font: shared-font stand-ins sized for the games' font engines
04ba572d chain/nvn: a vertex shader with z = w is drawn with a depth bias past the far value and depth clamping (PR #2199)
0def324d nvn: a feedback draw gets the levels its sampler's clamp reads (PR #1004)
03039baa nvn/resolve: implement tiled downsample commands (PR #2703)
1b24f3d6 nvn: check resource setup and fix analyzer findings in fixtures
815a4980 host/tests: observe polling sleeps without waiting on a frozen clock
049f8e0e packing/shaders: reject malformed NARC layouts with their diagnosis
c365e59f host/font: track and release enlarged engine work buffers (PR #2707)
a44ca5e7 host/pad: original Joy-Cons are read wholly from their HID reports on the Mac
960d203e nvn: the look-ahead admits every later draw's pipeline (PR #1344)
3fabafc8 host/nvn: an ID marked gone releases all its cached views (PR #923)
b2e2fdbf game: run Overcooked at 60 fps
a3b5230f host/pad: original Joy-Cons drive the Mac host as motion input (PR #2594)
b12d2977 game: Overcooked! All You Can Eat runs on Mac
34d86291 host/movie: nn::codec's VP8 and VP9 decoders are made as the movie path makes its own (PR #2198)
e251e168 host/audio: the AudioOutBuffer is the SDK's own 40-byte object, and its descriptor functions run in the sdk (PR #2739)
f8fce3fb game: Divinity: Original Sin 2 defaults to 60 fps
b1ba6570 nvn/fstep: a GPU-slowed probe needs the scene to fit hold 1 (PR #2611)
0e409ed8 gfx/nvn: a record that does not fit claims its position, and a lent segment hangs off the recording's bytes in the block it ran short in
73f6cbbb host/fs: a host error in a save path change refuses the save's next commit (PR #2690)
2e9a7bde game: port FINAL FANTASY VI
b2ae958f gfx/nvn: submissions that end behind running work go to the queue together, each in its own command buffer (PR #2645)
ddcc0f62 game: port FINAL FANTASY V
1fc17bbc nvn/submit: every commit of the submission's command buffer ends through cb_commit
```

Follow docs/agents/07-upstream-maintenance.md before integrating. This workflow never advances integrated_head, bumps releases, signs, installs or merges the PR.
