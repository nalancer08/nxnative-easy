# Pending upstream review

Pinned head: `24fe1e5a8a6fb21eebe6b0c0ff6078b387d7da57`.

Manual conflict resolution required. No engine changes are staged in this proposal. Conflicts: dm/host/Makefile, dm/tools/nx_extract/Program.cs, dm/tools/tests/test_nsp_mac_app.py, dm/tools/tests/test_shader_toolchain_cache.py

```text
24fe1e5a The controller applet waits for players: with a window, a game that asks for more players than it sees gets a prompt over the game that holds its thread until enough controllers have joined (a first button with Press a button to join, a connection without) or the player closes it, as the Switch's player screen; without a window or with DM_KEYS / DM_CTL it is canceled at once as before
32335650 An image slot takes a view of the type its shader declares, as a sampled slot does: Mario Kart World's mip passes write one-layer 2D-array views through slots declared 2D, and Metal dropped the stores (the blob shadows' zero mips drew a dark box around each kart's shadow)
12ddb1fb The graphics and sanitizer test targets run from a checkout whose path has a space: dm/gfx/tests quotes the three $(CURDIR) paths it hands to the Python tests, and sanitizers.mk names its folder relative to the including Makefile's (ASAN_FLAGS travels inside quotes, so it cannot quote an absolute path)
d70e6a3a --progress json sends a game event once the app's name, version and bundle ID are settled: its title ID, name, version, bundle ID, the app it will write and the game's icon, before the shader stages (issue #1627)
050580df The shader split reads legacy Unreal paks whose index and entries are encrypted, with the key from main: Little Nightmares II's shaders are found (PR #1646)
0caa6f93 The NSP script's tests no longer call the ShaderWatch that counted shader files: 9c2fb0c9 made it read dmsh_build.py's progress file and left test_shader_watch_counts_the_list failing on the old signature; a partial build's total is the keys it is given, which test_partial_library checks
a631295b A texture copy into an uncompressed alias of a compressed texture writes the compressed texture: Monster Jam Steel Titans 2's arena floor is no longer black (PR #1617)
5c4dc18f The NSP script takes every package's title ID and version from its content metas, never from its file name: untagged updates pack however many there are, a wrong [v<N>] tag is said and ignored, and a base game served at 1.1.0 is its profile's v65536 (Castlevania: Belmont's Curse; issue #1629)
f25fa956 Pools that hold shader code are no longer made resident to key the shaders: keys_hash asks mtl_addr_known, which makes no pool resident and no chunk (The Great Ace Attorney Chronicles: three chunks, about 5 MB; PR #1484)
fa9cfb84 A retired texture leaves the residency set only once no serial entry holds it: the texture cpu_unc_drop hands to a package's serials stays resident while any of them draws with it (Ocarina of Time's GPU page faults 15-45 minutes into play, #1326; PR #1644)
c8bfa161 A pixel shader's readable-tile version is cut from its one compile, and every extra entry point calls main0's one body: Mario Kart 8 Deluxe's cold Mac shader build 22:46 to 14:47 and Super Mario Odyssey's 30:02 to 22:23 on an M2 (PR #1520)
2bd920a9 The NSP script's fallback tool folders come after the caller's PATH: the zstd, dotnet, xcodegen or python3 it selects are the ones that run (PR #1475)
ff33639c A short NDSR pack no longer stops the shader split: the record-start score counts only complete 16-byte records (PR #1298)
4861fb03 An NVN memory pool's storage is device-shared: UnmapPhysicalMemory and a shrinking SetHeapSize over it fail with InvalidCurrentMemory, as on Horizon
490859ea At a 30 fps target in fullscreen on a fixed-rate screen the display link stays at 60 Hz and the present interval paces the 30: the 30 Hz link skipped ticks there and kept frames on screen 66.7 ms (Ocarina of Time on a MacBook Air M4: 388 and 996 frames over 50 ms on a 180 s walk, 7 after; PR #1555)
```

Follow docs/agents/07-upstream-maintenance.md before integrating. This workflow never advances integrated_head, bumps releases, signs, installs or merges the PR.
