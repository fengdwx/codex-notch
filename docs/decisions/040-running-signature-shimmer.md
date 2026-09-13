---
status: superseded
contract_ids: [FLOATING-CENTER-053, SETTINGS-PREFERENCES-018, FLOATING-ICON-052]
supersedes: [034-floating-center-styles]
superseded_by: 041-continuous-signature-shimmer
owner: project-maintainer
created_at: 2026-09-13
---

# Restore the running signature's soft text shimmer

The early custom-text preview used a four-second highlight clipped to the
glyphs. The later native implementation in 31dba9f selected static signature
text and only animated orbit and flow. The user noticed the missing shimmer;
this is not caused by the app restart or a disabled animation preference.

This L2 change supersedes only decision 034's static personal-signature choice.
Retain all four center choices, local persistence, twelve-character handling,
the actual task timer, fixed geometry and the visible-only motion lifecycle.
Keep the current SwiftUI text as the layout and glyph mask so its 11pt regular
monospaced font, tracking, truncation and centering do not change. Move a soft
neutral highlight behind that mask over a dim but visible text base. Reuse
the existing Core Animation renderer and preferred 8 FPS without SwiftUI
per-frame updates. Keep the status dot steady and preserve static 70 percent
white text when motion stops. Ordinary updates must not restart the cycle.

Preserve completion, idle, expansion, hiding, detachment, app motion off and
Reduce Motion gates. Orbit's label and elapsed digits remain static. Quota,
icons, expanded typography, open/close motion, task data and releases are out
of scope. Rejected: whole-label blinking, scaling glyphs, always-on decoration,
another setting or timer, and replacing native text with raster artwork.

Acceptance: reproduce the missing highlight in a hosted production-view test,
verify state gates and stable text geometry, record a full native cycle and
static completion, run full verification, then install with LaunchServices.
The user's mirrored-display appearance and physical-notch interaction still
require real-hardware confirmation; screenshots alone do not prove motion.

The live-layer fixture is opt-in via `NOTCH_SIGNATURE_FRAMES`; the native
recording uses `NOTCH_MOTION_CAPTURE_SCENARIO=signature`. Both require an
unlocked interactive desktop. A skipped fixture is not visual acceptance.
On 2026-09-13 the first live attempts could not run: the OS reported
`CGSSessionScreenIsLocked=1` despite authorized screen capture, and the panel
was occluded. Keep those attempts classified as unverified until an unlocked
run succeeds; do not force animation through the visibility gate.

The missing-highlight and motion-policy guards first failed on the original
implementation and passed after the repair. Full verification then passed:
206 tests passed, with the two interactive fixtures explicitly skipped,
followed by release build, bundle/resource and signature validation. The
installed bundle matched the verified executable and was launched through
macOS LaunchServices with launchd as its parent. Real display motion remains
unverified while locked; no capture was produced or represented as successful.
