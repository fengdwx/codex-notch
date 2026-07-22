---
status: active
contract_ids: [NOTCH-MOTION-003, NOTCH-LAYOUT-038]
supersedes: [001-fixed-canvas-notch-motion]
superseded_by: null
owner: project-maintainer
created_at: 2026-07-23
last_verified_commit: null
---

# Keep the Fixed Canvas but Remove Card Transitions and Completion Fireworks

## Context

The fixed transparent canvas eliminated the earlier crash-prone approach that resized the `NSPanel` every frame. SwiftUI still animated the visible card inside that canvas, and task completion briefly created a 60fps particle timeline around the quota indicator. The user chose to remove both transient effects while retaining the low-power running quota animation and the static completed cue.

## Decision

- Keep preparing the final transparent canvas before applying an expanded state; never restore frame-by-frame `NSPanel` resizing.
- Apply expanded, collapsed, and reset-schedule surface-size changes with animations disabled, regardless of the app animation preference.
- Reclaim the unused transparent canvas immediately after collapse instead of waiting for a collapse duration.
- Never create the quota completion particle timeline. Preserve the green completed ChatGPT mark, checkmark, readable quota value, and the separate animation preference for continuous quota motion.

## Rejected Alternatives

- **Turn off the global animation preference**: Also stops the running quota signal, which the user wants to keep.
- **Only shorten the card and firework animations**: Retains transient layout and 60fps particle work without providing a necessary state cue.
- **Resize the outer panel directly during hover**: Reintroduces the layout instability and window jumping that the fixed-canvas design prevents.

## Consequences and Verification

- Card expansion and collapse have no spring or fade; physical-notch review must confirm the immediate switch remains understandable and top-anchored.
- Completion no longer has a quota firework; a real task completion must confirm the remaining green mark and check are clear.
- Focused style and geometry tests plus `./scripts/verify.sh` protect the static policy, window boundary, app bundle, and signing.
