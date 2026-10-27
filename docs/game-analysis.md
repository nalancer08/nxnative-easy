# Optional original-game analysis with REA

The normal preparation flow still uses nxnative's rewriter, profiles and Metal
translation chain. REA is an optional static-analysis companion, not a replacement
compiler, an AI agent or automatic compatibility for unsupported games.

## Desktop flow

1. Prepare your own game once, so its original NSO modules exist locally.
2. In the menu bar, choose **Analysis tools → Analyze with REA**.
3. **Export for analysis** converts the newest extracted original `main` NSO to an
   AArch64 ELF using the existing `dm/tools/nso2elf.py`. It does not analyze the
   rewritten host executable, run the game or edit the original module.
4. For native analysis, install/configure a compatible Ghidra, Hopper or IDA
   provider using [REA's official instructions](https://github.com/morluto/rea/blob/main/docs/installation.md).
   The sheet can select an existing Ghidra folder directly, without relying on
   shell environment variables inherited by Finder. Provider version/native
   decompiler/Java requirements still apply; REA reports those failures.
5. **Export and run REA** creates a separate workspace and runs the official
   published CLI, pinned to `rea-agents@6.8.0` with `node@24.22.1`. An existing npm
   bootstraps those exact packages into a game-local cache. It does not upgrade
   global Node/npm, register MCP servers or change your agent configuration.
6. Open the retained workspace to review `main.elf`, `analysis.json`, `rea.json`
   (Evidence when analysis succeeds), `rea-stderr.log` and instructions. Failed
   provider runs retain the ELF and diagnostics. Export-only needs no npm or REA.

The entry is optional and does not clutter game preparation. Provider products
have their own installation requirements and licenses. This wrapper neither
bundles nor automatically installs their engines. It requires a prepared game's
local Python environment and dependencies; npm is required only to run REA.

## Files and identity

Every run creates a new private folder under
`<game>/nxnative-tools/analysis/<unique-run>/`, never overwriting a previous run.
The manifest records Title ID, selected extraction package, original main NSO
build ID, SHA-256 and pinned tools. It refuses mixed-title folders, symlink escapes
and outputs outside the game's analysis area. Original game files, keys, saves
and nxnative profiles are not modified or sent to GitHub. Keep all exported game
code and Evidence outside the repository. Downloading tools requires network;
this adapter passes only the exported ELF to the local REA CLI.

The newest *extracted* package is chosen numerically; adding an unprepared update
file alone does not make it the analysis target. A script can export without
running an analysis provider:

```sh
python3 scripts/analyze_game.py /absolute/path/to/your-game
```

Add `--run` to perform native analysis, and `--provider ghidra`, `hopper` or `ida`
when several compatible providers are available. The UI uses REA's automatic
provider selection. No setup command is invoked on the user's behalf.

## How an agent uses the result

REA's [CLI](https://github.com/morluto/rea/blob/main/docs/cli.md) exposes an overview,
functions, pseudocode, instructions and references through a local provider.
Use the exported ELF and its exact build ID in a separately configured agent to
investigate a specific function or hypothesis. Decompiled pseudocode does not
restore the original Unity project, assets, variable names or complete source.
Any proposed change still needs a build-ID-gated patch, rebuild and testing in
nxnative before it can enter a game profile. Nothing here automatically patches,
ports or publishes an unsupported title.

The project is [morluto/rea](https://github.com/morluto/rea), published as
[`rea-agents`](https://www.npmjs.com/package/rea-agents), under its
[MIT license](https://github.com/morluto/rea/blob/main/LICENSE).
This repository integrates the external CLI; it does not vendor REA source.
