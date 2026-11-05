# Pending upstream review

Pinned head: `865cc35fad7034d17c2190f8ce349f61f5bcaba1`.

Manual conflict resolution required. No engine changes are staged in this proposal. Conflicts: AGENTS.md, README.md, dm/gfx/tests/t_geometry_hazards.m, dm/host/Makefile, dm/host/tests/t_fs.c, dm/ios/Sources/DmGamepad.m, dm/ios/Sources/DmIOS-Bridging-Header.h, dm/ios/Sources/Launcher.swift, dm/ios/Sources/front_ios.m, dm/ios/Sources/main.m, dm/ios/project.yml, dm/ios/tests/test_romfs_startup.py, dm/ios/tools/build_ipa.sh, dm/mac/launcher.c, dm/mac/pack_app.py, dm/tools/nx_extract/Program.cs, dm/tools/tests/test_nsp_mac_app.py, docs/reference/memory.md, docs/settings.md, scripts/build_ipa_from_nsp.py

```text
865cc35f A game whose memory pool does not fit the iPhone's memory limit keeps its guest memory in files, out of the footprint iOS ends an app at (PR #1315, issue #1184)
dd6ce5ba Pokémon Legends: Arceus: the capture demo returns its empty result when its weak reference is unset or dead, instead of a null read at main+0x16e34fc (a function-matched workaround; the cause is open, issue #712)
6d269f93 Unreal's NVN dynamic buffers keep 4 copies instead of 3, so a write lock is less likely to come round to a copy queued draws still read (issue #1040)
7249ee9f The compile cache is one file read and written in place, with nothing unpacked for a build, and one tool venv serves every game
cb34473f A game's shader libraries are one file the host and the tools read in place, and an iPhone build no longer compiles pulling libraries nothing reads
f0838733 Sparse 3D textures take the standard 3D tile, and a 32-bit integer texture in a slot declared float reads through the float view of the same size (issue #783)
95f9a6a9 VOTEU (0x886) writes the uniform predicate its destination names and leaves the lane predicate alone: an unwritten UP read false, so its uniform guards never held
72d00571 The pipeline prebuild tool takes Metal's concurrent compile count: it had 1 worker on an M6 and 4 on an M5 Pro, because hw.perflevel0 is only the Super cores on chips with three core levels
4a0551e4 Handles built under a guard the read's guard cannot be tied to: Yoshi's 130 deleted reads translate and the pool's water on Chapter 1's page comes back, and reads that bound a texture word with no sampler word get both
58a77cc2 lint-python is green again: pack_quiet's days is declared a float, as it is used, and the work-folder test patches NSP_FOLDER instead of leaving it set
056e41fe A NUP or a dump of a game with no profile is surveyed and gets a provisional profile, and a derived profile adds a module main imports that moved to another slot
7550be15 Trinity's rendezvous no longer loses its release on Apple cores: the rewriter puts a barrier between the completer's flag store and its load of the state word
56bafa97 A game's work folder stops growing: regress.py keeps the 3 chain builds used last, and a hand-made folder untouched for 14 days becomes one tar
8e349b5f A pak naming the global shader cache counts as inline only when the containers in its folder hold export bundles and no shader libraries, so FINAL FANTASY RESONANCE's libraries are decoded again (issue #1277)
f8a5618d CI is green again on tests, lint-python and lint-c: three tool test files follow ed3c93ee's rewrites, and the new clang-tidy and Python findings are fixed
fba0096f A game's build folder keeps its compile cache and Xcode's derived data as one uncompressed tar each between builds, so Metroid Dread's 84,541 cache files and Xcode's thousand become two files
7bccfc88 Star Fox's last 3 shaders translate: Ampere BMSK (0x21b), and 0x925, the read of a covered pixel behind its quad efficiency views (chain change)
67f1d005 Star Fox (Switch 2, 0400E88025B1A000, v131072, SDK 21.4.4) runs on the Mac through the title and prologue into the tutorial, with sound; the fixes are general: its VZIP archive and shader wrapper split, SDK 21's output streams, Opus manager, socket init and GameChat, and NVN2 compute's separate handles in c[0]
cc60a0c1 A shader build reports what it lost without failing: a [RED] line per shader for deleted bindless accesses and lost entry points, and regress.py fails a rise shader by shader
0e3bf653 Splatoon Raiders packs again: NigoProc's mesh shader row is split again, and the build error names the row that differs
cb39b33a Donkey Kong Bananza's white characters between Hilltop's rocks (#1100) are the deferred write under a false guard: the reference entry and the game's note say so
84dea698 Float comparisons honour .FTZ on Ampere and Maxwell: a denormal operand compares as zero, which removes the NaN behind some of Mario Kart World's isolated bright dots (most of them have another cause, open)
f9b438fb From PR 1261: TXD through a uniform register keeps its handle, layer entry points survive a point size passed by reference, Yoshi's 395 more shader keys (chain 9bb5d8678204)
ed3c93ee The shader builder's Python takes half the CPU: rewrites that tried every character of a large source find their text instead, and Pokopia's seen shaders build in 607 s, not 1,426 (#1036)
12aeebe9 DRAGON QUEST BUILDERS 2 (010042000A986000, 1.7.3d, SDK 5.4.0, KTGL) plays on the Mac through character creation and the ship prologue at 60 fps; the fixes are general: ssl::Context::Create and Destroy succeed offline, and the shader split reads LINKDATA.IDX beside LINKDATA.BIN
1baa7669 120 fps on the Mac for Mario & Luigi: Brothership, the first Unreal game: the host's writes to t.MaxFPS and rhi.SyncInterval follow the frame step, so one profile line offers it
9507c221 Yoshi and the Mysterious Book (Switch 2, 0400245021D2C000, Ver. 1.0.2, Unreal 5.4.4) plays on the Mac at 60 fps through the first habitat, a save and a reload; the fixes are general: 5.4's shaders, 32 vertex attributes, image and buffer texture handles in uniform buffers, guarded Ampere loads and writes (chain 3dd02e581c0c)
975bb4c1 Mario Kart World's sky panels are checked on chain d5fe9ae8bfba: none at Crown City, with no measurable frame cost (#1186)
5ae0d9ae Task and mesh storage buffer tables are at c0 0x670 and 0x770: Mario Kart World's sky panels came from draws reading the dummy buffer (#1186)
02c91cd4 README: Fire Emblem Fortune's Weave runs at up to 120 fps, in no particular version: the host finds its frame rate in the game's code (v131072 is the one tested)
4e0333a5 120 fps on the Mac, Fire Emblem Fortune's Weave first: a profile's fps_max 120 offers it, and the target follows the frames that fit, so a game that steps by its target keeps its speed
777a5f6c A NUP with no base game packs: no base record with standalone_update on its updates, or an empty base record, is one case
4447be11 Loose NARC files reach the shader split's reader: packing hid the magics its prefilter looks for (#1131)
1110473c Placement sparse tiles are shared by physical memory: Mario Kart World's terrain in a third of the GPU memory, and 60 fps races on a 16 GB M6 with its heaps flat at 1 GB
c0e150f3 The offline pipeline archive compiles in groups by default, and a failed archive is a warning: the app is packed without one instead of the build stopping (PR #494)
ae031161 Front ends can follow main: docs/frontends.md says what git shows, and a Front-ends: line in a commit says what only its author knows
abd7014b A save named by a host before backslash paths is found again: Link's Awakening no longer shows New Game for a file it has
19a8574d lint-python is green again: the launcher settings test's helper returns the rows by variable, so a game with no language row is no None to subscript
18b435ac Mario & Luigi: Brothership (01006D0017F7A000, base game 1.0.0, Unreal 4.27.2 with IoStore and Wwise, SDK 12.3.2) plays on the Mac at 60 fps through its first battle; the shader split reads inline shaders from IoStore export bundles, the host drives more than one audio renderer, and nx_extract names a RomFS whose own tables fail the hash check
aafe01d3 The Game language row shows for a game packed from a NUP or a dump: both builds read the base game's list when an update has none, and with no list at all every language is offered with a note
c7da003c Architecture check: no game's title ID in host code (from PR #422), and the build-ID scan reads .inc files
7dc00e4d NSP script: game files whose extension is in capitals are found and packed, an NSZ or XCZ too
d17e0ca5 lint-python is green again after the All-Stars commit: a jit_key_data span of one byte no longer raises TypeError, and the JIT capture's done() binds its own folder
5061b2a1 The Mac app replaces the old app by moves on a volume without an atomic swap: a second build onto Mac OS Extended, exFAT or FAT no longer stops with [Errno 45]
0b8e0dc1 Super Mario 3D All-Stars (010049900F546000, update 1.1.4) plays on the Mac, packed as one game of several programs: the launcher, Super Mario 64 and Super Mario Sunshine in one IPA, Mac app or run command
4d5f0f52 CI: a push to main no longer cancels the tests and lint-c runs before it, so main gets finished runs
a3d85ae1 Mario Tennis Fever's gallery image is a match replay, cropped to the game's picture: the old one had the window texture's black bands
5ccbeddb RED_ONCE(152) wrote one past g_red_once: the array has its size and the macro checks its key at compile time; lint-c and lint-python are green again
24a01b98 DAVE THE DIVER (010097F018538000, update 1.0.6.1267, Unity 6000.0.52f1 IL2CPP with FMOD, SDK 20.5.29) plays on the Mac; the shader split skips Unity compute kernels with no code
13da1c52 A pixel shader's alpha test and logic operation entry points come from one Metal compile: a full shader build takes about half the CPU (#1036)
eae1d0a0 Snowdrop's three-pool allocator found by the rewriter, sizes in the profile: Sparks of Hope's 64 KB pages get 1.25 GB, the first-planet abort of issue #1010
a4d7bb7b Port Kirby Star Allies 4.0.0a: movies get their colour space (nv12-colorspace), and a mixed integer entry point returns only the outputs that hold integers (chain 6971bb0ca089)
b6dbb851 Mario Tennis Fever (Switch 2) plays on the Mac at 60 fps: its code is an NRO a boot stub decodes at run time, captured by the host, its files in a scrambled rom:/42, and every shader but one translates
019a822d Issues get the labels pull requests have: area, game and platform from their text, and their kind from their form or title
cee65140 DM_UPSCALER=metalfx takes each upscaler shader's colour from its code: Splatoon Raiders is no longer washed out
a41b8054 test_shader_pch: the fake subprocess.run requires stdin, as compile always passes it: lint-python passes again
f2a50f35 Shader compiles read their source from standard input: a library with function constants no longer depends on its file's name, so a build's bytes no longer depend on the order of its compiles (#1036)
a27d684b A table in nvn_mtl.m that cannot grow stops with its name instead of writing through NULL, and lint-c's ratchet passes again (baseline 262 to 241)
c96a5dce --seen-shaders builds a Mac app or Mac run from only the shaders a game's playtests used: Pokopia's 8,158 of 131,426 in minutes instead of hours (#1036)
02b0b662 A DualShock 4 controller that connects after the first gets its own effects report: the HID device is looked up in the registry at each connect
a70f0718 An edit to a shader build helper reaches the libraries: the shader cache key covers dmsh_wide, dmsh_ampere, dmsh_meshstage and screen_varyings, and the chain version covers dmsh_meshstage (chain change)
e556f7a1 CI: a mesh shader kernel parameter without a name is refused instead of stopping the shader build, and the Xcode fixture's profile has modules_in
dd8eb14a Ampere tests on the games' encodings: every shared memory stride on 4, 8 and 16-byte stores, BREV, HADD2 / HMUL2 on a live register; the stride evidence from Mario Kart World
e07cba1c First-invocation stores in more shapes: Mario Kart World's trees and bushes no longer vanish in blocks (chain 20b9b1c2e4e4)
d361c5f8 Shader compiles read Metal's texture classes from a precompiled header instead of instantiating them in every metal process: half the CPU of a Metal compile, with byte-identical libraries (#1036)
75e5ddd8 Uncompressed textures the CPU wrote, in a pool the GPU has not written, take their storage at first use: Mario Kart World's terrain is no longer flat
cb59a672 Mac apps opt out of Game Mode: macOS holds the GPU at its lowest clock while it is busy, so Tears of the Kingdom falls to 30 fps (#349)
1d4b8e82 Mario Kart World (Switch 2, base game) plays on the Mac at 60 fps: large sparse textures and pools only as far as they are used, task and mesh shaders, and every one of its 11,561 shaders translates (chain change)
df7fa667 The capture services get host sessions: Super Smash Bros. Ultimate no longer aborts on caps:su and caps:u when its single-player mode starts (#495)
45a3c987 SDK 19: fs::MountRom and QueryMountRomCacheSize with a program index, nvnTextureBuilderGetSwizzle (#514)
bd98317e docs: the COMPRESSIBLE entry no longer links a game note that is not on main (test_docs failed since 733dff9d)
733dff9d COMPRESSIBLE textures in a pool the CPU writes keep their content: the flag is a memory-compression hint, not a data format (SD GUNDAM G GENERATION CROSS RAYS: every image black) (#946)
e250bb8b Submit-thread CPU cuts: deferred uniform lookups remembered per range until the list changes, a program's facts cached, NVN trampolines uncounted unless call counts are asked for (Breath of the Wild: about 9% fewer translation cycles a frame) (#1122)
691e4775 MT Framework: ARC v7 directories with 64-byte paths and SPK packages with the control section first (Ultra Street Fighter II) are read from the bytes (#967, part of #960)
ee01253d A main that compiles its own GLSL with GLSLC for NVN is an NVN game even when it links EGL: Rayman 30th Anniversary Edition's provisional profile took it for OpenGL and drew nothing (#884)
2670e6ad Unity 6000.3 Shader layout for stripped player files (version 4: m_AssetLocalIdentifierInFile after the GUID)
04923357 Unity 2021.3 stripped players have a Shader layout: Dynablaster's shader split stopped on "no bundle has a Shader type tree of the same hash to borrow" (#1147)
79774e76 The host takes over movie::Decoder's base-object constructors too: Mario Tennis Aces reached the SDK's C2, whose DecoderImpl Configure read as the host's decoder (crash at pc=0) (#1131)
8fc76577 The render pass's number moves before its encoder begins, so the GPU profiler's rows carry the same pass label as the attachment and draw dumps (#1144)
4e5582eb A depth clear over the whole target with a partial stencil mask draws only the stencil: the depth half is the next pass's load action, and Donkey Kong Bananza no longer loads 22.8 MB of depth a frame to clear it (#1138)
e20888b4 The clang-tidy baseline drops the allowances main no longer needs: lint-c failed on main with two RetainCount entries below the baseline (#1141)
de159bcb attr_read takes half2/3/4 attributes and unsigned-byte indices: Donkey Kong Bananza's final quad (RGBA16F positions, byte indices) can be proved to cover its target (#1137)
6ddeda92 pso_offline.py --batch-size N compiles the offline pipeline archive in sequential groups of at most N bases and merges them with metal-pack: Super Mario Odyssey's 32,864 bases no longer exhaust an 8 GB Mac's paging space in air-nt (#1119)
b1c20372 The rewriter takes an unframed pointer thunk followed by zero trap padding as a tail call: Moving Out 2's main no longer stops on a jump table assertion (#888)
65cc2af4 A PFS0 whose last file name has no NUL is read: the NSP script bounds names by the string table, and nx_extract hands LibHac a virtual header with the terminator (older NSZ writers; Moving Out 2) (#886)
f3d8cf33 Mac apps declare LSSupportsGameMode, as the iOS app does (#699, from #944)
e2ab03aa Motion fusion rejects a non-finite accelerometer or gyro sample before it primes or changes the state: one NaN no longer poisons the orientation and angle for good (#861)
8148c343 uepak.py reads version 8 paks (Unreal Engine 4.22 to 4.25): version 4's per-file index with version 11's footer, the compression method an index into its names; DRAGON BALL Z: KAKAROT's shaders split (#917)
9e757d07 The shader split ignores the AppleDouble files of an external drive in captured GLSLC and decoded Unreal shader folders (#898)
04ef91eb A compute pipeline Metal refuses is named once and its dispatches skipped; IMAGE keeps only uncompressed textures from taking their storage at first use; the compute hoist scans only when a dispatch follows (#1107, #1125, #1121)
620c68da Cheat region 2 (alias) is the host's alias region (svc_alias_range), not one computed from the profile's sizes: a DM_ALIAS_SIZE run put it at the wrong base
1b94fab2 fn (Globe) + a letter goes to the system, not the game: AppKit's Globe-F full-screen shortcut and the other Globe shortcuts work in the game window (#875, #873)
753fe273 The rewriter's split of two patch areas stays within the back area's reach: Hello Kitty Party Land's main no longer stops on a B() range assertion (#856)
8f8b9d5a Animal Crossing's patches.py names its helpers in lower case: test_patches took its seven upper-case constants for tables patch_nso.py does not read, and failed on main since b6e1f005
5e62e207 vk_shaders.py links its metallib from the inputs' common folder with relative paths: thousands of absolute paths under a long work folder no longer pass ARG_MAX (Super Mario Galaxy) (#701)
92f223a7 A texture over the storage of its sRGB / linear twin is a view of that texture: what one writes, the other reads (Mario Kart World's Grand Prix movie no longer shows a frozen frame) (#1110)
53ab7a9d Mesh draws join runs while samples-passed counting is on: counting stays on for the rest of a game after its first reset, so Donkey Kong Bananza's depth prepass drew every geometry draw alone (#1099)
0ad564a7 audio.md: the output device notification under its SDK 21 and 22 name, which Fire Emblem Fortune's Weave's sdk calls at start (#974)
d6b432e5 regress.py keeps the game in focus while its window is up (DM_FOCUS_KEEP=1): Tears of the Kingdom's intermittent route "hang" was the game paused out of focus after another app took the key window
50363b14 texraw saves every depth slice of a 3D texture (#975)
229fc22c A sparse texture's CPU-write check runs once a submission, and its page-table walk keeps the dirty tracker's last range: Mario Kart World's terrain targets no longer walk their page table at nearly every lookup (#1080)
6fc34217 Texture ID views are revalidated only for the serials that changed: a few serial changes a frame no longer send every registered ID down the slow path (#1069)
442680db Bindless handle reads take the guest bytes at their address, and argument writes an arena's kept contents pointer: no -[MTLBuffer contents] message, retain and autorelease at every handle read (#1070)
82246bd2 t_audio drains every buffer a release event announces: a callback can finish several buffers and the notifier can combine wakes, so the suspend / resume case no longer fails under TSan with 5 of 6 notifications (#1008)
0b80fb6d DM_PROBE_WATCH and DM_PROBE_POLL take heap+<offset>, resolved once the game opens its heap, for games whose address space moves between runs (#1111)
b3b38f4b fn (Globe) + F puts the Mac game window in full screen: the key monitor took it as the game's F (#873)
6a60b722 An empty GLSLC capture passes when the offline split covers every shader the capture boot submitted: Alien: Isolation loads its precompiled shaders and compiles none at boot (#1017)
55fdf963 A kept provisional profile no longer packs an older version silently: the newest version in the folder is packed unless -p asks for another, and a profile that does not describe it stops the build with what to do (#1055)
fd14f3bc The NSP script's GLSLC capture boot presses A every 4 s from 5 s on: Crash Team Racing Nitro-Fueled compiles its run-time programs only after its title screen has had a press (#1078)
998896ac The Mac app pack ignores the AppleDouble files of an exFAT drive: its inputs skip "._name" files, copies leave extended attributes out, and the bundle is stripped of them before codesign reads it (#991)
dfac27f5 account::LoadProfileImage answers with the local user's profile image, a plain 256x256 JPEG: Burnout Paradise Remastered no longer asserts in nn::image::JpegDecoder after creating its save (#1118)
f8c8e376 The Unity 5.5 Shader layout for stripped players (hash 4496e93f…): Lovers in a Dangerous Spacetime's shaders split (#1020)
0fd9b1c8 A frame-step probe's grace lasts while its frames keep getting cheaper: on the Mac the GPU clock rises for the shorter deadline over seconds, and Breath of the Wild no longer stays at 30 or 20 fps after a heavier scene (#1042)
5a07ff2c The Mac input box keeps the game's focus: the game window resigning key while the box is up is not sent as out of focus, so Monster Hunter Rise takes a typed name on the first OK (#1031)
230fe532 RGBA4 textures hold Metal's channel order: their four nibbles are reversed where they cross between guest memory and a host texture, and Super Mario RPG's sunlit battle ground is lit again (#993)
51574845 A derived profile names its source profile by ID, not by folder: the same game version built from another checkout keeps its derived folder, shader split and heap check (#1098)
b7d7be11 The purchased-item notification is answered offline: an empty queue with an unsignalled system event, so Super Kirby Clash's purchase watcher no longer reaches the absent shop service after account selection (#1007, #987)
1e9e3df4 vi::OpenDisplay("Default") opens the host's display, as OpenDefaultDisplay does: Alien: Isolation no longer reads the absent vi service in its window setup (#1016)
08a15900 vi::QueryDisplayBufferMaxResolution answers from the screen the game is shown on: docked, the largest of 720p / 1080p / 1440p / 4K that the screen holds, as a docked Switch 2 answers with its TV (#971)
acdeaeb1 The movie decoder takes SDK 1's non-const movie::Buffer getters when the const ones are not exported: Ultra Street Fighter II no longer stops constructing its decoder (#966, #960)
235eb516 Bluetooth LE calls are answered offline: Pokémon Violet 3.0.1 no longer aborts a second after boot (#1132)
185b7dbf A bindless fragment shader counts as a depth reader only when one of its handles names the depth attachment: Fire Emblem Fortune's Weave's decals no longer split the pass each (#1068)
d6a2808a Uniform references in shader facts reach the whole 64 KB constant buffer: a pixel-position sample or a uv affine scale past c[x][63] no longer fails the shader's reflection (#1114)
c6e45e14 A derived profile loads only the modules its version ships: an older base game without a module the profile's update added no longer stops the rewrite (#1105, #1092)
cd7f3803 A texture serial's descriptors are retired only at its first release (#1120)
600c0b37 The game's view takes the shape of the picture the game presents: a 1.43:1 picture under DM_SCREEN_ASPECT fills a 1.43:1 screen instead of being fitted into a 16:9 view (from #1091)
b6e1f005 Animal Crossing: New Horizons in a taller screen's own shape (DM_SCREEN_ASPECT) (#1091)
2e804948 Breath of the Wild screen shape: the title menu's backing and an NPC dialog's backing (#969)
48d79ced Breath of the Wild: a picture of a taller screen's own shape (DM_SCREEN_ASPECT) (#969)
e2de8d39 t_upscaler_mfx runs under any profile: its named shader is the profile's first upscaler key (DM_GAME_UPSCALER_KEYS), not Donkey Kong Bananza's 7629d857a0a93833, and a profile without upscalers swaps none; make run failed it for every other game (#1086)
c94ce657 LDC with its bank in the address register (.IS) reads the bank chosen at run time: Hyrule Warriors: Age of Imprisonment's last two untranslated shaders, one of them also Pokopia's (chain 316fb82e2f22)
ad7af9cb Tests check the Metal buffers, bitmaps and events they make before using them: lint-c's ratchet passes again (seven nullability findings from #1086, #1084 and #1073, whose own runs were cancelled)
cc4500c8 iOS in-game menu: one compact text size whatever the system text size, no section headings or value lines
abd5ac2c iOS Xcode builds: the first copy of the game's files into the app is an APFS clone (cp -c), so a fresh BotW build no longer writes its 16.5 GB again (#1124)
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
