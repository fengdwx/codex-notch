---
status: superseded
contract_ids: [QUOTA-SEMANTICS-044]
supersedes: [018-running-notch-marquee]
superseded_by: 020-running-notch-breathing-light
owner: project-maintainer
created_at: 2026-08-31
last_verified_commit: null
---

# Bridge low-cadence running marquee steps with temporal copies

## Context

The physical-notch compact surface keeps its shared eight-frame-per-second
Core Animation budget. The short outer-edge marquee still looked rough because
its roughly 560pt path and 2.8-second loop can move about 24pt between those
visible updates. Increasing the marquee frame rate was considered, but the user
explicitly rejected that direction.

## Decision

- Keep the source marquee, quota ring, and wave-ball animations at the existing
  preferred 8 FPS cadence.
- Put the bright marquee core in a `CAReplicatorLayer` with four instances,
  0.04-second temporal spacing, and a negative alpha offset. The core dash is
  long enough for adjacent delayed copies to overlap into one short fading
  light band instead of reading as separate dots.
- Keep the existing short tail and restrained halo, the fixed panel canvas,
  the outer-contour path, and all visibility, running-state, expansion, and
  Reduce Motion gates.
- Do not add a timer, per-frame SwiftUI redraw, full bright outline, or panel
  geometry change.

## Rejected alternatives

- **Raise the marquee to 24 or 30 FPS:** Directly reduces phase jumps, but the
  user rejected increasing the frame-rate budget and it would spend more
  persistent animation work.
- **Use `CAEmitterLayer` particles:** Gives a softer trail, but introduces a
  less deterministic particle look in the narrow 32pt notch and adds more
  lifecycle and tuning surface.
- **Use only a moving gradient mask:** Still exposes one moving hard edge at
  each low-cadence update and does not bridge the phase gap by itself.
- **Drive the path from `TimelineView`:** Rebuilds SwiftUI content continuously
  and conflicts with the layer-backed lifecycle boundary.

## Consequences and verification

- Delayed copies overlap the source positions that would otherwise be skipped,
  so the same 8 FPS source movement reads as one continuous short light band.
- The effect remains deterministic, hit-test-free, and bounded to the existing
  physical-notch panel.
- Automated tests cover the delayed-copy count, delay, fade direction, and
  unchanged eight-frame cadence. The marquee, expanded stop, completion stop,
  and Reduce Motion states still require real-notch inspection.
