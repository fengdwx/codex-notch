---
status: superseded
contract_ids: [QUOTA-SEMANTICS-045]
supersedes: [019-low-cadence-notch-marquee]
superseded_by: 021-visible-quota-halo-running-cue
owner: project-maintainer
created_at: 2026-08-31
last_verified_commit: null
---

# Use a centered breathing light for the running physical-notch state

## Context

The outer-edge marquee remained visibly rough at the shared eight-frame-per-
second cadence. The user explicitly rejected increasing that frame rate and
clarified that the replacement does not need to be a marquee.

## Decision

- Replace spatial marquee travel with one small blue light centered in the
  black compact physical-notch surface.
- Animate only the light's opacity, scale, and soft halo with a slow,
  ease-in-ease-out breathing cycle. Keep the source and all persistent quota
  motion at the existing 8 FPS preference.
- Keep the five-hour and weekly lanes, fixed window canvas, outer surface
  geometry, and visibility, running-state, expansion, and Reduce Motion gates.
- Keep the cue hit-test-free and layer-backed; do not add a timer, a SwiftUI
  `TimelineView`, a full bright outline, or any panel geometry change.

## Rejected alternatives

- **Raise the marquee to 24 or 30 FPS:** The user rejected a larger frame-rate
  budget.
- **Keep tuning a moving edge streak:** Spatial displacement remains visible
  as a jump at low cadence, even when a tail or temporal copy is added.
- **Use `CAEmitterLayer` particles:** The random particle look is too noisy and
  less deterministic for this narrow status surface.
- **Use a rotating spinner:** Rotation would create the same low-cadence
  stepping and would compete with the quota indicators.

## Consequences and verification

- The running state remains visibly alive through a low-amplitude scalar pulse
  rather than a moving object, so each 8 FPS update changes presence gradually.
- The implementation remains deterministic, bounded to the existing compact
  surface, and compatible with the shared Core Animation lifecycle.
- Automated tests cover the state gates, small light geometry, breathing range,
  slow cycle, and unchanged eight-frame cadence. The centered position,
  readability, expansion stop, completion stop, and Reduce Motion state still
  require real-notch inspection.
