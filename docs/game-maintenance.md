# Update or renew a game

In the library, open a game's details and choose **Update or renew**. A prepared
iOS game with a recorded installation also opens this choice from its Update
action. The flow distinguishes two different needs:

- **Expired or about to expire:** reuse the recorded IPA to renew its signature.
  The guided installer reviews device, Apple account and identity before the
  explicit final button. No game recompilation or RomFS/save copy is performed.
- **Improvements or a game update:** choose Mac or iPhone/iPad, then continue
  into the existing preparation steps with your folder selected. Review your
  source files and matching update before starting compilation. Build progress
  and logs remain available. iOS preparation continues into installation.

Save and close the game first. Retain the existing app; do not uninstall it.
Mac game progress stays outside the app. For iOS, the existing game, account,
team, device and effective bundle identifier are checked. An unexpected identity
is a reason to stop, not permission to delete an app or create another container.
See [save locations and updating safely](saves.md) and [personal installation](personal-ios.md).

The renewal review pins the original registration and invokes the existing
renewal policy, including the recorded IPA digest and fresh helper checks. It
cannot register a different device, change teams or perform a content copy.
Automatic-renewal preferences are not silently changed by reviewing a manual
renewal. If there is no signing record, the flow says so and offers the regular
installer's existing-app review instead of inventing an expiry date.

Source/profile rebuild advice remains separate from signing expiry. An Easy
interface-only update does not require rebuilding a game. Engine or game-content
changes may require preparation; a renewed signature alone does not apply them.


## Why a recommendation appears

The Library now shows a reason next to the selected game and on each cover. Open
**View my game** for its installations and build history. Recorded signature
expiry, a different prepared/observed content version, and relevant source
changes are separate reasons. Rebuild changes are grouped by game profile,
graphics, saves, in-game controls/interface, engine services or packaging. Missing
history is unknown; a newer Easy interface alone is not a required game update.

**Prepared with** identifies the build-tool release. **Last signed with** records
the Easy release/build that received the successful install/renew receipt. The
current Easy release is displayed beside them. Existing installations lacking
those fields say **Not recorded**. No timestamp-based migration invents them.
Renewing an IPA updates signing provenance while retaining preparation provenance.
