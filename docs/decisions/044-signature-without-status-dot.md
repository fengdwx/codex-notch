---
status: active
contract_ids: [FLOATING-CENTER-057, SETTINGS-PREFERENCES-018]
supersedes: [043-faster-signature-light]
superseded_by: null
owner: project-maintainer
created_at: 2026-09-13
---

# Center the personal signature without its extra status dot

The user requested removing the dot before the personal signature. This L2
change renders the existing signature label directly, centering it in the
same reserved area. Preserve FLOATING-CENTER-056's five-second seamless light,
typography, brightness, all-state motion and stop gates, with only the dot
removed and the text recentered. Settings and primary task-state cues remain.
Other styles, card transitions, data, refactoring and releases are out of scope.

Rejected: making the dot transparent while reserving its width, which would
leave the text offset, or changing the elapsed style's fallback incidentally.
Acceptance reuses the existing hosted geometry and live animation checks,
runs full verification, and inspects live state frames and the installed bar.
Physical-notch appearance requires real hardware confirmation.

Validation on 2026-09-13: full verification passed with 207 tests passing and
one opt-in recording fixture skipped, followed by bundle and signing checks.
The enabled live signature fixture sampled 58 phases across running, completed
and idle; its rendered frames showed centered text with no dot. The installed
executable matched the verified build, ran under launchd and displayed an
opaque 212x30 top-center window. An eight-second recording on the mirrored
display showed the user's signature centered without a dot and continuous
light across the five-second repeat. Physical-notch appearance was not rechecked.
