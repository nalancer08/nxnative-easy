# Pending upstream review

Pinned head: `94a0944755da1a443f42651bf7ee49ab24ed5ee5`.

Manual conflict resolution required. No engine changes are staged in this proposal. Conflicts: dm/gfx/nvn/nvn_geometry.inc, dm/gfx/tests/t_pfv.m, dm/gfx/tests/t_pso_archive.m, dm/gfx/tests/t_sparse_copy.m, dm/gfx/tests/t_upload_src.m, dm/gfx/tests/t_vk_swapchain_life.m, dm/gfx/tests/t_wline.m, dm/gfx/tests/t_zero_depth.m, dm/host/tests/Makefile, dm/host/tests/t_pollwait.c, dm/tools/lint_c_baseline.tsv, dm/tools/tests/test_nsp_mac.py, docs/agents/symptoms.md, docs/reference/packing.md, scripts/build_ipa_from_nsp.py

```text
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
