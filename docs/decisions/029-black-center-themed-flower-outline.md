---
status: active
contract_ids: [QUOTA-SEMANTICS-054]
supersedes: []
superseded_by: null
owner: project-maintainer
created_at: 2026-09-06
last_verified_commit: null
---

# Keep the flower center black and theme only its outline

The user clarified that the center should remain black. Keep the quota theme
on a narrow outer flower pattern rather than filling the entire shape.

Reuse the full embedded flower silhouette twice: the outer copy uses the
weekly quota accent, and an inner copy at 88 percent scale uses black. This
leaves approximately a 1pt outline at the existing 18pt size. Draw the original
white prompt above both. No asset regeneration or frame change is needed.

Keep the previous theme source and echo lifecycle, including the neutral-white
critical-state running echo. The red outline stays static. Completion keeps
its green acknowledgement; ChatGPT and the neutral Settings sample are unchanged.

The rendering guard uses SwiftUI ImageRenderer at 2x to check green, yellow,
and red states: center samples must be black, the prompt must remain white,
and colored pixels must be confined to a small part of the flower. The old
filled implementation fails these assertions. Existing contrast, quota-theme,
low-quota motion, asset, and geometry checks remain. Run full verification and
inspect the real notch for outline thickness and motion legibility.
