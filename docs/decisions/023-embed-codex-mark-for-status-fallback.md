---
status: superseded
contract_ids: [QUOTA-SEMANTICS-049, PRIVACY-APP-BUNDLE-040]
supersedes: []
superseded_by: 025-selectable-status-icon
owner: project-maintainer
created_at: 2026-09-04
last_verified_commit: null
---

# Embed the Codex mark for compact status fallback

## Context

The no-five-hour fallback restored a white ChatGPT knot, but the surface tracks
Codex tasks and the user requested the recognizable Codex terminal-flower mark.
The mark must also preserve the existing rule that decorative UI never reads
another installed application's bundle at runtime.

## Decision

- Embed a display-sized 36px alpha mask of the Codex terminal-flower mark in
  the executable and render it as white at the existing 18pt app-mark size.
- Keep the `>_` glyph as a dark cutout so the mark stays recognizable on the
  black notch instead of collapsing into one solid white flower.
- Use the same mark for idle, running, and completed app-status states. Running
  keeps a restrained same-mark echo; completion keeps its green acknowledgement.
- Use `terminal.fill` only as the defensive SF Symbols fallback when the
  embedded image cannot decode.
- Do not locate or read ChatGPT.app, Codex.app, or any external app bundle at
  runtime.

## Rejected alternatives

- **Read the currently installed icon:** It revives the App Management privacy
  problem and depends on another application's private resource paths.
- **Keep the white ChatGPT knot:** It does not represent the requested Codex
  identity.
- **Use only an SF Symbol:** It is less recognizable and should remain a decode
  fallback rather than the primary mark.

## Consequences and verification

- The small embedded PNG adds no runtime file access and keeps the lane size
  unchanged.
- Automated tests verify dimensions, color rendering mode, pixel backing, and
  the absence of external bundle lookup.
- A real-notch preview must still determine whether the white mark remains
  recognizable and balanced beside the weekly indicator at 18pt.
