---
status: superseded
contract_ids: [NOTCH-VISIBILITY-040]
supersedes: []
superseded_by: 009-keep-notch-visible-across-full-screen-apps
owner: project-maintainer
created_at: 2026-07-26
last_verified_commit: null
---

# Suppress the Notch Panel Over Full-Screen Content

## Context

Removing `fullScreenAuxiliary` keeps the panel out of many native full-screen
Spaces, but games often use a borderless layer-zero window in the ordinary
Space. The generic application-switch recovery guard then orders CodexNotch
above that game and covers part of its top controls.

## Decision

- Explicitly add `fullScreenNone` to the notch panel's collection behavior.
- Inspect only the current session's on-screen window ownership, layer, and
  bounds. Never capture pixels, window titles, or application content.
- Suppress CodexNotch when a layer-zero window owned by the frontmost process
  covers at least 98 percent of the notch display and reaches every display
  edge within 2pt.
- Recheck immediately on application activation and active-Space changes, and
  at most once per second to detect borderless mode changes that do not switch
  Spaces.
- While suppressed, order out the complete panel, including the transparent
  hidden-state hover sensor, without clearing the requested notch mode. Render
  that requested mode again when the full-screen window disappears.

## Rejected Alternatives

- **Remove `canJoinAllSpaces`**: Breaks the confirmed behavior that keeps the
  notch visible across ordinary desktop application and Space changes.
- **Rely only on native full-screen notifications**: Does not detect borderless
  games that remain in the ordinary Space.
- **Maintain a game bundle-identifier list**: Is incomplete, requires ongoing
  maintenance, and does not generalize to presentations or video players.
- **Use Accessibility or screen capture**: Introduces unnecessary permissions
  and privacy exposure for a decision that only needs ownership and geometry.

## Consequences and Verification

The panel may take up to one second to disappear when an already-frontmost
application switches into borderless mode; application and Space changes are
checked immediately. A normal maximized window that leaves the menu-bar edge
uncovered does not trigger suppression. Unit tests protect the geometry and
restore policy; real hardware must confirm native and borderless full-screen
entry, absence of the hover sensor, and automatic restoration on exit.
