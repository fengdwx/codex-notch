---
status: active
contract_ids: [FLOATING-FLOW-061, ACTIVITY-FEEDBACK-060]
supersedes: []
owner: project-maintainer
created_at: 2026-10-14
---

# A single centered running light

The user rejected the flow style's status text stacked above a thin line.
The screenshot shows that the label dominates the bar and the light is pushed
towards its bottom edge. The existing sweep is running; a static screenshot
does not establish a stalled animation.

This L2 change replaces only the flow style's presentation. Running is a
centered 96x4pt blue light with a moving highlight. Without motion it retains
a static bright segment. Idle is a quiet centered 64x2pt neutral line. The
brief completion cue is a single centered green check. No status word or
ellipsis is stacked above or placed beside this style's light.

Preserve the two steady activity states and five-second feedback tracker,
static shape distinction, left Off and five-hour routing, quota semantics,
212x30pt geometry, app animation switch, visibility lifecycle, shared real
and preview renderer, sample quota, preference keys/defaults, all other
styles, reset confirmation and hover behavior. Physical-notch geometry,
notification behavior, account actions, release and packaging are out of scope.

Use the existing native sweep for animation and a SwiftUI rail/static
highlight for reliable nonanimated presentation. Do not add a task timer or
reset the sweep on one-second view refreshes. Retain its existing 2.8-second
linear travel and clipping. A text-plus-line alternative was rejected because
it repeats the user's reported visual problem; color-only idle differentiation
was rejected because the states must remain distinguishable without motion.

Validation must include a failing guard against the old stacked content,
rendered vertical centering and a bounded single-line height, retained static
state distinction, stable native animation across same-size updates, full
verification, rebuild/restart of the actual app, and native UI observations
of running movement and resting states. Screenshots establish layout; moving
highlight observations must cover different phases. No real reset is needed.

## Validation, 2026-10-14

- Before the layout fix, the new render guards rejected the old stacked flow:
  its visible height was 16.5-17pt, the idle content remained 96pt wide, and
  completion still included a line/label instead of a single check.
- Focused tests passed 20 checks with one opt-in capture skipped. The final
  full verification passed 317 tests with two opt-in capture tests skipped
  and zero failures, followed by production build, resource and signature
  validation. The existing Swift 6.4 native backend workaround was used.
- Restarted the exact running managed-worktree app and read back its new
  process path. Native captures of the real running bar showed the highlight
  at different positions across multiple sweep periods, with the rail centered
  and no stacked content. These observations confirm movement, not a measured
  frame-rate or a new physical-notch geometry acceptance.
- Native Settings inspection confirmed running, idle, check-only completion,
  and a visible centered bright segment with animations disabled. Restored
  animations on and retained the user's selected flow style and Codex icon.
  Account reset, completion timing and physical-notch layout were unchanged.
