---
status: active
contract_ids: [NOTCH-VISIBILITY-042]
supersedes:
  - 006-hidden-notch-hover-recovery
  - 007-suppress-notch-over-full-screen-content
superseded_by: null
owner: project-maintainer
created_at: 2026-07-27
last_verified_commit: null
---

# Keep the Requested Notch Visible Across Full-Screen Applications

## Context

CodexNotch previously opted out of native full-screen Spaces and also polled
frontmost window geometry to suppress the panel over borderless full-screen
content. That policy made the notch disappear in full-screen work applications
such as Feishu and Edge, even though the user still expected quota and task
status to remain available there.

The existing display switch already expresses the user's visibility intent.
Automatic menu-bar fallback remains a separate geometry decision and must not
create a panel on screens without a valid notch.

## Decision

- Configure `NotchPanel` with `canJoinAllSpaces`, `stationary`, and
  `fullScreenAuxiliary`; do not combine it with `fullScreenNone`.
- Do not inspect frontmost window geometry or automatically order out the panel
  because an application covers the display.
- Keep the generic next-main-loop panel reassertion after every application
  switch so AppKit deactivation cannot withdraw the requested panel.
- When the display switch is off, keep only the transparent physical-notch
  hover sensor, including in full-screen Spaces, so the same card can restore
  the visible surface.
- Keep automatic menu-bar fallback panel-free.

## Rejected Alternatives

- **Remove only the geometry detector**: Native full-screen Spaces would still
  exclude a panel that declares `fullScreenNone`.
- **Change only the Space flag**: Borderless full-screen windows would still
  trigger the runtime suppression path and order the panel out.
- **Allow-list Feishu and Edge**: The visibility requirement applies to all
  full-screen applications and should not depend on bundle identifiers.
- **Raise the window above system-level windows**: The existing `popUpMenu`
  level is sufficient and changing it would affect unrelated window behavior.

## Consequences and Verification

The notch intentionally remains visible over full-screen video, presentations,
and games when the display switch is enabled. Focused tests protect the Space
flags and restoration policy; the runtime no longer polls Core Graphics window
metadata. Real hardware must confirm native full screen in Feishu and Edge,
downward-only hover expansion, collapsed-canvas mouse pass-through, hidden
sensor recovery, and panel-free automatic menu-bar fallback.
