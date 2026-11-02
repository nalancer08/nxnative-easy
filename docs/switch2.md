# Switch 2 games in nxnative Easy

The integrated engine includes upstream Switch 2 execution and Ampere shader
translation through `4a2a81a64f029d0a75ade9523c8ffc6c89465375`.
[Donkey Kong Bananza](../dm/games/040074A01BF12000/README.md),
[Splatoon Raiders](../dm/games/0400380020056000/README.md) and
[Fire Emblem Fortune’s Weave](../dm/games/04007EF01F8AE000/README.md) have Mac
profiles and limited upstream gameplay evidence. That evidence does not establish iPhone/iPad support
or compatibility with every Switch 2 game. Mario Kart World has no registered
profile in this release.

## Prepare a supported game

1. Open Easy, choose **Add game**, then **Mac**.
2. Choose your own extracted game folder. Easy reads its NPDM program ID and NSO
   build ID, lists the available updates and identifies the registered profile.
   It does not need keys for already extracted content.
3. Check the identity and selected version, then prepare the game. Stages, actual
   work counts and compiler logs remain visible. The result is a complete Mac
   app with its RomFS image inside. No separate content copy is needed on Mac.

Required layout (updates and DLC are optional):

```text
MyGame/
  base/
    exefs/                        main, main.npdm, sdk, rtld, …
    romfs/
  updates/
    458752/                       numeric title version, not the display version
      exefs/
      romfs/                      complete patched tree for this update
  dlc/
    <DLC title ID>/0/romfs/
```

An update's RomFS must already be the complete patched tree. It is not overlaid
on the base: files deleted by the update must stay deleted in the prepared image.
Do not combine two different games or encrypted packages and a dump in one input
folder. Easy rejects links/special files and changed preflight identities before
preparation. Source folders stay untouched; new build outputs are separate.

A dump normally has no control NACP/icon. Its name comes from the matching
profile. A display version is shown only when its executable build matches a
registered display version; otherwise Easy shows the numeric internal version.
Do not guess a game or display version from a folder's friendly name.

## Other titles, including Mario Kart World

The common engine work is a foundation, not a ready profile for every title.
An unregistered dump is identified but is not prepared as a supported game.
Bringing up another title needs its own executable/import analysis, memory and
service behavior, shader extraction/tables, renderer validation and gameplay
route. Reusing Bananza's fixed patches or declaring success after compilation
would not establish compatibility.

Encrypted Switch 2 NSP/XCI extraction is not provided by this integration. This
project does not supply game files, keys, firmware or a dumping service.

Fire Emblem’s SDK 22 modules use ZBIC compression. Easy includes its pinned
decoder in the portable tools; source-checkout setup installs the same package.
Its AV1 movies require a hardware AV1 decoder: the upstream note reports black
movies on Macs without it. Read each game note for remaining shader, performance
and route-coverage limits; these profiles are not whole-game certification.

## What changed in the core

- Ampere shader decoding/translation alongside the existing Maxwell path;
  tensor HMMA lowering to Metal SIMD-group matrix operations.
- NVN2 compute constants, push constants, device values and texture GOB order;
  mesh/geometry sizing, loaded-pointer writes and synchronization improvements.
- Switch 2 codec/video services and its 31.25 MHz timing behavior, plus the
  registered Bananza executable/shader profile.

These changes are shared engine code. Existing game apps need preparation again
to gain them; updating Easy alone cannot change a previously compiled game.
Existing installed games continue using their current runtime and saves until
you deliberately update them. Preserve the same bundle identity for an update.
