---
status: active
contract_ids: [QUOTA-ALIGNMENT-056, SETTINGS-MOTION-021]
supersedes: []
owner: project-maintainer
created_at: 2026-10-02
---

# Keep the rotating glint and its circular mask in native layer coordinates

The supplied five-second recording shows silver-blue inner glint arcs changing
their apparent center during rotation, including a second arc near the outside
of the quota track. The quota value and outer track remain stationary. Existing
hosted center and density guards pass. Explicit SwiftUI frames and static
software-rendered samples also pass for the previous implementation; these
checks do not reproduce the recording's live composition artifact or establish
a particular macOS framework defect.

Keep the hosted glint at the quota's 22pt diameter, and put its circular
`CAShapeLayer` mask on the native `CAGradientLayer`. Both use zero-origin local
bounds, the same center and the hosting window's pixel density. Build the circle
from the smaller host dimension so resizing cannot make it elliptical. The
one-point stroke and quarter-point gap remain unchanged through rotation.
Only this full-circle glint moves to native clipping; the quota's trimmed
SwiftUI mask, colors, values, gradient timing, halo, wave, windows, preferences
and animation lifecycle remain unchanged.

This narrows the suspected SwiftUI/AppKit composition boundary without claiming
that passing model geometry proves the recorded live artifact is gone. Retain
decision 054's local coordinates and density handling; update its earlier
no-new-mask restriction only for the inner glint.

Rejected alternatives:

- Guessed x/y compensation moves the center at every phase and lacks evidence.
- Explicit frames alone retain the cross-framework animated mask boundary.
- Removing the glint or trimming it to remaining quota loses the running cue
  at low quota.
- A new timer, higher frame rate or window resizing changes unrelated behavior.

`QuotaRingAlignmentTests` checks circular clearance and center at twelve angles,
offset/rectangular bounds, and hosted two-times-density pixel samples. The
native clipping invariant fails before the change because no native mask
exists. Software-rendered samples are supporting geometry evidence, not proof
of live compositor behavior. Run the focused motion/alignment checks and full
verification, rebuild/restart the actual app, and inspect at least one complete
rotation plus hover expansion/collapse on the physical notch. Physical-hardware
confirmation is required for the recorded artifact and perceived smoothness.

On 2026-10-02, after the rebuilt app was restarted on the reporting user's Mac,
the user confirmed that the reported problem no longer occurred and requested a
release. This accepts the supplied recording's glint artifact on that machine;
it does not establish coverage of every display scale or external-display mode.
