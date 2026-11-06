# Pending upstream review

Pinned head: `e0dc79c9bacda37bc078f13d9f2a306f583e62f5`.

Manual conflict resolution required. No engine changes are staged in this proposal. Conflicts: README.md, dm/gfx/tests/t_int_float_view.m, docs/agents/symptoms.md, docs/reference/packing.md

```text
e0dc79c9 Fire Emblem: Three Houses' shader tables are split again with the current shader_split.py, so the NSP script builds it instead of stopping on a table difference: its 29 run-time GLSLC rows now name DATA1.bin entry 2391 as where each key first appears (was 2392); the keys and facts are unchanged, all 1,372 shaders build
48d0b372 Bound render targets outlive their command recordings: the queue keeps its own copy of the bound colour and depth descriptions at the end of each submission, so a game reusing completed command memory no longer turns them into command bytes; Rhythm Heaven Groove's frog stage no longer crashes in nvn_sparse_pool (PR #1502)
8764cdfc Graphics tests that include hle_nvn.c link again: a weak dm_vi_frame_queued stands in for hle_vi.c's frame history, which 51cc8bce made the present call
04df08d4 Ocarina of Time's shaders all build: ATOMG.CAS translates, Metal takes 259 nested brackets, and the BAHS split no longer reads a control section's words as a program entry; a decoder's busy answer is no red line (chain 844bf1a5ea8f, PRs #1414, #1357)
cac783a1 Copy strides are command buffer state, as in NVN: Smash's one-texture uploads fit their 256 bytes of command memory again, so opening Adventure no longer jumps to 0 (PR #1450)
9c2fb0c9 A shader build leaves a few files instead of one per shader output: finished shaders wait in cas.db and the image is written from there, so Octopath Traveler 0's build holds at most 328 files while it runs and about 65 when stopped, not 68,230 (chain c8849b34b7b0)
51cc8bce Minecraft Dungeons II plays on the Mac to first control in its first level at 30 fps: the layer's frame history lists the presents, so Unreal's first full render flush no longer waits for ever after the logo movie (profile 0100A7C01B792000, note, games table row, gallery)
339d9f23 Raw pool table words follow the pools at commit: a memory pool made between a raw shader's encode and its command buffer's commit is no longer missing from the table the GPU reads, where its loads read 0 (PR #1427)
c229bd7d A memory pool's texture IDs are marked gone before its CPU-written classification goes: a pool walk in between handed out an NvPkg as the texture, and Ocarina of Time stopped with "-[NvPkg buffer]: unrecognized selector" in tex_by_id (PR #1420)
d4239a6e A storage takeover asks whether a live texture object holds each shared texture in one lookup instead of walking the serial table: Ocarina of Time's long frames in Kokiri Forest fall from 332 to 212 (PR #1439)
bd9f422d HMMA chains keep their accumulators and A in the SIMD-group's matrices, and A loads where its LDSM read it: Ocarina of Time's title movie network takes 11.4 ms of compute a frame instead of 14.8 on an M6 (26.7 to 18.9 on an M4; chain 23a1ea1db092, PR #1456)
6d928fd1 The encode thread records and replays indirect task / mesh draws: Ocarina of Time no longer aborts when a save loads with DM_NVN_ENC_THREAD=1 (the iOS default) (PR #1458)
b4318c7a ŌKAMI HD plays on the Mac from its provisional profile: boot, the prologue and first control at 30 fps with no red line (profile 0100276009872000, note, games table row, gallery)
0f510fd5 Raw global memory lookups start from the entry they chose last: Ocarina of Time's 2,241 raw-memory shaders take about 2 ms less GPU a frame at the Kokiri Forest spawn point (chain cfcc3a82c78b, PR #1464)
88c7e03f The Metal 4 specialization descriptor is owned once whether the driver returns it retained or autoreleased: iOS 26.0 no longer crashes before the first frame with Metal 4 pipelines on (PR #1213)
a9d06b6f Linear textures a device cannot view on their pool's buffer are uploaded by rows and again after CPU writes: Axiom Verge's sky is no longer magenta on iOS (PR #1212)
99e32cea The NSP script checks for the zbic package before it extracts anything: a game with ZBIC modules stopped only at the rewrite, after its whole RomFS was unpacked (Ocarina of Time: 23 minutes)
2eb71820 The tests that main's present shape and readback cache changes left behind pass again, and Ocarina of Time's note has its measurements on the final chain
671c68e1 Tests check the Metal device, textures, encoders and functions they make before using them: lint-c's ratchet passes again (t_int_float_view.m's nullability finding from f0838733) (PR #1338)
d928699b Fire Emblem Fortune's Weave's profile says the game's near=0 depth mode: the app's bundled pipeline archive is built for it, instead of refused at every start while the Mac built 872 MB of its own (PR #1074)
0cefa868 A shader keeps its readable-tile functions and finds them by their numbers: bf_fn no longer builds three strings at each of Breath of the Wild's ~270 tile-reading draws a frame (PR #1161)
75c1a8cf A video movie decoder decodes on its own thread, as the SDK's codec does: Mario Strikers: Battle League's movie worker no longer sits in the host's decode while its owner tears the player down, the crash at the intro movie's skip (PR #762)
6c55c3de Mario Strikers: Battle League's shaders are split from its revision-4 Next Level Games archives: 3,230 shaders where there were 40, and its black screen after the loading text is gone (PR #759)
6121fd75 Ocarina of Time holds 60 fps in Kokiri Forest and uses about 4 GB less memory on an external drive: pool shaders count as depth readers only when one was seen reading, a segment commits only when the GPU has run out, pipeline archives are mapped (issues 1385, 1375 not closed)
b1d7c707 The Legend of Zelda: Ocarina of Time (Switch 2, 0400486024DEC000, v131072, SDK 22.2.8) plays on the Mac at about 59 fps through Kokiri Forest, close to console video, with general fixes (chain 31345483d426)
69cb9b6e An NVN event answers which memory pool and offset it was built on: Assassin's Creed Revelations maps that pool at start-up and crashed in MemoryPoolMap on a null pool (PR #1401)
a5c7234e nx_extract --html reads an update's HtmlDocument NCA over the base game's when its header marks it a patch: Super Smash Bros. Ultimate 13.0.5's pages no longer stop the build as 1,641 damaged files (PR #1215)
a2d39a26 A reboot no longer packs every RomFS image again: the image's identity leaves out st_dev, which macOS gives out at each mount (PR #1354)
16e3e24f A decode proves an Oodle shader table, and a package that does not read costs only itself: an export entry no longer stops OCTOPATH TRAVELER II's split at 11,832 of 13,980 shaders (PR #1333)
52190603 The audio update lock is read off Update, then UpdateImpl: SDK 22 moved it to +0x2d8, and Ocarina of Time's render thread crashed under a lock that excluded nothing (PR #1345)
3e193e07 The Python lint job passes again: a uniform-buffer handle table's decode in reflect() cannot be None, as pool_arrays makes that pool only for a name it decodes; a comment, so the chain version moves and shader cache keys do not
8feddfee Kirby Air Riders (Switch 2, 040077201BE50000, v458752, SDK 20.5.26) plays on the Mac at 60 fps through whole races, at about 10 GB; the fixes are general: a game's uniform-buffer handle tables take a table the host builds instead of a 32-entry array, which left characters with no ambient light; a captured draw with sparse vertex IDs is compacted instead of taking 36 or 72 MB of scratch; PMAP records in PDAT archives, the guard band cull 0x80d, TMML with a handle in a register, Ounce's vibration and nfp calls, and one key per form of the Opus decoder
f956ffb0 A failed command buffer names its game shaders, and DM_RES_CHECK reports what is released before a submission that bound it ends (issue #1289)
c83c48f2 tex_fit treats 2D, 2D array, cube and cube array as layers, so a cube in a cube array or 2D array slot reads every face: Splatoon Raiders' red line is gone (issue #1289)
2202d610 A crop only picks texels: the present shows the picture in the layer's shape, so Galaxy 2's 5:4 cutscene crop fills a 16:9 screen again (issue #949)
eab0aaac A provisional profile's heap check that grows the block keeps the profile's alias region out of the heap region: Ocarina of Time's 6.20 GB request got 0xb8000000 (issue #1361)
e9d1ef2c lint-python is green again: nso_match's recipe() returns a plain dict, as patch_recipe() does
a334797d Each audio renderer plays from its own PCM blocks: function-level statics let one renderer's thread rewrite blocks queued on another's output (issue #1336)
e9d71e27 The Mac's alias region is the Switch's 64 GB, so a game can lay out its regions past the iPhone-sized profile value; heap and stacks now sit before it in the guest block
```

Follow docs/agents/07-upstream-maintenance.md before integrating. This workflow never advances integrated_head, bumps releases, signs, installs or merges the PR.
