---
status: superseded
contract_ids: [NOTCH-VISIBILITY-044]
supersedes: []
superseded_by: 014-top-attached-no-notch-activity-island
owner: project-maintainer
created_at: 2026-08-10
---

# Show a Floating Status Bar on Displays Without a Notch

## Context

`NSScreen.auxiliaryTopLeftArea` and `auxiliaryTopRightArea` are available for a
physical camera cutout, but they are absent on Mac mini monitors, older Macs,
and ordinary external displays. The previous branch treated that absence as a
menu-bar-only fallback, so the primary quota and task surface was not visible
at all.

## Decision

- Add a separate `floatingBar` layout mode for displays without valid auxiliary
  notch areas.
- Center the compact bar on `visibleFrame.midX` and anchor its top edge below
  the menu bar (or eight points below the visible top when no menu bar inset is
  reported).
- Reuse the existing fixed transparent canvas and downward-only expanded card;
  use a fully rounded surface so the bar does not imply a physical camera
  opening.
- Keep the panel non-activating and in all Spaces, just like the requested
  physical-notch surface.
- Do not create an invisible hover sensor in the no-notch mode. If the user
  disables the display, order out the panel and retain the menu-bar recovery
  action.
- Keep the valid physical-notch path, camera-safe padding, and hidden-notch
  hover recovery unchanged.

## Rejected Alternatives

- **Keep the menu-bar-only fallback**: It is technically safe but makes the
  product's main quota and task surface disappear on the exact machines that
  need a fallback.
- **Pretend the whole top center is a physical notch**: This produces the wrong
  geometry and a visually misleading camera attachment on ordinary displays.
- **Create a second window implementation**: It would duplicate the fixed-canvas
  expansion, click routing, and state rendering already used by the notch.

## Consequences and Verification

The same state and data surface now works on Mac mini and external displays,
with a small geometry-specific shape difference. Automated geometry and
visibility-policy tests protect the mode boundary. Real hardware confirmation
is still required for menu-bar spacing, panel placement across Spaces, hover
expansion, and display-off recovery on a no-notch display.
