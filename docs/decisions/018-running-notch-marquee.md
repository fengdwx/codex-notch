---
status: superseded
contract_ids: [QUOTA-SEMANTICS-043]
supersedes: []
superseded_by: 019-low-cadence-notch-marquee
owner: project-maintainer
created_at: 2026-08-27
last_verified_commit: null
---

# Add a restrained running marquee to the physical notch

## Context

The physical-notch compact surface now uses the left lane for the returned
five-hour quota and the right lane for the weekly quota. The user also asked
for a clearer running cue, but the existing quota indicators already carry
their own motion and the notch must keep its geometry stable.

## Decision

- Add one blue comet-like light on the outside contour of the compact
  physical-notch outline while the task is running. It has a small bright
  core, a very short progressively softer tail, and a restrained halo; there
  is no continuously lit full outline.
- Run it only while a task is active, the physical-notch compact surface is
  shown, app and system motion are enabled, and the card is not expanded.
- Render the core, short tail, and halo with `CAShapeLayer`s and animate only
  their `lineDashPhase` at the preferred 8 FPS cadence with a 2.8-second
  linear loop.
- Stop and hide the layer when the surface is detached or hidden, the task
  stops, the card expands, or either motion preference disables animation.
- Keep the effect hit-test-free and do not change the prepared window canvas,
  panel frame, quota semantics, no-notch floating-bar status lane, or compact
  indicator geometry. The stroke is centered just inside the outer contour so
  its visible half reads as an outside-edge effect without being clipped by
  the fixed compact panel.

## Rejected Alternatives

- **A full-width scanning band inside the island**: More conspicuous, but it
  competes with the two quota percentages and can read as a third indicator.
- **A second animated icon or pulse**: Duplicates the status signal the user
  asked to remove from the physical-notch left lane.
- **A SwiftUI `TimelineView`**: Rebuilds the visible surface continuously and
  does not reuse the existing layer-backed lifecycle boundary.
- **Animating the NSPanel frame**: Changes window geometry and conflicts with
  the fixed-canvas expansion contract.

## Consequences and Verification

- The running state has a recognizable motion cue even when the quota values
  are unchanged.
- The light uses a tapered, short-lived tail instead of a hard isolated dash
  or a constantly blue outline; it must still be judged on a real physical
  notch. Automated tests cover the state policy, outer path offset, relative
  stroke and dash weights, and cadence, not perceived appearance.
- Run the focused tests and `./scripts/verify.sh`, then manually inspect the
  compact running state, expansion stop, completion stop, and Reduce Motion.
