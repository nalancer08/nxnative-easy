# Local isideload integration patch

Source: https://github.com/nab138/isideload
Published crate: isideload 0.5.0, MIT, Copyright (c) 2025 nab138.
Crate source revision: fc7a81a6de678aa707e05399ffafb8be0ad56921.
Original crate SHA-256: 649ccce64715f7b8f1e9eb330defc48d06d5d35eb8d13d17783533b02c67ba32.

Only functional change: `sideload/sideloader.rs` preserves the exact bundle
identifier supplied by our helper instead of unconditionally appending the team
ID. The helper chooses a unique ID on first installation and validates an
existing device app, selected team, signed identity and provisioning identity
before updating. This permits keeping identifiers originally used by Sideloadly.
No Apple authentication protocol, TLS behavior or certificate revocation policy
was changed. The helper explicitly refuses automatic certificate revocation.

When updating this dependency, compare this patch with the new upstream source,
retain identity checks and rerun the helper/device tests. The parent Cargo.lock
pins all remaining dependencies. Source is retained here with the MIT license.
