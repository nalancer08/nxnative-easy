# Private save-snapshot API prototype

This is a locally tested, provider-independent server foundation. The game apps
are **not connected to cloud login, upload or restore yet**. This module never
reads the Mac/iPhone's game folders and never installs or restores files. Do not
present it as a working cloud-save feature in the player interface.

## Current save model

- iOS uses `Documents/save`; games mounting separate account and device saves
  also use `Documents/save_device` (`main.m`, `hle_fs.c`). Mac uses its per-title
  Application Support save root; a separate device save is its `_device` sibling.
- The engine writes into `.work` directories and commits via APFS clones and an
  atomic swap. Failed writes preserve the previous committed tree. Upload the
  committed snapshot, not `.work`, `.new`, temporary files or the game assets.
- Some case-sensitive guest names use `.dm-case-*` physical aliases with the
  `org.d2rmobile.guest-name` xattr. A generic ZIP export that drops those xattrs
  can change the save's logical filenames. The portable manifest carries this
  metadata explicitly for files and directories.
- Account and device save roots are independent transactions. A safe client
  snapshots/restores both **before Play**, while the game is stopped. Import must
  create a local recovery backup, validate the entire package, stage all trees,
  use a durable restore journal with rollback/recovery, and refuse Play while a
  restore is pending. Those native snapshot/import operations are still to build.
- Saves may depend on game version, region, DLC, account or game-specific IDs.
  Record the exact Title ID, main build ID and version. Do not promise universal
  interchange with another release or an emulator without a tested conversion.

## What the prototype implements

The server stores immutable versions in SQLite, scoped to the verified user's
identity plus game and named save slot. Writes need an exact prior revision
(`If-Match`) or a new-slot condition (`If-None-Match: *`). Concurrent writes from
an iPad and iPhone cannot silently overwrite one another: the stale writer gets
412 and must keep its local branch until the user chooses. Retries after an
unknown upload outcome first read the cloud head and compare, rather than force
upload. History is retained; quota errors do not delete old versions.

Sharing pins one immutable revision. A signed-in recipient uses an expiring,
revocable token to copy that revision into their own slot. It does not grant write
access to the sender's slot; revoking a link does not erase copies already taken.
The prototype provides private endpoints, not a public gallery of save files.

Identity is delegated to a configured provider. The server checks asymmetric
RS256/ES256 JWT signatures, issuer, audience, expiry and required claims through
PyJWT/JWKS. It keeps no passwords, email addresses or signing private keys.
Issuer and JWKS must use HTTPS on the same trusted host. There is no bypass login
or hard-coded development token in the executable. Tests inject identities only
into test instances and generate their signing keys in memory.

For a simple native login, email OTP through a managed provider is a practical
first option; Supabase is one compatible example when its asymmetric signing keys
and correct session issuer/audience are configured. Its [passwordless auth docs](https://supabase.com/docs/guides/auth/auth-email-passwordless)
cover the code flow. Native login, secure token storage/refresh and logout remain
client work. Sign in with Apple/CloudKit would also need the corresponding Apple
capabilities and provisioning; do not assume they work under arbitrary sideloaded
bundle IDs ([Apple's CloudKit sample requirements](https://github.com/apple/sample-cloudkit-sharing)).
No provider account or external service was created by this implementation.

## Run locally after configuring identity

Use Python 3.10+ on the server. Keep its environment, database and backups outside
the source checkout. The server runs independently of Xcode and the game builder.

```sh
python3 -m venv /your/private/tools/save-api-venv
/your/private/tools/save-api-venv/bin/pip install -r dm/cloud/requirements.txt
export OIDC_ISSUER="https://your-identity-provider/issuer"
export OIDC_AUDIENCE="your-save-api-audience"
export OIDC_JWKS_URL="https://your-identity-provider/issuer/jwks"
/your/private/tools/save-api-venv/bin/python scripts/run_save_api.py --data /your/private/save-api-data
```

It binds to `127.0.0.1:8787`. `/health` is unauthenticated; every `/v1` route needs
`Authorization: Bearer <provider session token>`. The sample domains above are
placeholders, not real credentials. Use a real configured provider before running.
No real saves or tokens are included in this repo.

The local WSGI runner is for development, not a public deployment. Before exposing
it, choose hosting, a production WSGI server/TLS proxy, request rate/time/size
limits, disk quotas, encrypted storage, scheduled database backups and tested
recovery. The snapshots are not end-to-end encrypted; the server administrator
can read them. Leave native cloud buttons disabled until the identity and restore
flows are actually configured and device-tested.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Local availability |
| GET | `/v1/me` | Opaque authenticated account ID |
| GET | `/v1/games/{title}/saves` | Current named save slots |
| GET | `/v1/games/{title}/saves/{slot}/revisions` | Latest 100 retained revisions |
| GET | `/v1/games/{title}/saves/{slot}/snapshot?revision=...` | Private current or historical package |
| PUT | `/v1/games/{title}/saves/{slot}/snapshot` | Conditional upload; ETag is the resulting revision |
| POST | `/v1/shares` | Share `{title_id, slot, revision, expires_in_seconds}` |
| POST | `/v1/shares/{token}/copy` | Copy to the recipient's `{title_id, slot}`, with a write precondition |
| DELETE | `/v1/shares/{share_id}` | Revoke your link |

Slots use 1–40 lowercase letters, digits and hyphens. Title IDs are 16 uppercase
hex digits. Snapshot payloads use `application/vnd.nxnative.save+zip`; JSON bodies
are at most 16 KiB. Share lifetime is one minute to seven days. Archive size and
expanded contents are capped at 64 MiB, 4,096 entries; retained payload quota is
512 MiB per user. Those are prototype limits, not compatibility guarantees for
larger saves. There is no automatic pruning or unconditional overwrite endpoint.

## Portable nxsave v1 package

A ZIP contains `manifest.json` plus precisely its listed account/device entries.
Paths are relative, unique, bounded and free of traversal, symlinks or special
files; case/Unicode-colliding physical paths are rejected. File bytes are checked
against sizes, ZIP CRCs and SHA-256. Every uploaded snapshot must match its API
Title ID. Game packages, console keys and IPA/signing credentials are refused.

```json
{
  "schema": 1,
  "title_id": "010093801237C000",
  "game_version": "2.1.0",
  "build_id": "64 hex digits from the exact game's main NSO build ID",
  "entries": [
    {"kind": "file", "path": "account/progress.bin", "size": 12, "sha256": "64 hex digits of the file"},
    {"kind": "directory", "path": "device/system"},
    {"kind": "file", "path": "account/.dm-case-1", "size": 5, "sha256": "64 hex digits", "guest_name": "CaseSensitiveName"}
  ]
}
```

This illustrates the format; hashes/build ID must be real values in an actual
package. `guest_name` represents only the engine's known case-alias xattr, never
arbitrary extended attributes. Control presets remain local per-game preferences;
they are separate from game progress and are not uploaded by this prototype.

## Validation

Run `python -m unittest scripts.tests.test_save_api` using the prepared server
venv. Fixtures test real loopback HTTP, user isolation, conditional/concurrent
updates, immutable sharing, revocation/expiry, archive rejection and actual RSA
JWT signature/issuer/audience/expiry checks. No account, real save or game file is
used. This does not validate a deployed service or a native iPad-to-iPhone restore.
