---
status: active
contract_ids: [NOTCH-VISIBILITY-049]
supersedes: []
superseded_by: null
owner: project-maintainer
created_at: 2026-09-07
last_verified_commit: null
---

# Restore a hidden floating card through its original hover area

The disabled floating route previously removed the panel and set its hidden
frame to zero. Retain a transparent compact-sized sensor, using the same hover
state machine as physical-notch recovery. Hover opens the existing card without
changing the saved visibility preference; leaving hides it again. Enabling the
switch restores normal compact display. Keep hardware-mirror routing ahead of
sensor rendering, and keep menu-bar-only routes panel-free.

This replaces the menu-bar-only recovery clause inherited from decision 016 and
NOTCH-VISIBILITY-047 through NOTCH-VISIBILITY-048. Do not create a full-width
screen-edge sensor or retain the expanded canvas: both intercept unrelated
mouse input. Keep all geometry, quota and battle behavior unchanged.

Policy and geometry guards failed before this repair. Full verification and a
real close/leave/hover/reenable cycle validate recovery. Physical-notch hardware
must still confirm its existing camera-safe hover behavior.
