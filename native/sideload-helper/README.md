# nxnative-sideload

Native ARM64 helper for nxnative Easy's integrated iPhone/iPad
sign/install/refresh flow. See [architecture, security boundary and validation](../../docs/sideloading.md).

It uses isideload 0.5.0 (MIT), with the included exact-identifier patch, and
idevice 0.1.68 (MIT). Signing dependencies are pinned in Cargo.lock and their
notices/source URLs are bundled by the desktop builder. No Sideloadly code,
binary, icon or proprietary resource is included.

The newline JSON protocol is private stdin/stdout. It accepts `devices`,
`installed_apps`, `login`, `restore`, `code`, `resend`, `send_to_devices`, `sms`,
`install`, `logout` and `quit`. Authentication requests must never be logged or
passed in argv/environment variables. Protocol errors are redacted. Tests use
synthetic credentials and never sign/install on a user's device.

The helper has no uninstall operation and never automatically revokes certificates.

For the legacy macOS 10.12.6 anisette client family reported in
[Easy #19](https://github.com/nalancer08/nxnative-easy/issues/19), GrandSlam uses
the same Mac AuthKit client identity for lookup, password exchange, trusted-device
and SMS requests. Other provider identities stay unchanged. Synthetic tests cover
header consistency and both content types without making an Apple request. The
reporter's real-account success is limited to their account/Mac; this change does
not establish clean first-time 2FA, restoration, renewal or installation on every
provider. TLS validation, session persistence and credential redaction are unchanged.
RomFS access is restricted to `/Documents/romfs` and reserved transfer journals;
it does not read or write save roots. Physical-device and real-account validation
is still required before treating this as a tested Sideloadly replacement.
