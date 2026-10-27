# Packing

## Build tools

### Homebrew .NET is on PATH but apphosts cannot find the runtime

- **Symptom:** the first extraction stops with `nx_extract exit code 131` and `.NET location: Not found`, even though `dotnet` is on `PATH`. The shader translator can fail the same way.
- **Cause:** standalone .NET apphosts search runtime roots and registered installations, not `PATH` ([.NET runtime discovery](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-environment-variables#dotnet_root-dotnet_rootx86-dotnet_root_x86-dotnet_root_x64)). Homebrew's formula installs the runtime under `libexec` and its `bin/dotnet` can be a wrapper that sets `DOTNET_ROOT` only for its own child ([Homebrew caveat](https://formulae.brew.sh/formula/dotnet)). Resolving that wrapper's symlink gives `bin`, not the runtime root.
- **Fix:** `scripts/build_ipa_from_nsp.py` `configure_dotnet` derives the root from the `Microsoft.NETCore.App` entry in `dotnet --list-runtimes`, using the build's environment, before any extraction or survey. It exports `DOTNET_ROOT` both to that environment and to `os.environ`, for tools launched with an explicit environment and those that inherit it. Caller-supplied roots, including architecture-specific overrides, retain precedence. A failed or malformed probe leaves the environment unchanged rather than guessing the wrapper's directory.
- **Found on:** [Balatro](../../dm/games/0100CD801CE5E000/README.md), first extraction with Homebrew .NET ([PR #284](https://github.com/seedds/nxnative/pull/284)). Applies to every game's build on that installation setup.

## IPA archives

### A streamed file changes size and the IPA fails its CRC check

- **Symptom:** packing succeeds, but `unzip -t` or Python's `ZipFile.testzip()` reports a bad CRC for a large deflated file.
- **Cause:** `pack_ipa.py` wrote the uncompressed size collected before reading. Its streaming check compared the output size only for stored files, so a compressible file that grew or shrank still published an archive with the old size.
- **Fix:** count uncompressed bytes as they are read and compare them with the listed size before completing either streamed method. A mismatch stops the pack and removes the partial archive, preserving the previous IPA and its reuse index. Regression tests cover growth and shrinkage with both deflate and store.
- **Found on:** synthetic IPA inputs while reviewing [PR #279](https://github.com/seedds/nxnative/pull/279); no game files required.

## Compressed inputs

### NSZ decompression rejects `--keys`

- **Symptom:** `decompress NSZ` stops immediately with `nsz: error: unrecognized arguments: --keys …`.
- **Cause:** `nsz` 4.6.1 has no `--keys` argument. It loads `keys.txt` beside `sys.argv[0]`, or falls back to `~/.switch/prod.keys`, while importing its modules, before parsing arguments ([4.6.1 key loader](https://github.com/nicoboss/nsz/blob/4.6.1/nsz/nut/Keys.py)). Newer upstream code supports `--keys`; staging `keys.txt` also supports 4.6.1.
- **Fix:** `scripts/build_ipa_from_nsp.py` `decompress_nsz` links the file selected by `-k` as `keys.txt` in the conversion's temporary folder and runs `nsz -D` there, with `sys.argv[0]` set to `nsz` before import. Input and output paths are absolute. The temporary folder and link are removed on success or failure; the user's default keys are untouched.
- **Found on:** [Super Mario Odyssey](../../dm/games/0100000000010000/README.md), converting its v0 NSZ. Applies to NSZ and XCZ inputs for every game.

## Desktop build worker

### Prepare game fails at `os.setsid()`

- **Symptom:** clicking Prepare game stops before any build tools start, with `PermissionError: [Errno 1] Operation not permitted` at `build_session.py` `os.setsid()`.
- **Cause:** Foundation `Process` already launches the worker as its own process-group leader on macOS. POSIX rejects `setsid()` for a group leader. A normal Python subprocess launch did not expose this difference, so the original regression test missed the GUI path.
- **Fix:** reuse the existing group when `os.getpgrp() == os.getpid()`; call `setsid()` only for a worker that still shares its parent's group. Cancellation still signals the worker's separate group. Do not suppress unrelated permission failures. Added regression coverage for Foundation `Process`, an existing group leader, an existing session leader and a normal subprocess launch, including cancellation.
- **Found on:** a user's clean desktop installation, before game detection; reproduced locally with a Swift Foundation launcher. Applies to every Mac/iPhone game preparation, independent of the game, keys or saves. Released in 1.4.2/build 7.

### Graphics regression command fails in a workspace path containing spaces

- **Symptom:** `check_t_transform_feedback` reports `Code/.../t_transform_feedback: No such file or directory` before running its checks.
- **Cause:** the Makefile passed `$(CURDIR)` into a shell environment assignment without quoting; the space split the executable path into a command.
- **Fix:** quote the complete `DM_TEST_TRANSFORM_FEEDBACK` value.
- **Found on:** the full upstream-main integration in this fork's `Claude Code/ios_games` workspace; independent of game data.

### Bundled-pipeline regression fixture targets a newer macOS than the host

- **Symptom:** `t_pso_bundle` builds an archive but reports ten failures after Metal rejects its deployment target.
- **Cause:** the fixture used `pso_offline.py`'s SDK-major default (27) on a Mac running macOS 26.6. Production intentionally falls back to compiling bases on-device when it cannot load such an archive.
- **Fix:** the native fixture explicitly passes the current macOS major as `--os-min`, so it tests archive reuse on the system actually running it; keep its scratch fixture on failure for diagnostics. Production fallback remains intact.
- **Found on:** full-main GPU validation with Xcode 27.1 on macOS 26.6.1, Apple M2 Max.

### Desktop preparation shows a spinner with no build activity

- **Symptom:** preparation appears stuck; the player cannot inspect compilation output until a failure.
- **Cause:** the UI hid its transcript unless `failed` was true, parsed only coarse text fragments, and did not surface the compiler logs that the upstream builder intentionally writes separately.
- **Fix:** request upstream JSON progress through the wrappers, frame complete UTF-8 records in the native model, and show stage counters/fractions only when reported. The group-preserving worker streams console output and bounded tails of changed regular per-tool logs, retains a private session log and preserves the original complete compiler files. The UI exposes both log locations, elapsed time, a quiet-output notice and error details; preview truncation never deletes the original logs. Mac rebuilds retain bundle/Title ID metadata; a previous preparation is not evidence of an iPhone installation.
- **Found on:** desktop builds reported by the repository owner; validated with synthetic streaming/rotation/failure/cancellation fixtures and the production Swift model. See [personal desktop workflow](../personal-ios.md#live-preparation-logs-and-game-updates).

### Native sideload toolchain install rejects a workspace path with spaces

- **Symptom:** the official Rust component shell installer rejects part of `--prefix` as an unknown option; a partial LLVM setup can also make `rust-objcopy` fail to load `libLLVM.dylib`.
- **Cause:** the installer splits a prefix containing spaces, while the new compiler's object tool requires its matching LLVM-tools component.
- **Fix:** install checksum-pinned official component manifests directly in an external cache, including LLVM-tools; validate archive paths/links and use an explicit ARM64 Cargo target. Keep the system Rust installation unchanged. Synthetic archive tests cover spaces, reuse and traversal refusal.
- **Found on:** the [native helper build](../sideloading.md#build-and-test) in this fork's workspace; no game or Apple account required.

### A sideload signer changes an existing game's bundle identifier

- **Symptom:** a replacement signer can append a second team suffix or produce another app identifier, separating the user from the existing app container.
- **Cause:** isideload 0.5.0 unconditionally appended the team ID to the supplied bundle ID, even when the caller already knows the effective installed identifier.
- **Fix:** the small vendored MIT patch preserves the caller's exact final ID. Our helper selects an actual existing device app, checks that it matches the game, verifies the signed/provisioned identity and never uninstalls the previous app to force an update. Original preparation IPAs stay unsigned. Tests cover custom identifiers and mismatch refusal; real-account/device migration still requires validation.
- **Found on:** source review and synthetic tests for the [integrated installer](../sideloading.md#user-flow), with no existing user installation modified.
