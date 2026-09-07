---
status: superseded
contract_ids: [QUOTA-SEMANTICS-054]
supersedes: []
superseded_by: 030-floating-five-hour-quota
owner: project-maintainer
created_at: 2026-09-04
last_verified_commit: null
---

# Restore the left status icon when five-hour quota is unavailable

## Context

The physical-notch left lane was changed to show a returned five-hour quota
instead of the Codex status mark. That implementation also left the lane empty
when the API did not return a five-hour window, which made accounts such as Pro
appear to have lost their original activity indicator.

## Decision

- Select exactly one content type for the compact left lane.
- On a physical notch, show the five-hour quota when that window is returned.
- Otherwise, show the selected embedded white ready, running, or completed
  status icon, defaulting to Codex.
- Keep weekly quota on the right, the no-notch status lane unchanged, and do
  not invent a five-hour value when the API omits it.
- A quota halo may appear only behind a real quota indicator; the restored app
  icon keeps its existing activity and completion treatments.

## Rejected alternatives

- **Keep the lane empty:** It removes the original status feedback and looks
  like a rendering failure on plans without a five-hour window.
- **Always show both the mark and five-hour quota:** The compact wing has one
  established indicator lane and must not widen or overlap the camera cutout.
- **Move weekly to the left:** It would change the confirmed two-window layout
  and make the compact arrangement depend on plan type.

## Consequences and verification

- Left-lane selection is represented by one policy result, preventing quota
  and status content from being requested at the same time.
- Automated tests cover physical-notch presence and absence of five-hour data,
  plus the no-notch fallback.
- Real-notch inspection must still confirm that the restored icon is centered
  and readable in ready, running, and completed states.
