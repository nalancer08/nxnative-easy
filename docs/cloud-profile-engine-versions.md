# Cloud profile and engine versions

The launcher separates three identities: the local Mac profile, the system's
current iCloud Drive account, and the Apple account used to sign/install games.
They can differ. The avatar initials are explicitly this Mac's profile, not an
inferred iCloud name or the signing email. The account popover links to System
Settings to inspect the real account and shows the selected save folder and last
successful local scan. No account name/email/photo is scraped, collected or logged.
Apple documents the Drive [identity token](https://developer.apple.com/documentation/foundation/filemanager/ubiquityidentitytoken)
as opaque. The old CloudKit identity discovery API is
[no longer supported](https://developer.apple.com/documentation/cloudkit/ckdiscoveruseridentitiesoperation).

Setup now has checking, confirmation and failure states. A successful folder scan
confirms the selected connection before the user opens the library. It does not
claim that another device has received progress. The optional shared-folder path
uses its actual folder selection. A system identity-change notification drops
cached evidence/permission and requires explicit reconnecting, retaining all files.

The engine badge uses dotted versions independently of the launcher release.
The existing runtime `d9dc1087` is the 1.0.0 baseline and the linker fix `0031fe49`
is 1.0.1. These are Easy integration versions, not upstream release tags or a
promise about gameplay compatibility. Unknown pre-baseline code is shown as
“older than 1.0.0”; an unknown hash has no guessed version/order.

`scripts/sync_engine_history.py` walks complete first-parent integration history,
assigns internal stable indices, and maps old build source commits to their engine.
The public labels come from `desktop/engine-versioning.json`. After the baseline,
each runtime integration advances the patch; explicit overrides may advance major
or minor. Cosmetic commits do not advance the engine. The catalog carries the last
24 change notes and offline lookup for all known source builds. The desktop package
gate rejects stale runtime catalogs. The exact current frontend source is aliased
to its unchanged engine version when loading a verified package.

A higher engine is informational. Recompile advice still examines changes used by
the particular game; an unrelated profile change or new launcher alone never
requires recompilation. Existing games, outputs and saves are read without mutation.

Validation uses temporary Git histories, synthetic cloud folders and independent
preferences. It covers cosmetic/runtime/merge version ordering, source lookup,
malformed catalogs, first-scan status, failed scans and account-change preservation.
No real Apple account, game launch, signing or device installation is required.
