---
status: active
contract_ids: [QUOTA-SEMANTICS-055]
supersedes: [020-running-notch-breathing-light]
superseded_by: null
owner: project-maintainer
created_at: 2026-08-31
last_verified_commit: null
---

# Put the running cue behind the visible quota indicators

## Context

The centered breathing light was only visible in a software screenshot. On a
real MacBook, that location is the physical camera cutout, so it cannot be a
reliable or useful status signal. The two compact quota circles are already
known displayable locations on the left and right sides of the cutout.

## Decision

- Remove the centered running light entirely.
- Put a restrained blue breathing halo behind every returned physical-notch
  compact quota indicator: five-hour on the left and weekly on the right.
- Keep the halo at a 24pt visible diameter, so it remains inside the 22pt
  indicator's two-point camera-side clearance and its 46pt lane.
- Animate only opacity and scale on a `CAShapeLayer` at the shared preferred
  8 FPS cadence. It is stopped through the existing visible-surface lifecycle
  when the view detaches, hides, expands away, or motion is disabled.
- Do not add a central cue, spatial travel, a timer, a SwiftUI `TimelineView`,
  a full bright outline, or any panel/frame change. The floating-bar fallback
  keeps its independent status presentation without this halo.

## Rejected alternatives

- **Keep the centered light:** It renders beneath real camera hardware and
  therefore provides no physical-screen value.
- **Return to an outer-edge marquee:** The user already found its low-cadence
  movement visually rough.
- **Use a halo wider than the side clearance:** It risks being covered by the
  camera cutout or reading as a bright outline.
- **Use a new central software island:** It would change the established
  compact geometry and still compete with the hardware notch.

## Consequences and verification

- The running state uses only real displayable pixels while preserving the
  compact layout and quota semantics.
- The visual signal is intentionally secondary to the readable percentages;
  it should remain a soft background cue, not a second status badge.
- Automated tests cover activity, quota-presence, layout, motion-preference,
  side-clearance, and cadence gates. Full verification checks the bundle.
  Real-notch inspection must still confirm that both halos are visible,
  unobtrusive, stop correctly, and do not touch the physical cutout.
