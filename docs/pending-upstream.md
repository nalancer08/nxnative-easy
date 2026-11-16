# Pending upstream review

Pinned head: `edc7eff9cf9d1e4b2134c624e2b8cb690b0e586d`.

Manual conflict resolution required. No engine changes are staged in this proposal. Conflicts: README.md, dm/gfx/nvn/nvn_geometry.inc, dm/gfx/tests/t_pfv.m, dm/gfx/tests/t_pso_archive.m, dm/gfx/tests/t_pso_stall.m, dm/gfx/tests/t_sparse_copy.m, dm/gfx/tests/t_upload_src.m, dm/gfx/tests/t_vk_swapchain_life.m, dm/gfx/tests/t_wline.m, dm/gfx/tests/t_zero_depth.m, dm/host/tests/Makefile, dm/host/tests/t_pollwait.c, dm/ios/Sources/DmIOS-Bridging-Header.h, dm/tools/lint_c_baseline.tsv, dm/tools/tests/test_nsp_mac.py, docs/agents/symptoms.md, docs/reference/frame-rate.md, docs/reference/packing.md, scripts/build_ipa_from_nsp.py

```text
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
