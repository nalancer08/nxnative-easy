# Mario Kart World review — 2026-11-03

> Historical review: superseded by the [2026-11-05 integration](2026-11-05.md), which imports the now-merged Mario Kart World profile.

This is a topic review, not an upstream merge or a gameplay claim. The fork
remains integrated through `4a2a81a64f029d0a75ade9523c8ffc6c89465375`. Fetched upstream
main was frozen at `bd688163afea8a7cf6d5e5f889e177ad1d589711`; it has no
`dm/games/0400C3F00006E000` profile. No unrelated main commits were imported.

## Owner-supplied input

Read-only inspection of `<selected folder>/MKW [ROM]` found a complete extracted
input layout, `base/exefs` plus `base/romfs`, program ID `0400C3F00006E000` and
internal base version **0**. Its main build ID begins
`9e244438c3d8ef1c703a6a85ef99c4f0`. No update directory was present; display
version/name were unavailable from the supplied control metadata. The payload
contains main, sdk and subsdk0, unlike the 1.8.0 proposal's four-module set.
Inspection reported `profile_missing`, examined 205,788 source entries and did
not compile/extract a game, execute the adjacent Windows emulator, read console
keys or change a save. The supplied executables/DLLs were not used.

## Current proposals

| Proposal | Reviewed head / state | Relevance |
| --- | --- | --- |
| [#900](https://github.com/seedds/nxnative/pull/900) | `02fcb8068ff289eec04730019506ca67678ca0f5`, open **draft** | Profile and shared host/rendering/translator changes. Author reports Mac races in **1.8.0**, v917504; iOS untested. |
| [#982](https://github.com/seedds/nxnative/pull/982) | `dacec52315062bda9145b001bb5a8e9f0ac0b11e`, open | SDK 19 video/sync-point forms and shading-rate calls. |
| [#983](https://github.com/seedds/nxnative/pull/983) | `b124b24a0af5ca9f96a15f92482357bb28d55573`, open | Task/mesh shaders used by grass; author distinguishes base v0 from 1.8.0. |
| [#1056](https://github.com/seedds/nxnative/pull/1056) | `630151a299e27d554a030edc990fb347a3b01133`, open | SURED and concrete Ampere shared-stride tests. |
| [#834](https://github.com/seedds/nxnative/pull/834) | `c73dd36280b1e48d8bbe71231b351ce6a1ca8263`, closed, not merged | Earlier broad bring-up, not a ready profile to copy. |

The current #900 profile registers main build `d00e4f399e411d0613aa8d26b1c02fef`
for 1.8.0. That is not the supplied base build. Its 9-GB application pool,
sparse placement textures, first-use storage rule and shared-memory spill affect
other games. The author lists unclosed defects: duplicate threadgroup-grid
parameters in a spill case, unfreed camera sessions/heaps, partially mapped sparse
tile contents and an unmeasured per-bind view check. Its broad game regression
is explicitly not run. Importing only its profile or applying its fixed build
assumptions to v0 would not provide supported gameplay.

## Decision and next gate

Keep #900 and its dependencies out of the stable engine until isolated review,
version-appropriate patch/table validation, host/GPU regressions and exact-build
gameplay evidence are available. The current feature work does not recompile or
replace the owner's working games. A separate bring-up can use this base dump,
but must validate that build rather than relabel a 1.8.0 report.

The desktop now has a separate pending-proposal record keyed by the inspected
program ID. It can identify the proposal, show its reported Mac version and link
the source. It never changes `PackageInspection.ready`, the compiler guard, the
supported catalog or its galleries. Unknown/unmerged proposals are not counted
as supported games. No physical iPhone or Mario Kart World gameplay was tested.
