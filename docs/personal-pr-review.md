# Full upstream main integration and permanent catalog maintenance

Current release: **1.5.0 / build 9**. Our main now incorporates the complete upstream
history through `40e6baede556acd454169ac75b33d1686063f528`, replacing the selective-only state documented below.
All earlier reviews remain historical evidence, not the current integration state.
The next update starts from `integrated_head` in [upstream-sync.json](upstream-sync.json).

Eight upstream profiles are now included with their existing screenshots, notes,
versions and required core changes: Mario + Rabbids® Sparks of Hope, Kirby and the Forgotten Land, OCTOPATH TRAVELER, SHIN MEGAMI TENSEI V: Vengeance, Xenoblade Chronicles 3, Sea of Stars, Donkey Kong Country Returns HD, Donkey Kong Country: Tropical Freeze.
There are 78 installed profiles. Both README galleries, the generated inventory
and artwork map are synchronized; the app's live carousel, View all and search
read these profiles. No independent iPhone-playability claim was added for the
new games; upstream platform-specific evidence stays in each game note.

The standing agent procedure is [07-upstream-maintenance.md](agents/07-upstream-maintenance.md),
linked directly from root AGENTS.md. `sync_upstream.py --merge-main` creates a
separate candidate, reports added/updated/removed profiles, synchronizes catalog
outputs and runs synthetic checks. Conflicts remain isolated for agent review.
`sync_game_catalog.py --check` is also a required CI gate: missing notes, images,
version updates, manifest entries or bilingual gallery rows fail the check.

The merge retains our Spanish/English interface, updater, controller test, touch
editor, lightweight unsigned iOS output, complete Mac apps and explicit own-key
selection. Working game packages and saves were not changed. The new translation
chain is `7fbca6dd477d`: all 1,010 Dread shaders and their variants/pulling libraries
were rebuilt for macOS and iOS in separate scratch directories, then the new host
was built. The production build's own-compilers wrapper was used because this
Mac's spirv-cross binary fingerprint differs from the maintainer's lock; the
locked translator was retained, and no mismatch was concealed by editing the lock.
An unsigned production iOS project with synthetic Dread-profile modules compiled
and linked, including our touch controls. Host tests passed. Full native GPU regression checks passed. The initial full Python run passed
61 test files (441 cases, 19 skipped optional fixtures); final fork checks
were rerun after maintenance/lint fixes. The pinned lint ratchet reports zero
new findings, without expanding its existing upstream baseline. Compilation and
synthetic checks are not a new physical iPhone gameplay test.

Two native test fixture issues were corrected during integration: an unquoted
workspace path in the transform-feedback Makefile, and an offline-pipeline test
that targeted the SDK's macOS 27 default while running on macOS 26.6. The fixture
now requests the running OS major and retains failed artifacts for diagnostics;
production's archive fallback is unchanged. The newly imported Python lint gate
also exposed small pre-existing fork issues; these were fixed without expanding
the upstream baseline. This included a missing interpreter argument in the sync
command's validation call, now covered by a full command-path regression test.

---

# Upstream maintenance: latest selective integration

Snapshot captured on 2026-10-26 (America/Mexico_City), pinned to upstream
`15805ef52578afe54196504e3f98e15a22221664`: 38 commits since our base and 85 open
PRs. Commit inventories were compared and the four tooling changes below received
source review and synthetic tests. Open PR metadata and file inventories are
archived; this is not a line-by-line audit of all 85 proposals or their generated
tables. The historical review below retains its original snapshot and limitations.
The machine-readable latest review is in [personal-pr-review.json](personal-pr-review.json).

## Integrated tooling

| Upstream commit | Result |
|---|---|
| `4639c5114cbb` (#241/#260) | Pack shader/pipeline pair tables and optional GPU pipeline archive into complete Mac apps. |
| `b117c9131721` (#272) | Compare shader build reports and stop when previously translated shaders regress. |
| `89744da75364` (#284) | Discover Homebrew .NET runtimes correctly for standalone build tools. |
| `09f3778c366f` (#279) | Incremental IPA and Mac packaging and derived-profile cache reuse, with atomic publication checks. |

The runtime, shared touch editor, game profiles and translator/chain header remain
at our working base. The current chain is `8393d85a4eae`. The two cherry-pick
conflicts preserved our README and the existing FINAL FANTASY RESONANCE note:
that note's later graphics claim depends on changes we did not import.
No game files, keys, installed game identities or saves were changed.

Incremental final packaging needs the same output path. Our simple wrappers still
produce separate dated outputs to preserve previous builds; their intermediate
profile/shader caches benefit, but do not promise that the final app/IPA is reused
across those different names. Direct core builds with the same output reuse it.
The upstream IPA index trusts unchanged APFS metadata; `--no-reuse` on the packer
forces a fresh archive. It does not detect old archive corruption during reuse.
Our lightweight export retains its CRC verification.

## Validation of this batch

The 100 focused .NET, Mac packaging, incremental IPA and shader-regression tests
passed before integration. The final candidate passed 48 Python test files
(352 test cases, 16 skipped for unavailable optional fixtures), using the prepared
build environment. The production iOS project compiled and linked unsigned with
synthetic Metroid Dread-profile modules; this exercises the shared touch editor
and host linkage, not gameplay. The updated Mac launcher compiled with the macOS
SDK. No prepared game was rebuilt, launched or installed during this audit.
The fork owner's successful iPhone and Mac gameplay report preceded this batch;
it is user-reported evidence, not a new automated device test.

## Deferred work

- Runtime changes: startup notification deadlock (`0963959`), save transaction
  isolation (`a0841d6`), audio/device/layout (`40b643b`, `15805ef`), scripted versus
  controller input (`583ae42`). Useful, but require the associated host tests and
  fresh gameplay checks; not mixed into the validated engine automatically.
- Graphics and new game series: image atomics, texture aliasing, display pacing,
  pipeline padding, Unity/HAL extraction and eight new profiles. Those share a
  translation chain and need coherent imports plus cross-game rendering checks.
- Developer tooling: upstream regression/impact harness (#328/#329), compiler
  pinning (#333/#337), base-NCA selection (#311), NSZ fallback (#327), faster
  builds (#343/#344). Evaluate as separate batches with their dependencies.
- Optional features: controller gyro (#351/#286/#296), cheats (#268), save sync
  (#210/#255). Gyro needs hardware checks; cheats need exact-build/code-page
  safeguards; sync needs destructive failure/conflict/recovery tests. Not enabled.
- Networking remains offline in both our runtime and the reviewed upstream main;
  no Jamboree profile was found. Local multiplayer controllers are different from
  LAN/netplay or Nintendo's online service.

## Repeatable flow

Use the repository's existing installer once to prepare tools, then:

```sh
python3 scripts/sync_upstream.py --output "/Volumes/Games/review-next"
```

This fetches upstream, freezes its head SHA and writes a commit/file/risk report.
It distinguishes the reviewed head from the actually integrated commits recorded
in [upstream-sync.json](upstream-sync.json). It never merges the active branch.
To test explicitly selected SHAs, in dependency order:

```sh
python3 scripts/sync_upstream.py --output "/Volumes/Games/candidate-next" --stage FULL_SHA [ANOTHER_SHA]
```

The second command rejects dirty source checkouts, integrated/non-upstream commits
and creates a detached candidate worktree. Conflicts remain there for inspection;
the active checkout stays intact. It finds the prepared Python environment and
runs all synthetic personal, tool, iOS and graphics Python checks into `checks/`.
Missing dependencies or failed checks stop the flow. Review logs, compile affected
targets and test games/devices before integrating. A passed synthetic test suite
is not a claim of gameplay compatibility or approval to publish a release.
Register newly accepted upstream SHAs in the policy, then bump the desktop release
manifest when distributing changed functionality through the in-app updater.

For a separate archive of every open PR and its pinned patch, use:

```sh
python3 scripts/review_upstream.py --output "/Volumes/Games/pr-review-next"
```

## Latest open PR inventory

| PR | Pinned head | Applicability |
|---|---|---|
| [#29](https://github.com/seedds/nxnative/pull/29) | `c117972a2513` | A16 BC decoding and rhythm-specific controls are bundled together; retain generic editor and separate bundle identity deliberately. Requires older iPhone texture, memory and touch testing. |
| [#32](https://github.com/seedds/nxnative/pull/32) | `0c0d8f3d1709` | Alpha-test variants can fix foliage, but first-use draws are deliberately skipped while compilation runs. Requires scene comparisons and cold/warm cache tests before adoption. |
| [#76](https://github.com/seedds/nxnative/pull/76) | `40460d2d4972` | BotW variable frame step and resolution changes require exact registered builds and timing tests. No established Dread benefit; higher caps also need thermal validation. |
| [#102](https://github.com/seedds/nxnative/pull/102) | `36afdfa28893` | Xbox label preference is opt-in and overlaps Nintendo detection proposals #180/#295. Choose one mapping policy, then test real controllers. |
| [#104](https://github.com/seedds/nxnative/pull/104) | `48c615d25dd4` | Mac app packaging, save locations and preferences overlap already-existing upstream Mac packaging. Reconcile save migration and current packer before considering it. |
| [#126](https://github.com/seedds/nxnative/pull/126) | `309722488d99` | Same title ID overlaps #289/#304; compare builds and regenerated tables. Prefer the newer, smaller validated profile series rather than stacking all three. |
| [#160](https://github.com/seedds/nxnative/pull/160) | `bdbf8eb2c854` | Xenoblade 2/Torna adds SDK 3.5, audio, movie and frame-step behavior. Mac evidence does not validate iOS memory or frame timing. |
| [#167](https://github.com/seedds/nxnative/pull/167) | `e4dc169c7662` | CPU-written linear and unflushed sampled texture upload paths can help several games. Requires dirty-page, alias and CPU/GPU synchronization regressions before adoption. |
| [#171](https://github.com/seedds/nxnative/pull/171) | `52c5daa90308` | Native SM/CSRNG transport can reduce SDK symbol interceptions. Large service-memory and handle-lifetime surface; run adversarial IPC and thread-safety tests before replacing working paths. |
| [#173](https://github.com/seedds/nxnative/pull/173) | `f5e632cf5f89` | SMT V combines profile, sparse pools and iOS aspect modes; depends on #263. The aspect changes also touch the editor's coordinate assumptions and need device testing. |
| [#176](https://github.com/seedds/nxnative/pull/176) | `887a4f058ebf` | Trails adds rewriter, scanner and NVN changes as well as a region-specific profile. Rebuild shader chain and check exact regional build; IPA build alone is not gameplay validation. |
| [#179](https://github.com/seedds/nxnative/pull/179) | `f661323a779d` | Physical keyboard support changes control visibility and focus cleanup. Must retain editor access and test keyboard/controller connect, disconnect and stale callbacks together. |
| [#180](https://github.com/seedds/nxnative/pull/180) | `fccf98362334` | Nintendo label detection is small and relevant on iOS, but overlaps #295 on Mac. Test Pro/Joy-Con and Xbox/PlayStation hardware before changing mappings. |
| [#181](https://github.com/seedds/nxnative/pull/181) | `691dd43ef6d3` | Asian Unicorn Overlord has independent title/build IDs and reportedly identical shader data. Import only for that release, verify build registration and profile tests. |
| [#186](https://github.com/seedds/nxnative/pull/186) | `bb517566f820` | Ninja Gaiden adds indexed Team Ninja archive parsing and ReadFile hook. Validate malformed archives, decompressed sizes and SDK ABI along with target-game playback. |
| [#188](https://github.com/seedds/nxnative/pull/188) | `603a60b780c9` | Blasphemous offset-table fallback must remain uniquely bounded; Blasphemous 2 relies on the framed tail-call fix already in the base lineage. Run ambiguity regressions before import. |
| [#189](https://github.com/seedds/nxnative/pull/189) | `e7d470c15244` | Intel translator launcher can help Intel build hosts, while runtime shader/Oodle capture still needs a native decoder. Do not treat universal launcher as universal game execution. |
| [#192](https://github.com/seedds/nxnative/pull/192) | `2d5fd5b29e1e` | Wonder's two feedback snapshots can address flicker; only affects that profile. Compare affected scenes and GPU/attachment cost on the actual version. |
| [#193](https://github.com/seedds/nxnative/pull/193) | `2c859258934d` | 3D All-Stars combines multi-program packaging, JIT, services and program switching. Major lifecycle and iOS changes; validate separately, including rejected 32-bit Galaxy path. |
| [#194](https://github.com/seedds/nxnative/pull/194) | `e20c2a5f4dc3` | Fullscreen display-link workaround addresses Mac 60-to-30 drops, not demonstrated iPhone behavior. Test fullscreen, variable refresh and pacing regressions. |
| [#209](https://github.com/seedds/nxnative/pull/209) | `acdd8dc6c873` | Converter manages dependencies and builds but also signing and engine selection. Preserve this private source checkout and unsigned-only policy if adopting any frontend. |
| [#210](https://github.com/seedds/nxnative/pull/210) | `acf21eee2fb7` | Folder import is asynchronous around gameplay startup. Require proof that mounting/game writes cannot race import, plus fault injection and recovery on disposable saves. |
| [#216](https://github.com/seedds/nxnative/pull/216) | `d70e4ac1ad3e` | Texture-level dumps, A2C fields and probe comparisons help bring-up. Not a speed feature; check dump boundaries and packaged-resource resolution. |
| [#218](https://github.com/seedds/nxnative/pull/218) | `c5923f0ef378` | Yoshi needs sparse layouts and GPU writes into texture storage, with Mac evidence. Combine carefully with #300 and rebuild/test shader dependencies before iPhone use. |
| [#221](https://github.com/seedds/nxnative/pull/221) | `f7c2f2f10543` | Steam controller adds HID, haptics, motion and player ownership. Requires the actual hardware plus multi-controller, reconnect and focus tests; no direct touch-editor benefit. |
| [#227](https://github.com/seedds/nxnative/pull/227) | `2e835c72451d` | Persona 5 note explicitly distinguishes install acceptance from gameplay. Useful evidence, no runtime improvement and no reason to replace the existing recipe. |
| [#231](https://github.com/seedds/nxnative/pull/231) | `69531352b9ee` | Secondary renderer advances at about 5 ms but its DeviceSink PCM is discarded. Verify this is intended for each game, and test close/join races before general use. |
| [#233](https://github.com/seedds/nxnative/pull/233) | `36fc9b37baf8` | War in the North changes an event clear-mode instruction. Keep exact build-ID gate; verify worker wake behavior and absence of lost work in that title. |
| [#234](https://github.com/seedds/nxnative/pull/234) | `75fd1b28b8ea` | Runtime shader dumping can recover variants missed offline. Validate guest control/code bounds and capture deduplication; keep captured game shaders outside Git. |
| [#236](https://github.com/seedds/nxnative/pull/236) | `dffb26f608f4` | 30XX generalizes SDK discovery to subsdk modules and adds GL/EGL and sampler handling. Run GL shader, SDK discovery and existing NVN/Vulkan regressions before adoption. |
| [#239](https://github.com/seedds/nxnative/pull/239) | `11e1ea583376` | Preferred-language discovery is Mac-only and explicit language wins. Our iOS wrapper persists the selected language already; no iOS benefit from importing this series. |
| [#252](https://github.com/seedds/nxnative/pull/252) | `ebc3bc409d47` | Oodle GFPAKs, address-space cuts and dual-source blending may unlock Arceus/Z-A builds. Requires chain rebuild, precise build gates and visual/gameplay validation. |
| [#255](https://github.com/seedds/nxnative/pull/255) | `988d765d4dbd` | Single-file archives and transaction hooks are a stronger starting point than mixing with #210. Still require interrupted-copy, rollback, conflict and unavailable-cloud tests on disposable saves. |
| [#258](https://github.com/seedds/nxnative/pull/258) | `27339e1e3d4b` | Swipe camera/deadzone helpers have useful tests but the PR remains draft pending integrated device testing. Reconcile DmGamepad changes with our editor before any merge. |
| [#263](https://github.com/seedds/nxnative/pull/263) | `46b6aa45112b` | Buffer-image type and unbound atomic scratch address concrete admission failures. Related fixes now also exist in later upstream commits; compare first to avoid duplicate or older implementations. |
| [#265](https://github.com/seedds/nxnative/pull/265) | `633816faa76f` | HUD counters and system load can help measurements; overlap game profile and host state. Check sampling overhead and thread safety; no demonstrated iPhone FPS gain. |
| [#268](https://github.com/seedds/nxnative/pull/268) | `c84153fbbbc3` | Adds memory writes, executable baking and a runtime menu. Separate from automated builds and compatibility; requires opcode bounds, build matching and pause/thread testing before opt-in adoption. |
| [#269](https://github.com/seedds/nxnative/pull/269) | `0214c68bd3d1` | Violet profile includes Bluetooth service and rasterization stub. Mac opening evidence plus an acknowledged image-atomic warning does not establish correct iPhone gameplay. |
| [#273](https://github.com/seedds/nxnative/pull/273) | `028f8b248add` | Jump-table reach, transform-feedback layout and MGFX tolerance can help several titles. Broad translator/binary changes require chain regeneration and cross-game regression comparisons. |
| [#275](https://github.com/seedds/nxnative/pull/275) | `f0f966fecba3` | cache_outputs gates the entire mac group, including _b.json/_b.metal, when selecting ios only; downstream analysis still consumes those products. Reproduce clean-output cache-hit restoration and fix metadata caching first. |
| [#277](https://github.com/seedds/nxnative/pull/277) | `841684012800` | Count unique archive paths instead of unique byte sizes. Exact source patch and three synthetic regressions adopted; no shader, game profile or runtime change. |
| [#278](https://github.com/seedds/nxnative/pull/278) | `62d2085018f0` | Multi-platform CLI is stacked on #275 and carries its target-selection changes. Repair and validate target-specific cache restoration first, then test each platform combination. |
| [#280](https://github.com/seedds/nxnative/pull/280) | `05715be61396` | Spanish GUI also includes scheduler, extraction and shader changes and device signing/install. Extract independent fixes; keep unsigned automation and editor base rather than import the whole application. |
| [#282](https://github.com/seedds/nxnative/pull/282) | `48192496c829` | scan_file catches every Exception and returns an empty shader set, so a build may succeed with omitted shaders. Separate compiler-signal retry from scanner policy; require explicit incomplete-build reporting. |
| [#285](https://github.com/seedds/nxnative/pull/285) | `e79692b58fa1` | Crystal Chronicles profile uses build-gated Unity memory-order cuts. Verify registered instruction bytes, worker stress and iPhone behavior; newer Unity TextAsset scanner changes are separately upstream. |
| [#286](https://github.com/seedds/nxnative/pull/286) | `0cd0e1658246` | dm_motion_set writes g_mot_t under g_mot_mu, while mot_fresh reads it without that lock. Fix synchronized snapshots and run race/focus/disconnect tests before gyro adoption. |
| [#289](https://github.com/seedds/nxnative/pull/289) | `7cc835f996f2` | Large FFR regional series overlaps #126/#304 and changes common extraction/allocator paths. Compare exact title/build IDs rather than relying on conflicting region labels. |
| [#295](https://github.com/seedds/nxnative/pull/295) | `9a9500bbcb13` | Nintendo label detection plus override overlaps #180. Candidate for a unified mapping helper; reported Mac Pro Controller test does not validate iOS. |
| [#296](https://github.com/seedds/nxnative/pull/296) | `f1a254912389` | Pro Controller HID supplies motion when GameController reports zero. Reconcile with #221/#286 instead of stacking alternate motion APIs; test calibration, axes, drift and ownership. |
| [#297](https://github.com/seedds/nxnative/pull/297) | `7d8cfcee455e` | Leaving unlinkable pairs out can salvage an archive but does not restore missing vertex outputs. Prefer #298's padding fix; also verify cache stamp sensitivity to --leave changes. |
| [#299](https://github.com/seedds/nxnative/pull/299) | `28fbf0af4f98` | Good Job combines profile, Unity timing and Mac launcher/window changes. Separate reusable UI from title-specific frame-step patches; Mac metrics do not validate iPhone. |
| [#300](https://github.com/seedds/nxnative/pull/300) | `04d16458249b` | Sub-tile sparse textures must keep automatic block height. Has synthetic layout tests and a concrete Yoshi symptom; apply with the related sparse-layout series and cross-format tests. |
| [#301](https://github.com/seedds/nxnative/pull/301) | `9a0563ccafd4` | BotW MetalFX interpolation is opt-in and adds latency, frame hooks and game assumptions. Not an iPhone FPS fix; isolate and compare UI/motion artifacts on supported hardware. |
| [#302](https://github.com/seedds/nxnative/pull/302) | `ff9727c980c1` | DMG window/background automation is useful for Mac distribution, not IPA installation. Finder automation permissions and fallback need testing if Mac delivery becomes a goal. |
| [#303](https://github.com/seedds/nxnative/pull/303) | `dbf0ab920f7d` | Pool high-water tracking can guide memory sizing. Static pool-pointer tracking needs concurrency/lifetime checks; it measures pages ever used, not current live allocations or FPS. |
| [#304](https://github.com/seedds/nxnative/pull/304) | `3b32d7d6c3bd` | Newer FFR regional profile includes translator/host defects and claimed iPhone evidence. Avoid stacking #126/#289; chain binaries and tables require full reproducible regression builds. |
| [#306](https://github.com/seedds/nxnative/pull/306) | `a957e6b73689` | Contribution templates are optional repository maintenance, independent of game support. |
| [#307](https://github.com/seedds/nxnative/pull/307) | `15763f525640` | Graphics test discovery is useful maintenance; keep CI without GPU and local GPU tests distinct. |
| [#310](https://github.com/seedds/nxnative/pull/310) | `c5bf5061bf57` | Older iOS/tvOS support is a separate platform effort; compilation is insufficient to claim device support. |
| [#311](https://github.com/seedds/nxnative/pull/311) | `38915ee7e1f9` | Base Program NCA selection in cartridge dumps is an important next extraction candidate; exercise mixed base/update fixtures. |
| [#314](https://github.com/seedds/nxnative/pull/314) | `adedb5f535d2` | Frame-step probe timing changes a performance/latency tradeoff; test affected iPhone/iPad models. |
| [#317](https://github.com/seedds/nxnative/pull/317) | `acdd6e8ff45f` | Audio-device regression fixture depends on a newer host; import with that audio series. |
| [#319](https://github.com/seedds/nxnative/pull/319) | `833c56641b17` | Unaligned vertex streams affect general rendering; validate buffer lifetime, bounds and visual output. |
| [#320](https://github.com/seedds/nxnative/pull/320) | `63e294e709a7` | Overlaps the already integrated upstream Sparks of Hope port; prefer the coherent upstream main series. |
| [#321](https://github.com/seedds/nxnative/pull/321) | `0e171b9b1472` | Texture tracking changes are core runtime work; run graphics and dirty-resource regressions first. |
| [#322](https://github.com/seedds/nxnative/pull/322) | `639e2a97c9e8` | Dependency manifests and pinning are useful, but must match our installer and current translator. |
| [#325](https://github.com/seedds/nxnative/pull/325) | `4a4769e0e4b3` | Diagnostic thread dumps can help debugging; assess signal/thread safety before importing runtime code. |
| [#327](https://github.com/seedds/nxnative/pull/327) | `76eb68f88707` | Standalone NSZ/XCZ converter fallback is a useful next dependency-installation candidate. |
| [#330](https://github.com/seedds/nxnative/pull/330) | `d7a95500248e` | Game-specific keyboard/mouse aiming; prefer a coherent input policy with real hardware checks. |
| [#333](https://github.com/seedds/nxnative/pull/333) | `cee9b90e1ef9` | Pinning the tested Metal compiler is a reproducibility priority; coordinate with Xcode/chain requirements. |
| [#335](https://github.com/seedds/nxnative/pull/335) | `af3e3a4fb96c` | Optional sampler filtering requires rendering and performance comparison. |
| [#336](https://github.com/seedds/nxnative/pull/336) | `e188fe98c55f` | NieR pacing and dynamic resolution require exact-version gameplay and timing checks. |
| [#337](https://github.com/seedds/nxnative/pull/337) | `c990da26aed3` | Pinning spirv-cross is a reproducibility priority; select binaries matching our retained translation chain. |
| [#339](https://github.com/seedds/nxnative/pull/339) | `14e5d32fe051` | UE3 support spans extraction, allocation and timing; needs its own game and malformed-input regression checks. |
| [#340](https://github.com/seedds/nxnative/pull/340) | `4d676160f85c` | Batman bring-up depends on other open rendering/UE3 proposals; not ready as an independent game profile. |
| [#341](https://github.com/seedds/nxnative/pull/341) | `21870dcc5b5a` | Exact Mario Kart update profile; needs matching game files and shaders, not an automatic compatibility promise. |
| [#343](https://github.com/seedds/nxnative/pull/343) | `b8afb5b78c1b` | Build/prewarm speed candidate with shader cache and pipeline dependencies; keep the chain coherent. |
| [#344](https://github.com/seedds/nxnative/pull/344) | `379f147fedad` | Pipeline compiler time budgets can help stalls; verify fallback behavior and archive completeness first. |
| [#345](https://github.com/seedds/nxnative/pull/345) | `c37381120a8f` | Optional presentation scaling and sharpening change GPU work and image quality; device validation required. |
| [#351](https://github.com/seedds/nxnative/pull/351) | `f9dc8b4bb24c` | Motion control is relevant for future games; reconcile competing gyro proposals and test real Xbox/PlayStation/Nintendo/device sensors. |
| [#352](https://github.com/seedds/nxnative/pull/352) | `576947788c58` | Mac launcher configuration and shader progress are useful next tooling candidates; reconcile our app and progress parser. |
| [#354](https://github.com/seedds/nxnative/pull/354) | `27a31b57b429` | Per-game render scale ceilings affect GPU memory and image quality; need device comparisons. |
| [#355](https://github.com/seedds/nxnative/pull/355) | `a2e9bf7803d9` | Conditional settings overlap our simpler UI. Evaluate backend settings independently. |
| [#356](https://github.com/seedds/nxnative/pull/356) | `4dba64a0ec73` | Optional Mac keyboard camera; test focus loss and simultaneous controller input before adoption. |
| [#357](https://github.com/seedds/nxnative/pull/357) | `07448091977a` | Launcher UI restructuring overlaps our simplified interface; do not replace our frontend wholesale. |

---

# Personal iOS branch: upstream review, 2026-10-26

Scope: all 57 PRs open at the captured snapshot, plus the 20 upstream commits after
`ecbeae164c0b419d1ba1031248fe1402050a3eb0`. This is static applicability triage:
PR descriptions, changed-file inventories and source patches were inspected, with
closer review of the input, save, packaging and shader-cache candidates noted below.
It is not a line-by-line correctness audit of all generated tables or binaries.
Except #277, these proposals were not applied, compiled or tested on our branch.
Author-reported device results are evidence from the author, not our own device tests.
An open PR, clean merge or CI `action_required` is not proof of correctness.

## Applied now

- Preserve our shared touch editor and the original Dread engine/shader chain.
- #277: unique archive paths for extraction-space estimation; all three tests pass.
- New one-command dependency/build/lightweight-export scripts, independent of a clean-checkout gate.
- No save-sync import, automatic engine upgrade, Apple signing or device installation.

## Most useful next work

1. Evaluate the upstream-integrated .NET discovery and incremental packing changes
   as an isolated tooling update; compare clean and cached outputs, including CRCs.
2. Investigate #298 (stage-output padding), #300 (sub-tile sparse layout), and the
   later upstream shader regression gate before upgrading graphics for a new game.
3. For input features, reconcile #258/#179/#180 with our editor and test actual hardware.
4. For new titles, select the exact profile/build series in the table. A game without
   a proven profile can get a best-effort build from upstream; that is not a promise it plays.
5. Keep save synchronization separate until destructive failure and recovery scenarios pass.

## Every open PR

Each row pins the reviewed head. Links lead to upstream source/discussion.

| PR | Head | Decision | Applicability and required validation |
|---|---|---|---|
| [#29](https://github.com/seedds/nxnative/pull/29) Rhythm Heaven Groove: A16 legacy support, touch pad and ambient bars | `c117972a2513` | Conditional hardware support | A16 BC decoding and rhythm-specific controls are bundled together; retain generic editor and separate bundle identity deliberately. Requires older iPhone texture, memory and touch testing. |
| [#32](https://github.com/seedds/nxnative/pull/32) NVN: alpha test through a fragment variant; parallel prewarm; alpha-tested pipelines built in the background | `0c0d8f3d1709` | Graphics candidate | Alpha-test variants can fix foliage, but first-use draws are deliberately skipped while compilation runs. Requires scene comparisons and cold/warm cache tests before adoption. |
| [#76](https://github.com/seedds/nxnative/pull/76) Breath of the Wild above 60 fps and above 1080p (reworked from #62) | `b84966ae37da` | Game-specific candidate | BotW variable frame step and resolution changes require exact registered builds and timing tests. No established Dread benefit; higher caps also need thermal validation. |
| [#102](https://github.com/seedds/nxnative/pull/102) Mac: add optional Xbox letter-based controller mapping | `36afdfa28893` | Mac-only option | Xbox label preference is opt-in and overlaps Nintendo detection proposals #180/#295. Choose one mapping policy, then test real controllers. |
| [#104](https://github.com/seedds/nxnative/pull/104) Mac: native AppKit app bundle, preferences, and controller mapping | `48c615d25dd4` | Defer broad frontend replacement | Mac app packaging, save locations and preferences overlap already-existing upstream Mac packaging. Reconcile save migration and current packer before considering it. |
| [#126](https://github.com/seedds/nxnative/pull/126) FINAL FANTASY RESONANCE HK 1.0.1 (0100B8A026F14000): the game profile | `309722488d99` | Superseded profile candidate | Same title ID overlaps #289/#304; compare builds and regenerated tables. Prefer the newer, smaller validated profile series rather than stacking all three. |
| [#160](https://github.com/seedds/nxnative/pull/160) Xenoblade Chronicles 2 (0100F3400332C000, JP 3.0.0, SDK 3.5) on the Mac host, with Torna | `bdbf8eb2c854` | Game-specific candidate | Xenoblade 2/Torna adds SDK 3.5, audio, movie and frame-step behavior. Mac evidence does not validate iOS memory or frame timing. |
| [#167](https://github.com/seedds/nxnative/pull/167) Textures: upload CPU-written linear and unflushed sampled textures | `e4dc169c7662` | General rendering candidate | CPU-written linear and unflushed sampled texture upload paths can help several games. Requires dirty-page, alias and CPU/GPU synchronization regressions before adoption. |
| [#171](https://github.com/seedds/nxnative/pull/171) Add native SM and CSRNG IPC transport | `52c5daa90308` | Architecture candidate | Native SM/CSRNG transport can reduce SDK symbol interceptions. Large service-memory and handle-lifetime surface; run adversarial IPC and thread-safety tests before replacing working paths. |
| [#173](https://github.com/seedds/nxnative/pull/173) SHIN MEGAMI TENSEI V (010063B012DC6000, 1.0.0): game profile, version 8 Unreal paks, sparse virtual pools, 60 fps and an iOS Screen setting | `f5e632cf5f89` | Game-specific candidate | SMT V combines profile, sparse pools and iOS aspect modes; depends on #263. The aspect changes also touch the editor's coordinate assumptions and need device testing. |
| [#176](https://github.com/seedds/nxnative/pull/176) Trails in the Sky 1st Chapter (01001E9023920000, update 1.0.6.1): game profile, plus general fixes to the rewriter, the GLSLC split, the shader build and the NVN layer | `887a4f058ebf` | Game-specific candidate | Trails adds rewriter, scanner and NVN changes as well as a region-specific profile. Rebuild shader chain and check exact regional build; IPA build alone is not gameplay validation. |
| [#179](https://github.com/seedds/nxnative/pull/179) Add physical keyboard support on iOS | `f661323a779d` | Input candidate | Physical keyboard support changes control visibility and focus cleanup. Must retain editor access and test keyboard/controller connect, disconnect and stale callbacks together. |
| [#180](https://github.com/seedds/nxnative/pull/180) Map Nintendo controller face buttons by label on macOS and iOS | `fccf98362334` | Input candidate | Nintendo label detection is small and relevant on iOS, but overlaps #295 on Mac. Test Pro/Joy-Con and Xbox/PlayStation hardware before changing mappings. |
| [#181](https://github.com/seedds/nxnative/pull/181) Unicorn Overlord, Asian release (010054B01AD92000, 1.05): game profile | `691dd43ef6d3` | Low-scope profile candidate | Asian Unicorn Overlord has independent title/build IDs and reportedly identical shader data. Import only for that release, verify build registration and profile tests. |
| [#186](https://github.com/seedds/nxnative/pull/186) Add NINJA GAIDEN Sigma profile (0100E2F014F46000) | `bb517566f820` | Game-specific candidate | Ninja Gaiden adds indexed Team Ninja archive parsing and ReadFile hook. Validate malformed archives, decompressed sizes and SDK ABI along with target-game playback. |
| [#188](https://github.com/seedds/nxnative/pull/188) Port Blasphemous and Blasphemous 2 | `603a60b780c9` | Game-specific candidate | Blasphemous offset-table fallback must remain uniquely bounded; Blasphemous 2 relies on the framed tail-call fix already in the base lineage. Run ambiguity regressions before import. |
| [#189](https://github.com/seedds/nxnative/pull/189) Intel Mac: build the shader translator for x86_64 and document the pipeline | `e7d470c15244` | Hardware-specific candidate | Intel translator launcher can help Intel build hosts, while runtime shader/Oodle capture still needs a native decoder. Do not treat universal launcher as universal game execution. |
| [#192](https://github.com/seedds/nxnative/pull/192) Snapshot Mario Wonder's two same-pass feedback draws | `2d5fd5b29e1e` | Narrow game fix | Wonder's two feedback snapshots can address flicker; only affects that profile. Compare affected scenes and GPU/attachment cost on the actual version. |
| [#193](https://github.com/seedds/nxnative/pull/193) Super Mario 3D All-Stars: multi-program applications, nn::jit served on iOS, and an opt-in in-process program switch | `2c859258934d` | Defer large lifecycle series | 3D All-Stars combines multi-program packaging, JIT, services and program switching. Major lifecycle and iOS changes; validate separately, including rejected 32-bit Galaxy path. |
| [#194](https://github.com/seedds/nxnative/pull/194) Mac fullscreen: present without the display link, so 60 fps games no longer drop to 30 | `e20c2a5f4dc3` | Mac-only rendering candidate | Fullscreen display-link workaround addresses Mac 60-to-30 drops, not demonstrated iPhone behavior. Test fullscreen, variable refresh and pacing regressions. |
| [#209](https://github.com/seedds/nxnative/pull/209) Add NxNative Converter, a native Mac app over the NSP script's mac-app build | `acdd8dc6c873` | Mac GUI candidate | Converter manages dependencies and builds but also signing and engine selection. Preserve this private source checkout and unsigned-only policy if adopting any frontend. |
| [#210](https://github.com/seedds/nxnative/pull/210) Save Folder Sync | `c077af7904bd` | Defer save synchronization | Folder import is asynchronous around gameplay startup. Require proof that mounting/game writes cannot race import, plus fault injection and recovery on disposable saves. |
| [#216](https://github.com/seedds/nxnative/pull/216) Diagnostics: texraw by level, A2C pass-dump fields, probe filter comparisons | `99f893b8c674` | Diagnostic candidate | Texture-level dumps, A2C fields and probe comparisons help bring-up. Not a speed feature; check dump boundaries and packaged-resource resolution. |
| [#218](https://github.com/seedds/nxnative/pull/218) Yoshi's Crafted World: profile, sparse texture layout, GPU copies into texture storage | `32e696b8c5d6` | Game-specific candidate | Yoshi needs sparse layouts and GPU writes into texture storage, with Mac evidence. Combine carefully with #300 and rebuild/test shader dependencies before iPhone use. |
| [#221](https://github.com/seedds/nxnative/pull/221) Add Steam Controller (2026) support on macOS | `f7c2f2f10543` | Mac controller candidate | Steam controller adds HID, haptics, motion and player ownership. Requires the actual hardware plus multi-controller, reconnect and focus tests; no direct touch-editor benefit. |
| [#227](https://github.com/seedds/nxnative/pull/227) docs: record Persona 5 Royal Mac build and iPhone installation checkpoint | `2e835c72451d` | Documentation only | Persona 5 note explicitly distinguishes install acceptance from gameplay. Useful evidence, no runtime improvement and no reason to replace the existing recipe. |
| [#231](https://github.com/seedds/nxnative/pull/231) audren: drive a concurrent secondary renderer | `69531352b9ee` | Audio candidate with limitation | Secondary renderer advances at about 5 ms but its DeviceSink PCM is discarded. Verify this is intended for each game, and test close/join races before general use. |
| [#233](https://github.com/seedds/nxnative/pull/233) games: fix War in the North job worker wake | `36fc9b37baf8` | Narrow game fix | War in the North changes an event clear-mode instruction. Keep exact build-ID gate; verify worker wake behavior and absence of lost work in that title. |
| [#234](https://github.com/seedds/nxnative/pull/234) nvn: capture runtime shaders at ProgramSetShaders | `75fd1b28b8ea` | Bring-up diagnostic candidate | Runtime shader dumping can recover variants missed offline. Validate guest control/code bounds and capture deduplication; keep captured game shaders outside Git. |
| [#236](https://github.com/seedds/nxnative/pull/236) Bring up 30XX: SDK in subsdk modules, GL 4.5 / ES probe, GLSL 1.20, sampler slots | `dffb26f608f4` | Compatibility candidate | 30XX generalizes SDK discovery to subsdk modules and adds GL/EGL and sampler handling. Run GL shader, SDK discovery and existing NVN/Vulkan regressions before adoption. |
| [#239](https://github.com/seedds/nxnative/pull/239) Mac: default the game language to the Mac's own | `11e1ea583376` | Mac localization candidate | Preferred-language discovery is Mac-only and explicit language wins. Our iOS wrapper persists the selected language already; no iOS benefit from importing this series. |
| [#252](https://github.com/seedds/nxnative/pull/252) Decode Oodle GFPAKs, fit Arceus's and Z-A 1.0.0's address space, add NVN dual-source blending | `ebc3bc409d47` | Game-specific candidate | Oodle GFPAKs, address-space cuts and dual-source blending may unlock Arceus/Z-A builds. Requires chain rebuild, precise build gates and visual/gameplay validation. |
| [#255](https://github.com/seedds/nxnative/pull/255) Save sync through a cloud folder for the Mac and iOS apps (DM_SAVE_SYNC) | `57659f59e0f7` | Preferred save-sync research candidate | Single-file archives and transaction hooks are a stronger starting point than mixing with #210. Still require interrupted-copy, rollback, conflict and unavailable-cloud tests on disposable saves. |
| [#258](https://github.com/seedds/nxnative/pull/258) iOS: add optional swipe camera and touch-control settings | `27339e1e3d4b` | Optional input candidate | Swipe camera/deadzone helpers have useful tests but the PR remains draft pending integrated device testing. Reconcile DmGamepad changes with our editor before any merge. |
| [#263](https://github.com/seedds/nxnative/pull/263) Image atomics on buffer images: declared as buffers, and an unbound one gets a buffer placeholder and an atomic scratch of its own (general, from SHIN MEGAMI TENSEI V) | `46b6aa45112b` | General graphics candidate | Buffer-image type and unbound atomic scratch address concrete admission failures. Related fixes now also exist in later upstream commits; compare first to avoid duplicate or older implementations. |
| [#265](https://github.com/seedds/nxnative/pull/265) Add an opt-in performance overlay to the Mac game window | `633816faa76f` | Mac diagnostic candidate | HUD counters and system load can help measurements; overlap game profile and host state. Check sampling overhead and thread safety; no demonstrated iPhone FPS gain. |
| [#268](https://github.com/seedds/nxnative/pull/268) Cheats: an Atmosphère-format engine, build-time baking and an in-game menu | `c84153fbbbc3` | Defer optional cheat engine | Adds memory writes, executable baking and a runtime menu. Separate from automated builds and compatibility; requires opcode bounds, build matching and pause/thread testing before opt-in adoption. |
| [#269](https://github.com/seedds/nxnative/pull/269) Pokémon Violet: profile, Bluetooth LE takeover, ConservativeRasterDilate stub | `9bd4ec05fcbf` | Game-specific candidate | Violet profile includes Bluetooth service and rasterization stub. Mac opening evidence plus an acknowledged image-atomic warning does not establish correct iPhone gameplay. |
| [#273](https://github.com/seedds/nxnative/pull/273) Mac host: unrolled-switch jump tables, multi-output transform feedback, MGFX reader tolerance (Silksong, Tale of Immortal, Pokkén DX, Stardew Valley) | `028f8b248add` | Compatibility candidate | Jump-table reach, transform-feedback layout and MGFX tolerance can help several titles. Broad translator/binary changes require chain regeneration and cross-game regression comparisons. |
| [#275](https://github.com/seedds/nxnative/pull/275) dmsh_build: build only the metallibs a target needs (an iPhone build skips the macOS half) | `a64310864462` | Hold: cache correctness issue | cache_outputs gates the entire mac group, including _b.json/_b.metal, when selecting ios only; downstream analysis still consumes those products. Reproduce clean-output cache-hit restoration and fix metadata caching first. |
| [#277](https://github.com/seedds/nxnative/pull/277) Fix NSP extraction space estimates | `841684012800` | Integrated and tested | Count unique archive paths instead of unique byte sizes. Exact source patch and three synthetic regressions adopted; no shader, game profile or runtime change. |
| [#278](https://github.com/seedds/nxnative/pull/278) build_ipa_from_nsp: --platform takes a list, so one run builds the IPA and the Mac app | `a0f4d41e1e15` | Hold on dependency | Multi-platform CLI is stacked on #275 and carries its target-selection changes. Repair and validate target-specific cache restoration first, then test each platform combination. |
| [#280](https://github.com/seedds/nxnative/pull/280) Add native macOS app for building ports and installing on paired iOS devices | `05715be61396` | Defer broad GUI series | Spanish GUI also includes scheduler, extraction and shader changes and device signing/install. Extract independent fixes; keep unsigned automation and editor base rather than import the whole application. |
| [#282](https://github.com/seedds/nxnative/pull/282) shader_split: one unreadable archive no longer stops the split; retry a crashed Metal compiler | `48192496c829` | Hold: error masking | scan_file catches every Exception and returns an empty shader set, so a build may succeed with omitted shaders. Separate compiler-signal retry from scanner policy; require explicit incomplete-build reporting. |
| [#285](https://github.com/seedds/nxnative/pull/285) Add FINAL FANTASY CRYSTAL CHRONICLES Remastered Edition (1.0.3) | `e79692b58fa1` | Game-specific candidate | Crystal Chronicles profile uses build-gated Unity memory-order cuts. Verify registered instruction bytes, worker stress and iPhone behavior; newer Unity TextAsset scanner changes are separately upstream. |
| [#286](https://github.com/seedds/nxnative/pull/286) iOS: six-axis gyro aiming from the controller (and the device in handheld) | `0cd0e1658246` | Hold: synchronization review | dm_motion_set writes g_mot_t under g_mot_mu, while mot_fresh reads it without that lock. Fix synchronized snapshots and run race/focus/disconnect tests before gyro adoption. |
| [#289](https://github.com/seedds/nxnative/pull/289) FINAL FANTASY RESONANCE (Korean release, 0100B8A026F14000): the game's own profile and the full shader table | `10fc65d5871b` | Superseded profile candidate | Large FFR regional series overlaps #126/#304 and changes common extraction/allocator paths. Compare exact title/build IDs rather than relying on conflicting region labels. |
| [#295](https://github.com/seedds/nxnative/pull/295) Mac: map a Nintendo controller's face buttons by label | `9a9500bbcb13` | Mac input candidate | Nintendo label detection plus override overlaps #180. Candidate for a unified mapping helper; reported Mac Pro Controller test does not validate iOS. |
| [#296](https://github.com/seedds/nxnative/pull/296) Mac: controller motion (Switch Pro Controller gyro over HID) | `f1a254912389` | Mac motion candidate | Pro Controller HID supplies motion when GameController reports zero. Reconcile with #221/#286 instead of stacking alternate motion APIs; test calibration, axes, drift and ownership. |
| [#297](https://github.com/seedds/nxnative/pull/297) pso_offline: leave pairs metal-tt cannot link to the device | `7d8cfcee455e` | Hold pending root fix | Leaving unlinkable pairs out can salvage an archive but does not restore missing vertex outputs. Prefer #298's padding fix; also verify cache stamp sensitivity to --leave changes. |
| [#298](https://github.com/seedds/nxnative/pull/298) Shader build: pad the vertex shaders of the prebuild's own pairs | `8c81c6e7d152` | High-priority graphics candidate | Padding pso_pairs as well as shader_pairs addresses missing stage outputs at their source. Changes chain version and rebuilds every game; validate fresh and cached builds and visual regressions separately. |
| [#299](https://github.com/seedds/nxnative/pull/299) Port Good Job! to native Mac | `28fbf0af4f98` | Game-specific candidate | Good Job combines profile, Unity timing and Mac launcher/window changes. Separate reusable UI from title-specific frame-step patches; Mac metrics do not validate iPhone. |
| [#300](https://github.com/seedds/nxnative/pull/300) Keep the automatic block height for sparse textures smaller than a tile | `04d16458249b` | High-priority texture candidate | Sub-tile sparse textures must keep automatic block height. Has synthetic layout tests and a concrete Yoshi symptom; apply with the related sparse-layout series and cross-format tests. |
| [#301](https://github.com/seedds/nxnative/pull/301) Mac: MetalFX frame interpolation (30+30) for Breath of the Wild 1.9.0, ported from MacNativeGames | `57c74b0632f4` | Mac experimental feature | BotW MetalFX interpolation is opt-in and adds latency, frame hooks and game assumptions. Not an iPhone FPS fix; isolate and compare UI/motion artifacts on supported hardware. |
| [#302](https://github.com/seedds/nxnative/pull/302) Pack a Mac app into a disk image with a ready-made window | `ff9727c980c1` | Mac packaging only | DMG window/background automation is useful for Mac distribution, not IPA installation. Finder automation permissions and fallback need testing if Mac delivery becomes a goal. |
| [#303](https://github.com/seedds/nxnative/pull/303) DM_NVN_POOLPEAK: how full a game's render target pool gets | `f3c8b0496dcc` | Diagnostic candidate with lifecycle review | Pool high-water tracking can guide memory sizing. Static pool-pointer tracking needs concurrency/lifetime checks; it measures pages ever used, not current live allocations or FPS. |
| [#304](https://github.com/seedds/nxnative/pull/304) Add the Hong Kong release of FINAL FANTASY RESONANCE as a game profile | `3b32d7d6c3bd` | Preferred FFR profile research candidate | Newer FFR regional profile includes translator/host defects and claimed iPhone evidence. Avoid stacking #126/#289; chain binaries and tables require full reproducible regression builds. |

## Changes already integrated by upstream after our base

These commits are present on upstream main but have NOT been merged into the personal
branch. Closed PRs may have been reworked or squashed, so compare integrated commits
rather than reapply the closed PR patch. The original stable Dread caches are preserved.

| Commit | Change | Recommendation |
|---|---|---|
| [`4639c5114cbb`](https://github.com/seedds/nxnative/commit/4639c5114cbb8a8f250645941fa3a25c1ba08cc6) | Pack shader pairs and the offline pipeline archive into Mac apps (#241, #260) | Future compatibility/tooling candidate; evaluate in isolated update with relevant regressions. |
| [`1c857cae4bb4`](https://github.com/seedds/nxnative/commit/1c857cae4bb44e56208afcf0a52069dbdef9c18a) | shader_split: read GLSLC outputs kept in Unity TextAssets | Future compatibility/tooling candidate; evaluate in isolated update with relevant regressions. |
| [`7c5b0b2a789e`](https://github.com/seedds/nxnative/commit/7c5b0b2a789e289b220ada076bdac437eba56450) | Shader split: open HAL's .cmp containers | Future compatibility/tooling candidate; evaluate in isolated update with relevant regressions. |
| [`eb858ec51ad6`](https://github.com/seedds/nxnative/commit/eb858ec51ad65f95d6df6ecfb67bff853e3f07d3) | Shader split: check a size-prefixed frame's own size first, bound TextAsset reads (#203, #238) | Future compatibility/tooling candidate; evaluate in isolated update with relevant regressions. |
| [`e72991d8ca4d`](https://github.com/seedds/nxnative/commit/e72991d8ca4dffdab7bb27765f3f071106d92b16) | NVN on Metal: remove Metal's archive build folders, cap texture fields Metal refuses, 8-byte hash keys as one word (general, from MacNativeGames) | Future compatibility/tooling candidate; evaluate in isolated update with relevant regressions. |
| [`2e655b79bfdc`](https://github.com/seedds/nxnative/commit/2e655b79bfdc86b2967ad0c0b3305e260ad6228f) | Port SHIN MEGAMI TENSEI V: Vengeance 1.0.3 at 60 fps | High-value compatibility work; new chain requires rebuilds and cross-game regression tests. |
| [`ce9b30b01093`](https://github.com/seedds/nxnative/commit/ce9b30b01093b22eb03a6dab14058cddca43b9b2) | Port Sea of Stars 2.0.59001 at 60 fps | Future title profile; verify exact version, memory and device gameplay. |
| [`933b67590c74`](https://github.com/seedds/nxnative/commit/933b67590c742bb28c2b2361bbc5de6939a7681f) | Port OCTOPATH TRAVELER 1.0.5 (Unreal Engine 4.18, SDK 3.5.1) | Future title profile; verify exact version, memory and device gameplay. |
| [`1402ded2d905`](https://github.com/seedds/nxnative/commit/1402ded2d90521ab70ededbc55aab4705515064b) | BotW 1.9.0: held-button counts step by the VFR ratio (menu repeat in game time at 60 fps); archive build folders never taken at a recapture; unsupported sample counts not made | Future compatibility/tooling candidate; evaluate in isolated update with relevant regressions. |
| [`4db4c69f0b9d`](https://github.com/seedds/nxnative/commit/4db4c69f0b9da126e61b236a6f1ed4ac25144404) | Port Donkey Kong Country: Tropical Freeze 1.0.2 | Future title profile; verify exact version, memory and device gameplay. |
| [`0963959f2fc2`](https://github.com/seedds/nxnative/commit/0963959f2fc2c31d3d2c84a3e9429f85a34a6008) | Fix startup deadlock in blocking notification waits | General correctness candidate; run transaction/thread/wait tests before runtime update. |
| [`a2e1c1d8a629`](https://github.com/seedds/nxnative/commit/a2e1c1d8a6297e7248849381fc822c6d05ea20df) | Refresh host test fixtures for heap and audio event changes | Mac-only candidate; no need for current iPhone workflow. |
| [`a0841d6b3c9b`](https://github.com/seedds/nxnative/commit/a0841d6b3c9b4463f472ca6b86e60be87bf6c671) | Isolate save failures by backing transaction | General correctness candidate; run transaction/thread/wait tests before runtime update. |
| [`99d0aae38f32`](https://github.com/seedds/nxnative/commit/99d0aae38f329c08fca3552436a23333b34f7bf4) | Keep bindless reads through mixed handle phis; read misaligned buffer textures through an aligned copy (#168) | High-value compatibility work; new chain requires rebuilds and cross-game regression tests. |
| [`b117c9131721`](https://github.com/seedds/nxnative/commit/b117c913172120520f01028bd42e3b2d55d9f7af) | Check translation chain changes on games their author does not own (#272) | High-value compatibility work; new chain requires rebuilds and cross-game regression tests. |
| [`89744da75364`](https://github.com/seedds/nxnative/commit/89744da75364ba1847dfbd25f5a82a57d8f1ccb1) | Discover Homebrew .NET runtimes for standalone build tools | Tooling candidate; test Homebrew runtime discovery and caller overrides. |
| [`09f3778c366f`](https://github.com/seedds/nxnative/commit/09f3778c366fabc2b02b3bf4ae340bb7ce40c2d9) | Make repeated IPA and Mac app builds incremental (#279) | Tooling candidate; test clean/reused archive equality and corrupted/changed inputs. |
| [`53843cc7d5d8`](https://github.com/seedds/nxnative/commit/53843cc7d5d81eea4acbe4b1c99903632989bb67) | Port Donkey Kong Country Returns HD 1.1.0 | Future title profile; verify exact version, memory and device gameplay. |
| [`06b7b3e56303`](https://github.com/seedds/nxnative/commit/06b7b3e56303bc67213a98cae61925f9253bdf89) | Share finite SyncWait budget across event and feedback waits (#274) | General correctness candidate; run transaction/thread/wait tests before runtime update. |
| [`40b643bbe688`](https://github.com/seedds/nxnative/commit/40b643bbe68861d171cb1a2733a953aa739f9ac1) | Keep Mac audio buffers near 5 ms across output changes | Mac-only candidate; no need for current iPhone workflow. |

## Reproduce the inventory

Run `python3 scripts/review_upstream.py --output /path/outside/repo/new-review`.
It archives every open PR, full changed-file metadata, check results and a head-pinned
diff, plus the comparison against the stable base. It applies nothing and never merges.
The generated archive belongs outside Git: it may be large, and source snapshots are
untrusted review material. Do not execute commands copied from a PR description.

## Local validation and limits

The personal automation has synthetic tests for archive path/credential rejection,
partial-output cleanup, original preservation, unsigned build checks, identity
persistence, cancel-free dry runs, and full-to-light export. The app-only path was also
run against the existing Dread caches and real unsigned build. A first-time extraction
of a different game, fresh shader compilation, iPhone gameplay, and the deferred PRs
were not validated in this session. Signing remains the user's Sideloadly step.
