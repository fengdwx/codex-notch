---
status: active
contract_ids: [QUOTA-ALIGNMENT-056, SETTINGS-MOTION-021]
supersedes: []
owner: project-maintainer
created_at: 2026-09-14
---

# Keep decorative quota layers in local coordinates

The user supplied a screenshot of the pale running ring displaced from the
weekly quota on the real Mac notch. A hosted test confirmed that the quota
gradient and inner-glint views already share their 22pt frame and center.
The halo had a separate coordinate defect: it set its layer frame to view
bounds, then built the path from those same view bounds. A nonzero origin was
therefore applied twice. A test with a (2, 2) bounds origin expected center
(14, 14) and observed (16, 16) before the fix.

Use zero-origin local layer bounds and explicitly place the layer at the
host's bounds center. Build the halo's circular path around the local center,
using the smaller host dimension so rectangular hosts cannot stretch it.
Use the same local-bounds convention for the rotating gradient layers.

This L2 fix preserves all quota semantics, dimensions, colors, layer timing,
static cues, app animation settings, visibility/detachment gates, and window
geometry. Do not compensate with a guessed SwiftUI x/y offset or move the
quota number. No new mask, animation or rendering dependency is introduced.

The geometry regression demonstrates a code defect; it does not alone prove
that the user's live rendering takes that exact offset-bounds path. Check the
rebuilt app on the actual notch at multiple phases and after hover cycles.
The user confirmed a substantial improvement after the first rebuilt app,
but reported a small residual visual offset. A temporary diagnostic build
then captured the live compact view: the halo occupied (222, 4, 24, 24),
and both gradient views occupied (223, 5, 22, 22) in the same host. All three
therefore shared center (234, 16). The window and AppKit backing layer used
2x density, while all three manually managed drawing layers still used 1x.
The diagnostic code was removed after this observation.

Set managed gradient and halo `contentsScale` from the hosting window, and
invalidate layout after window attachment or backing-property changes. This
keeps their edges at the same pixel density as SwiftUI's masks without moving
the center or changing rotation/pulse state. The 2x -> 1x -> 2x window test
failed four assertions before this correction. This resolves a verified
resolution mismatch; whether it eliminates the remaining perceived offset
still requires inspection of the rebuilt app on the actual notch.

Run the focused alignment, additive-motion and halo tests, then the full
verification and restart the app. The completion report must distinguish the
automated geometry result from physical-notch acceptance.
