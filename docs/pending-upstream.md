# Pending upstream review

Pinned head: `d3f7433ed1c1a82d9de1155dd733a722748379d8`.

Manual conflict resolution required. No engine changes are staged in this proposal. Conflicts: .gitignore, AGENTS.md, README.md, dm/host/save_sync.c, docs/development.md, docs/settings.md

```text
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
