# Portable desktop distribution

Download `nxnative-Easy-macOS-arm64.zip` from the repository's Releases page,
unzip it and move `nxnative Easy.app` into Applications. The launcher is already
compiled. It contains a checksum-pinned ARM64 standalone Python runtime, pinned
Python packages, XcodeGen, zstd, glslang, their relocated dynamic libraries,
.NET SDK 10, the metadata/extraction reader, the native installer, the optional
renewal worker, source code and third-party notices. It contains no game files,
console keys, Apple account or personal save data.

Xcode 27.1 and macOS 26.6+ are still required to **compile games**. Xcode is
installed by the user through Apple; the app does not obtain it with an Apple
account or silently approve its license. Homebrew is not required for a portable
release. The older one-command source setup remains an alternative.

The launcher is ad-hoc signed, not notarized with a paid Developer ID. macOS may
require explicit approval on first opening. A successful ad-hoc verification does
not establish notarization or imply that Gatekeeper will skip its normal checks.

The embedded source is copied once per source revision into
`~/Library/Application Support/nxnative Easy/PortableSources/<revision>/`.
Generated build files go there or into the user's game build folders, never into
the signed application. Older source revisions are retained for provenance and
rebuild comparisons. Bundled runtimes are read-only during ordinary use; Python
bytecode writes are disabled. The pinned prebuilt reader is reused only when its
source digest agrees with the checkout.

## Updates

Portable installations download the versioned portable release and verify its
SHA-256, archive paths, size limits, ad-hoc signature, version/build, bundle identity
and source revision against the release tag. The app is staged before the old
one is replaced; the previous app remains as a backup. User games and source
folders are not replaced. No Homebrew or frontend compilation is needed for this
route. A portable update is offered only once its ZIP and checksum assets exist.
Source-built installations prefer a published portable package on their next update as well; the staged source-build route remains available when no binary release exists.

An in-progress installer/worker owns a shared per-user lease. Final replacement
refuses while another installation holds that lease. Updating the desktop app does
not recompile or reinstall existing games automatically.

## Release builders

Install the release build prerequisites, then run:

```sh
python3 scripts/build_desktop_app.py --portable --output '/external/path/nxnative Easy.app'
codesign --verify --deep --strict '/external/path/nxnative Easy.app'
```

The manual `desktop-release.yml` workflow runs checks, builds the same package
and publishes a ZIP plus `SHA256SUMS`, pinned to the workflow's source commit.
`desktop/portable-requirements.txt` pins Python dependencies. Homebrew dependency
license files and SPDX notices are shipped with the tools. Python's upstream
archive checksum is pinned in `scripts/bundle_tools.py`; .NET and package license
notices accompany the distribution. Do not include personal SDK caches or keys.
