# Publication preparation

nxnative Easy is derived from [seedds/nxnative](https://github.com/seedds/nxnative).
The original engine, game profiles and compatibility work retain their authors,
MIT notice and third-party license files. Our additions are the native desktop
preparation UI, persistent iOS touch-control editor and lightweight build workflow.
No endorsement by Nintendo, Apple, game publishers or upstream authors is implied.

The desktop UI uses original phone/controller artwork and generic system symbols rather than game screenshots or logos.
The README/gallery and upstream documentation still contain game screenshots;
removing artwork from the app does not remove that documentation or historical
Git objects. The code's license is not a blanket grant of rights over third-party
artwork. Publication is a separate owner decision; this check is not legal clearance.

The current local desktop build uses Xcode's Swift compiler and explicit ad-hoc
signing (`codesign --sign - --timestamp=none`). `Signature=adhoc` and an unset
`TeamIdentifier` confirm no Apple development identity is selected. No Apple
account, organization certificate, provisioning profile or company team is used.
The generated iPhone IPA remains unsigned; Sideloadly signing is performed later
by the user with their own personal account.

Users must select their own external folder containing prod.keys. The application
stores only that local folder path in UserDefaults, not key values. The maintained
CLI does not discover keys beside a game without an explicit selection. Keys,
game packages, saves, IPAs and build outputs are excluded from this repository.
Synthetic test fixtures are created in temporary directories and contain dummy
bytes, never usable console keys.

Pre-publication audit on 2026-10-26 inspected 10,172 objects reachable from main,
including 5,877 historical blobs (5,699 treated as text). Checks covered sensitive
filenames, private PEM headers, recognizable GitHub tokens, console-key assignment
patterns, company references and the owner's known local home/email identifiers.
No matches were found. This targeted scan is not proof that no possible secret
exists. It does not audit unreachable server objects or independently establish
third-party copyright permissions.

Validation: native desktop compilation, explicit ad-hoc signature inspection,
12 script/worker tests and 4 documentation/link checks passed. No Apple account
was used, no game was signed/installed, and no new device gameplay is claimed.

See GitHub's [visibility documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility):
public visibility exposes repository content and Actions history, and others can fork
it. A later return to private does not retrieve copies already made by others.

Publication refresh on 2026-10-26 rechecked all 5,945 historical blobs reachable
from main before the README screenshot refresh. No matches were found for the
checked key/token patterns, sensitive package filenames, company references or
known private local identifiers. The owner explicitly requested public visibility.
Current English/Spanish app screenshots and the profile search screenshot replace
the earlier interface captures.
