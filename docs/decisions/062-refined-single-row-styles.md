---
status: active
contract_ids: [FLOATING-STYLES-062, FLOATING-FLOW-061]
supersedes: []
owner: project-maintainer
created_at: 2026-10-14
---

# Refine the other three single-row styles

The user accepted the corrected flow, asked for the other styles to become
simple and attractive with immediately distinct running/idle appearances,
and observed that the earlier result felt less refined. The previous orbit
combined an ellipsis, a ring and text; identical text treatment also weakened
the distinction between active and resting states.

This L2 change refines signature, orbit and elapsed presentation only:

- Use one 16pt indicator slot and one single-line text region, separated by
  6pt. Signature/orbit share readable proportional 11pt medium text. Keep
  stored text, the 12-character normalization, natural text size and truncation.
- Signature uses a small steady vertical cursor when running, a horizontal
  dash when idle, and a green check for brief completion. Running text is
  brighter; idle is quieter but readable. No animated equalizer is added.
  Signature shimmer now runs only during running, explicitly superseding
  the inherited all-state shimmer rule from decisions 041 through 060.
  Retain its five-second period and native visible-only lifecycle. This
  makes resting text still and keeps active text readable between highlights.
- Orbit uses one integrated 16pt mark in the same slot, without a separate
  ellipsis. Running has a ring and orbiting bead (static bead when motion is
  off); idle has a quiet ring with a dash; completion replaces the ring with
  a check. SwiftUI owns static shapes; the native layer owns only the bead.
- Elapsed shows one clock and monospaced time when running; the shared dash
  plus localized Idle and check plus Finished cover resting states. Do not
  add another running word or redundant activity symbol beside the clock.

Preserve the user-accepted flow exactly, the selected flow preference,
212x30 geometry, left Off/five-hour routing, quota styles/values, sample quota,
preview/live renderer, two steady states and five-second completion feedback,
history, app animation switch, camera geometry, hover/collapse and reset.
Authentication, new settings, notifications and releases are out of scope.

Rejected: extra activity glyphs beside the orbit, two-line arrangements,
animated bars plus shimmering text, and relying only on color or movement.
Disabled motion must retain distinct shape cues; long labels must not shift
the weekly quota lane. The elapsed mode retains real task start semantics.

Validation includes failing running-only shimmer and integrated-layout guards,
the existing state silhouette and Off/five-hour matrices, unchanged flow
guards, real and preview motion-switch checks, production build and native UI
inspection. Static renders do not establish animation smoothness or physical
notch acceptance. Restore temporary preferences and leave the accepted flow
selected after inspecting the alternatives.

## Validation, 2026-10-14

- Before the production change, three running-only shimmer guards failed
  with eight expected assertions against the inherited all-state behavior.
- Focused checks: 35 tests, one opt-in capture skipped, no failures. Five
  new rendered guards cover the fixed mark slot, static orbit bead versus
  idle dash, shared text placement and brightness, truthful elapsed/unknown
  time, localized resting labels, long text and the fixed weekly quota lane.
  Signature text comparisons use a real offscreen AppKit view capture:
  SwiftUI ImageRenderer substitutes a colored unsupported-view placeholder
  for the native overlay, even when that overlay's animation is stopped.
  The exact pixel comparison and brightness assertion remain in force.
- `./scripts/verify.sh` passed: 322 tests, two opt-in captures skipped,
  zero failures (320 passed), followed by production build, app resources
  and signature validation. The native SwiftPM backend was used, matching
  the existing resource-bundle contract on this machine. No resource guard
  or accepted flow test was removed or relaxed.
- Restarted the exact previously running app bundle in this worktree's
  `dist/CodexNotch.app`; confirmed the new executable process and inspected
  native Settings and the real compact floating bar. All three styles were
  checked in running, idle and completion samples. With animations and the
  left icon disabled, the signature retained cursor/dash, the orbit retained
  bead/dash, and the elapsed style retained its clock and time.
- Actual compact-bar captures showed signature highlight changes and orbit
  bead positions at different times, plus the real task timer. A naturally
  occurring completion cue was observed, followed by running again on the
  next observation. This was not a measurement of the five-second deadline.
  Completion timing remains covered by the unchanged state-machine guards.
- Restored the user's selected flow, animations on and Codex left icon.
  The stored `keep going` text and quota-ring preference were preserved.
  The final live bar showed the accepted single flow. No quota reset was used.

The active screen uses floating-bar mode. Physical camera clearance and
hover/collapse were not re-tested in this presentation-only change. Static
captures and observed phase changes do not establish perceived smoothness;
final real-hardware appearance remains subject to user confirmation.
