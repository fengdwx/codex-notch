---
status: superseded
contract_ids: [NOTCH-MOTION-002]
supersedes: []
superseded_by: 005-static-card-transitions-and-completion-cue
owner: project-maintainer
created_at: 2026-07-17
last_verified_commit: 0d37196
---

# Fixed Canvas with an Expanding Inner Island

## Context

Early versions continuously adjusted the `NSPanel` frame with timers and AppKit animations. This caused re-entrant layout crashes during SwiftUI text layout, and visually made the window burst out of the physical notch instead of matching Atoll's layered experience.

## Decision

Before expansion, `NotchWindowController.prepare` allocates the final transparent canvas once. `NotchView` and `NotchPresentationMotion` then animate the visible island inside that canvas. After collapse, `settleFrame` reclaims the extra transparent canvas after a delay so it cannot intercept mouse events outside the compact notch.

When the user disables animations, the same fixed-canvas boundary remains in place, but SwiftUI state changes and the final frame settlement happen immediately instead of waiting for an animation interval.

## Rejected Alternatives

- **Set the panel frame every frame**: Competes with SwiftUI layout and previously caused crashes and flicker.
- **Scale the entire window with AppKit only**: Avoids the crash, but still makes the window move instead of letting the island expand naturally downward.

## Consequences and Verification

- Future animation changes must not restore a timer-driven `NSPanel.setFrame` loop.
- Run `NotchGeometryTests` automatically; hover expansion, collapse, and mouse hit regions still require validation on real notch hardware.
