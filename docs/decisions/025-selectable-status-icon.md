---
status: active
contract_ids: [QUOTA-SEMANTICS-054, SETTINGS-PREFERENCES-017, PRIVACY-APP-BUNDLE-040]
supersedes: [023-embed-codex-mark-for-status-fallback]
superseded_by: null
owner: project-maintainer
created_at: 2026-09-06
last_verified_commit: null
---

# Choose the status icon in Settings

## Context

The user requested a setting to switch between the ChatGPT knot and Codex
terminal flower. The current Codex default, accepted motion, and five-hour
quota priority must remain intact.

## Decision

- Store `statusIconStyle` as a local cosmetic preference with `codex` and
  `chatgpt` values. Missing or unrecognized values keep Codex.
- Use the existing native settings form, with localized labels and both
  artwork choices. `@AppStorage` updates the actual notch immediately and
  preserves the selection across launches.
- Render both icons from embedded 36px template images at the existing 18pt
  size. Codex uses a dark flower with a white prompt, with rendering defined
  by [decision 027](027-restore-dark-codex-flower.md). The selection
  applies to idle, running, and completed states and to
  the floating bar; it does not change the application Dock icon.
- Share the foreground and echo renderer. Change only the Core Animation
  mask when the preference changes, keeping an existing pulse running and
  preserving static cues when motion is disabled.
- Keep returned five-hour quota ahead of status artwork in the physical
  notch's left lane. The settings explanation makes this priority visible.
- Never locate or read another application's bundle to obtain artwork.

## Rejected alternatives

- **Separate renderers for each product:** Duplicates motion and completion
  behavior and makes it easier for the two choices to diverge.
- **Apply only after restart:** Prevents the real notch from serving as the
  immediate preview already used by other appearance settings.
- **Fetch the installed app's icon:** Reintroduces the App Management
  dependency without improving the user's choice.

## Verification

`StatusIconStyleTests` checks both stored values, default/unknown values,
unchanged runtime data preferences, equal template geometry, distinct artwork,
and live echo-mask switching with preserved animation and detachment cleanup.
Existing motion, quota, lane-selection, and embedded-asset guards remain.
The old prohibition on ChatGPT artwork is explicitly superseded by
QUOTA-SEMANTICS-050; the external-bundle prohibition is retained for both marks.

Run `./scripts/verify.sh`, open the built app's Settings, switch both choices,
and restart with ChatGPT selected to check persistence. Physical-notch
confirmation is still required for both silhouettes' readability, camera
clearance, and motion across running, completed, and reduced-motion states.
