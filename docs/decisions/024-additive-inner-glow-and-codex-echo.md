---
status: active
contract_ids: [QUOTA-SEMANTICS-055]
supersedes: []
superseded_by: null
owner: project-maintainer
created_at: 2026-09-05
last_verified_commit: null
---

# Add inner-ring glint and animate the existing Codex echo

## Context and acceptance

At 5% remaining, the quota-colored gradient is masked to a very short arc.
The user cannot confidently tell whether a task is still running. The first
design used separate blue activity bars; the user rejected their appearance,
selected the inner-ring glint preview, and explicitly asked to retain the
original animation and animate the left icon too.

Smallest real-hardware reproduction: select the ring style, observe a running
task with roughly 5% quota, and compare running versus stopped without hovering.
The old short arc is the reproduction; perceptual clarity requires physical
notch confirmation and cannot be certified by automated samples.

## Decision

- Keep the quota-colored gradient, its 3-second rotation, the existing outer
  breathing halo, wave motion, and green completion treatment unchanged.
- Reuse `QuotaGradientLayerView` with a silver-blue, mostly transparent conic
  palette for a separate 3.5-second glint. A full-circle 1pt SwiftUI mask sits
  inside the quota stroke with 0.25pt separation. It receives no remaining
  percentage, so low quota cannot reduce the running cue's size.
- Keep the selected 18pt foreground still. Mask one themed layer with the
  matching embedded silhouette and animate its opacity from 0.22 to 0.62
  and scale from 1.02 to 1.17 over 2.6 seconds. The largest visible echo is
  21.06pt, inside the existing 22pt container. The unchanged static echo is
  used when motion is disabled or Reduce Motion is enabled.
  The icon choice follows [decision 025](025-selectable-status-icon.md), with
  Codex as the default; changing artwork preserves the animation's phase.
  Echo colors follow [decision 028](028-share-weekly-quota-theme.md), and the
  Codex foreground follows [decision 030](030-white-codex-flower-outline.md).
- Both additions use `QuotaAnimatedLayerView` for visibility/detachment cleanup
  and the shared preferred 8 FPS Core Animation cadence. The existing static
  quota mask and white foreground never move. No timer, SwiftUI timeline,
  window geometry, external image lookup, or session-state change is needed.
- The existing left-lane policy still selects five-hour quota when available;
  it does not show an app mark and quota simultaneously.

## Rejected alternatives

- **Separate activity bars:** Clear, but the user found them unattractive.
- **Replace the original quota flow:** Conflicts with the explicit request to
  keep the original animation.
- **Clip the new glint to the remaining arc:** Recreates the 5% visibility issue.
- **Rotate or bounce the white Codex mark:** Changes the established silhouette
  orientation and makes the tiny terminal cutout harder to read.
- **Increase the global frame rate:** Changes the existing performance budget;
  first inspect this local design using the retained cadence.

## Verification

`AdditiveRunningMotionTests` covers the retained 5% quota trim/gradient, the
independent inner-glow geometry and state gates, the echo's maximum size,
embedded silhouette, shared cadence, and animation cleanup on detachment.
Existing quota, halo, left-lane, geometry, and completion guards remain intact.
Run `./scripts/verify.sh`, restart the built app, and inspect a real running
task. User confirmation is still needed for perceived smoothness and visibility
on the physical notch, especially at low quota and with both quota windows.
