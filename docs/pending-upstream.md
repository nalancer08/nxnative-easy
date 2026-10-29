# Pending upstream review

Pinned head: `bfda8c54a944258f8c3195c54699900d5b8cbda5`.

Manual conflict resolution required. No engine changes are staged in this proposal. Conflicts: README.md, dm/gfx/tests/Makefile, dm/ios/Sources/main.m, dm/tools/nx_extract/Program.cs, docs/agents/symptoms.md, docs/reference/packing.md

```text
bfda8c5 README: the games gallery with screenshots again
d7c0aea docs/images: keep the game screenshots
8432521 NVN render passes into storage-backed textures: written back into their storage (#604)
9c4b17a README: a plain list of the ported games, no images
393af57 Need for Speed: Hot Pursuit Remastered 1.0.3 (010029B0118E8000): profile, 60 fps
44a5da1 shader_split: read GLSLC outputs in Criterion's Bundle 2 resources
81ccacf nvn_mtl: encode a draw again when binding its arguments ended the render pass
5782527 Movies hold 30 fps under the frame step, from the host's movie decoder (issue #636)
32b12b4 dmsh_alpha: the first entry point's offset from its match, not a second search (chain 2fcec1622a5f)
fa475bb NSP script: an iOS build keeps a Mac build's shader libraries
881c618 Unreal texture streaming pool: profile key ue_texture_pool, the variable found by name (issue #589)
aaaceb3 CI: shader_split rejects a damaged cmp-zlib payload; baseline dmsh_alpha's pyright finding
1c54ea0 NVN vertex streams: a draw that reads past a stream's bound size reads zeros there (#558)
f78eec7 Well Dweller: profile and note (SDK 22 GameMaker/OpenGL: first room, pause menu, 60 fps)
ee369f0 NVN alpha test: a chain-built library per pixel shader, SetAlphaRef as replay state
42ac5d7 Team Sonic Racing: profile and note (Mac: menus, Wisp Circuit, Team Adventure opening, 30 fps races)
949a23b regress.py: drop chain_build_locked's unused tools (lint-python F841)
9791d74 Shader tables and Metal cache: only the shader build's outputs, not AppleDouble files
ad4619f NSP script: a sparse base game is read only with its update
500aaf5 regress.py replay: a replayer per game; BotW's route on the outdoors save; TotK capture
e542ccb Shaders: read Sumo's Ninty_NX descriptors, NVNsh records and MuxFDMR streams (Team Sonic Racing)
f293a70 NVN writes: a storage buffer bound with size 0 is the rest of its buffer
b478f5d NVN textures: the RGB565 family in Metal's order in every host texture
594eedd Audio renderer: the AudioRenderSystem's place in AudioRendererImpl read off the SDK (+0x50 in SDK 3.4: SteamWorld Dig's choppy sound)
ae4ec43 SteamWorld Dig: profile and note (Mac: opening and first mine, save, 60 fps)
b4be8c3 CI: the switch table lists DM_NVN_STORAGE_FIRST_USE; no unread switch in a note; a typed node list
4e900d9 Subnautica: profile and note (Mac: title to the lifepod opening, 30 fps)
4bbd9ff NVN textures: a plain texture's initial fill in Metal's channel order
49c752f NVN textures: MINIMAL_LAYOUT keeps automatic blocks only without padding
cca3333 The phone's motion comes in the pad view's frame on iOS 27 (GitHub issue #569)
cf3ec56 Port Mario Party Superstars 1.1.1; texture and sampler pools for handles traced to no slot
cd62e5e Streets of Rage 4: profile and note (Mac: intro, stage 1, save, 60 fps)
37c7eaa Block-compressed textures the CPU wrote before first use are CPU-written (GitHub issue #568)
404e92b SteamWorld Dig 2: profile and note (Mac: opening and first area, save, 60 fps)
15dd9c1 The prepare step runs outside the graphics gate (GitHub PR #574)
ac9598a Luigi's Mansion 3: depth_mode zero (PR #580)
f9e68a7 README gallery: captions one size smaller (<small>)
475dec9 Subnautica: Below Zero: profile and note (Mac: opening to the crash site, 30 fps)
7c715db SteamWorld Heist: Ultimate Edition: profile and note (Mac: first mission, save, 60 fps)
a1c8efd SteamWorld Heist II: profile and note (Mac: first mission, save, 60 fps)
1191af5 regress.py: missing shader libraries are one RED kind; a hang leaves its stacks
137c229 Library applets take the application's focus (GitHub issue #550)
123e3b4 Baba Is You: profile and note (Mac: level 00, save, 60 fps)
920a846 README: normal-size footer text
8325eef regress.py capture and replay: check the replay layer on recorded frames (#402)
528d185 Gallery: no IPA sizes, normal-size captions, every name linked
e12e01f iOS: take Documents/romfs.img in any letter case
810e368 Batman note: stage 0 cb0 unbound at boot is the game's own
2bccdcc A 2D texture in a 3D slot binds the zero 3D texture
fae1db0 NSP script: stop on a 32-bit ARM version of a game that has a profile
faabe05 Move the tool lock checks out of the chain (tool_lock.py)
5d2bf73 BotW note: replay noise comes from depth-equal tests in the G-buffer pass
971d336 Host fixes found reviewing MacNativeGames: SDK return types, LOD bias, build stamp
fa231d9 dmsh_chain.py: name the translator that does not run, not an empty xlate_source
d85f582 clean_metal_cache.py loads: no Optional spec (lint-python on 38b8907d)
38b8907 clean_metal_cache.py: remove Metal's idle build folders; regress.py runs it
6625a93 Frame replay: Wonder replays bit for bit; captures need no fixed clock
a6171b8 regress.py: a hex number in a [RED] line normalises as a decimal one does
37d18db Port Bastion 1.0.0
d8bc921 Port Batman: Arkham Knight 1.0.5
```

Follow docs/agents/07-upstream-maintenance.md before integrating. This workflow never advances integrated_head, bumps releases, signs, installs or merges the PR.
