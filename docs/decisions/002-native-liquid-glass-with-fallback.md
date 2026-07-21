---
status: superseded
contract_ids: [EXPANDED-APPEARANCE-009, NOTCH-MOTION-002]
supersedes: []
superseded_by: 003-abandon-cross-window-liquid-glass
owner: project-maintainer
created_at: 2026-07-17
last_verified_commit: 916f72b
---

# Use Native Liquid Glass for the Expanded Surface with an Older-System Fallback

## Context

The expanded card needed a modern macOS glass appearance while the project continued to support macOS 14 as its minimum deployment target. The material change could not break the existing fixed transparent canvas or downward-only window boundary.

## Decision

- The default appearance is glass, with a live glass/black segmented choice in Settings.
- On macOS 26 and later, apply SwiftUI `glassEffect` once to the entire expanded surface, use a subtle dark tint to keep white text readable, and enable the system pointer interaction effect.
- On macOS 14 and 15, use `ultraThinMaterial` with a subtle dark overlay as the compatibility fallback; do not imitate Liquid Glass animation.
- The compact notch and black option continue to use a pure-black surface; the hidden state remains fully transparent.
- SwiftUI alone draws the material; do not change the fixed-canvas preparation, reclamation, or panel-frame strategy in `NotchWindowController`.

## Rejected Alternatives

- **Raise the minimum system version to macOS 26**: Unnecessarily drops existing macOS 14 and 15 users.
- **Hand-write multiple blur and highlight layers to imitate Liquid Glass**: Cannot follow system material behavior and adds maintenance cost.
- **Apply glass separately to every quota, reset, and conversation row**: Muddy the information hierarchy and increase compositing cost.
- **Use window opacity or frame animation to express material changes**: Breaks the fixed canvas boundary and reintroduces jumping risk.

## Consequences and Verification

- Automated tests lock the default, available options, and the state mapping where glass is used only in the visible expanded state.
- Full verification must cover compilation for the macOS 14 deployment target and app-bundle checks.
- The actual system-glass refraction, pointer response, text contrast, and expansion/collapse appearance still require manual confirmation on a physical-notch Mac.
