# Background renewal and connection checks

In Settings → General, enable **Renew even when the app is closed**. macOS may
ask for approval in Login Items. Each game must also have automatic renewal
enabled after an explicitly approved installation with a remembered session.
Neither installing this update nor starting the app registers that service.

The optional `com.nalancer08.nxnative.refresh` user agent starts the bundled
`nxnative-refresh` worker every 30 minutes, even with the main window closed.
It is not a server, an always-on Mac or a permanent signature. It requires the
Mac awake, Internet, an existing Keychain session and an already paired reachable
iPhone/iPad. USB is preferred; configured Wi-Fi remains supported. When the main
app is running, that app handles renewal and the worker exits.

The worker shares the exact installation policy and native helper with the UI.
Only opted-in jobs within 48 hours of their actual profile expiry are considered.
It verifies source IPA hash, game version, team, identity and an existing device
registration; it does not register a new device. It refuses to replace a running
game or an unknown process inventory and does not recopy RomFS. One installer
lease prevents overlapping workers and foreground helper sessions. A challenge
requiring 2FA pauses automatic attempts until the user signs in in the UI. Missing
sessions and failures preserve the saved session marker; no password is stored.
A worker attempt is bounded to four minutes and retains normal retry/backoff.

The foreground installation review and Settings continue to manage the shared
Apple account. The worker never presents a password or verification-code prompt. If an attempt needs attention, it posts a generic local notification when macOS has already granted notification permission; it does not request permission in the background.
A changed ad-hoc helper may require a fresh Keychain permission approval through
the foreground app; unattended recovery is not guaranteed by compilation.

**Check USB and Wi-Fi** reads device metadata separately over each advertised
route, without signing in or installing an app. A check mark confirms that metadata
was reachable over that route; it does not prove that signing or a large transfer
will succeed. For Wi-Fi, pair by USB first and enable wireless syncing in Finder.

After signing, the helper compares the actual signed increased-memory entitlement
with the verified provisioning profile. A mismatch stops installation. The success
screen distinguishes confirmed increased memory from a signature without it;
absence does not promise that a memory-heavy game will run. Apple grants the
capability; the app cannot invent it or bypass a team restriction.

## Validation boundary

Synthetic tests cover session recovery/2FA, logout, original identity/hash,
backoff, no new registration during renewal, save protection and the worker's
shared code. A real read-only connection check on 2026-10-28 reached a paired
device over Wi-Fi. USB was not advertised in that run. No Apple login, signing,
installation or automatic renewal was performed by the agent. Full unattended
renewal across an actual expiry and a physical USB/Wi-Fi installation still need
owner testing. Existing successful owner installations do not prove every one of
those scenarios.
