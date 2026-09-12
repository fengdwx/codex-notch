---
status: superseded
contract_ids: [NOTCH-VISIBILITY-047]
supersedes: []
superseded_by: 032-mirrored-display-floating-island
owner: project-maintainer
created_at: 2026-08-21
---

# Keep Mirrored Desktop Content Clear of the No-Notch Island

## Context

`NSScreen` reports the active mirror master's coordinate space while hardware
display mirroring is enabled. On a built-in Mac display mirrored to a
non-notch television or monitor, that coordinate space can have no auxiliary
camera areas even though the physical built-in display has a camera housing.
Treating it as an ordinary no-notch display places the 212pt activity island
above normal mirrored application content.

## Decision

- Use `CGDisplayIsInMirrorSet` for the selected `NSScreen` display ID at each
  render; do not infer mirroring from screen dimensions, model, or resolution.
- When the live layout would be `floatingBar` and that display is in a hardware
  mirror set, hide the panel and expose the current Codex state through the
  existing menu-bar fallback.
- Keep the user's display preference unchanged. When mirroring ends, the next
  screen-parameter render derives the physical-notch or ordinary no-notch
  layout from fresh `NSScreen` metrics.
- Preserve the Sword Wanderer island for genuine non-mirrored no-notch
  displays, and preserve physical-notch geometry whenever valid auxiliary
  areas are reported.

## Rejected Alternatives

- **Hard-code a screen width or notch width**: scaled modes and mirror masters
  change independently of the built-in camera geometry.
- **Reuse the last notch rectangle while mirrored**: a mirror master does not
  share a stable coordinate system or aspect ratio with the built-in display,
  so retaining that rectangle can still cover unrelated content.
- **Disable the display preference permanently**: users should regain their
  chosen presentation automatically when the mirror topology changes.

## Consequences and Verification

The mirror route is panel-free but retains task and quota access in the menu
bar. The route decision is deterministic and unit-tested separately from live
screen APIs. Full verification covers the behavior contracts and bundle; a
real display-mirroring transition remains required to confirm that the panel
disappears immediately and returns with current geometry after mirroring ends.
