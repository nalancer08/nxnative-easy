# Switch 2 games in nxnative Easy

The integrated engine includes original main through `865cc35fad7034d17c2190f8ce349f61f5bcaba1` (2026-11-05). [Mario Kart World](../dm/games/0400C3F00006E000/README.md) now has its own executable/shader profile, alongside Bananza, Splatoon Raiders, Fire Emblem Fortune’s Weave, Pokopia, Star Fox, Mario Tennis Fever, Yoshi and Hyrule Warriors. Read each game note for its exact builds and tested platform. One title's Mac evidence does not establish support for every Switch 2 game or iPhone/iPad.

## Prepare a supported game

1. In Easy, choose **Add game → Mac**.
2. Select your own extracted folder or a folder containing one NUP. Easy checks metadata, identifies the title and executable build, and lists available updates before preparation. Already decrypted content needs no keys.
3. Review the identity/version, then prepare. Stages, actual work counts and compiler logs remain visible. The output is a complete Mac app, including its game data. No separate content copy is needed on Mac.

Required extracted layout (updates and DLC are optional):

```text
MyGame/
  base/
    exefs/                        main, main.npdm, sdk, rtld, …
    romfs/
  updates/
    458752/                       numeric title version, not display version
      exefs/
      romfs/                      complete patched tree for this update
  dlc/
    <DLC title ID>/0/romfs/
```

An update's RomFS must already be the complete patched tree. It is not overlaid on the base: files deleted by the update must stay deleted in the prepared image. NUP is an upstream decrypted container, not another name for an encrypted NSP. Its package metadata, executable and container integrity are checked without extracting the full game during identification. NUP and extracted inputs are currently exposed for **Mac** in Easy.

Do not mix encrypted packages, a dump and NUPs in one input folder. Easy rejects ambiguous input, links/special files and source identity changes before preparation. Source files remain untouched; build outputs are separate. Old cache cleanup remains opt-in.

A dump can lack control NACP/icon. The name then comes from its exact profile; display version appears only for a matching registered build. Otherwise Easy shows the internal numeric version, not a guess from the folder name. NUP control metadata supplies the real display version when present.

## Mario Kart World

The registered base executable (`9e244438c3d8ef1c703a6a85ef99c4f0`, internal version 0) matches the owner's extracted copy. The earlier Easy release did not contain this profile: shared Switch 2 engine support alone could not prepare this game. This integration adds its profile and the required renderer/host/shader changes together.

Local verification on 2026-11-05 translated all 11,561 Mac shaders, compiled and signed the self-contained Mac package, and reached an interactive race with a private test save (seven-minute run; first lap rendered, controls responded). This does not establish a completed race, all courses or iPhone/iPad support. The upstream note reports Mac gameplay and remaining issues; later game updates need their own matching-build validation. See [the review](upstream-reviews/2026-11-05.md).

## Scope and preservation

Encrypted Switch 2 NSP/XCI extraction is not provided. No games, keys, firmware or dumping service are included. AV1 movies now use the upstream dav1d software decoder as well as available hardware paths; older notes about hardware-only black movies describe the previous implementation.

The update imports Ampere/task/mesh shader work, NVN2 services, SDK fixes, memory/texture changes, multi-program packaging and cache improvements. It retains Easy's touch profiles, immutable cloud-save history, conflict copies, exact installation identities and explicit cleanup preview. Already installed game apps need preparation again to gain the new engine. Updating Easy alone does not replace their runtime or saves; keep their existing bundle/account identity when updating.
