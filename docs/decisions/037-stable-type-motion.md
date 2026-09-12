---
status: active
contract_ids: [NOTCH-MOTION-006, SETTINGS-PREFERENCES-018, NOTCH-LAYOUT-038]
supersedes: [036-measured-collapse-motion]
superseded_by: null
owner: project-maintainer
created_at: 2026-09-13
---

# Keep type stable while the island lands and rebounds

The user requested a small rebound at the end of opening, stable text while the
shell expands, and a more coordinated collapse. This L2 change adjusts the
opening spring and content transitions. Preserve the measured closing curve,
settled geometry, camera/icon clearance, completion-driven canvas settlement,
reentry and motion gates from decision 036. Fonts, font weights, task/usage data,
settings and releases are out of scope.

Use a 0.48s response, 0.68 damping-fraction opening spring. The shell passes its
destination slightly, returns through it, then settles. Smoothly bound the
visible overshoot with a tanh curve: at most 6pt additional total width and 8pt
height. This fits the existing transparent canvas at all card heights without
a hard stop at the window edge. The upper bound uses the larger start/end size
and is retained during clock updates, so collapsing expanded content does not
jump straight to its smaller target. The compact camera-safe floor and bounded
floating compression remain unchanged.

The previous insertion scaled the entire detail layer from 0.8 to 1. That made
text visibly grow while the shell was already changing size. Keep the detail
layer at its final layout and scale in both directions. Use built-in offset,
blur and opacity effects within a regular view modifier:

- Opening: start 4pt above the final position, blur 1.5pt, opacity zero; reveal
  over 0.24s with a 0.035s delay.
- Closing: move 6pt upward, blur 3pt and fade out over 0.18s, clearing the details
  before the shell's compact return instead of dragging legible rows through it.
- Compact return: begin at 65% opacity with only 1pt blur, no offset or delay;
  become crisp over 0.16s. Status remains recognizable during collapse. Removal
  of this header on opening stays immediate.

The exterior supplies the spring movement; content has no scale transform or
independent spring. The short-lived light blur preserves a soft transition.
All effects settle completely and are bypassed by the existing disabled-motion
and Reduce Motion paths.

Use the existing `NotchMotionCaptureTests` production-view fixture to compare
opening, closing and rapid reentry before/after. Inspect the frame sequence for
stable text size, a small uncut landing rebound and early compact-header clarity.
Existing tests continue to guard surface travel, icon/camera bounds, hosting,
completion, stale callbacks and motion preferences. Additional outcome guards
check that short/tall opening frames fit the canvas and that reducing content
height retains the whole starting frame through clock updates. Run full verification and rebuild/restart
the installed application. Physical-notch clearance and subjective acceptance
remain real-hardware confirmation items.
