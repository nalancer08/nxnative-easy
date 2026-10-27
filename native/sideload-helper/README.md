# nxnative-sideload

Native ARM64 helper for nxnative Easy's experimental integrated iPhone/iPad
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
RomFS access is restricted to `/Documents/romfs` and reserved transfer journals;
it does not read or write save roots. Physical-device and real-account validation
is still required before treating this as a tested Sideloadly replacement.
