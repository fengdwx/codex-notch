---
status: active
contract_ids: [EXPANDED-APPEARANCE-011, NOTCH-MOTION-002]
supersedes: [002-native-liquid-glass-with-fallback]
superseded_by: null
owner: project-maintainer
created_at: 2026-07-17
last_verified_commit: 53beec8
---

# Abandon Cross-Window Liquid Glass and Keep the Expanded Surface Pure Black

## Context

The project tested the shared SwiftUI/AppKit materials and a window-server background-sampling approach inspired by Atoll's layering. The final result on a physical-notch Mac was that the expanded card remained black during normal use and became a white translucent surface only while the system screenshot key was held. An incidental screenshot-path effect is not the glass appearance users see in daily use.

## Decision

- Keep the expanded card on the existing pure-black surface; no longer offer a glass/black appearance switch.
- Remove the glass implementation path and its Settings option so the Settings promise matches the real display.
- Keep the hidden state fully transparent, and preserve the compact state, fixed transparent canvas, downward-only expansion, and post-collapse canvas reclamation.
- Do not make system screenshots, screen recording, or additional screen-capture permission prerequisites for a glass appearance.

## Rejected Alternatives

- **Continue tuning private background-sampling parameters**: Real hardware proved that the effect depends on screenshot compositing, so more private parameters have no stable acceptance boundary.
- **Treat the white translucent screenshot effect as a pass**: Users still see black during normal use; a different compositing path cannot replace the real display.
- **Capture the screen and draw a fake background**: Requires extra screen-recording permission and introduces performance, privacy, and multi-display synchronization problems.
- **Keep the broken glass option as an experiment**: Lets users choose a result that is invisible and unpredictable in daily use.

## Consequences and Verification

- Automated tests lock the mapping where the visible surface is always pure black and the hidden canvas is always transparent.
- Settings no longer shows a card-appearance choice; it keeps only genuinely usable settings such as the recent-conversation count.
- Full verification continues to cover the macOS 14 deployment target, app bundle, fixed canvas, and window geometry.
- The final appearance of the black surface on a real notch is confirmed during normal use, not by the state shown while the screenshot key is held.
