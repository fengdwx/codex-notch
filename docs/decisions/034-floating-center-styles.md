---
status: superseded
contract_ids: [FLOATING-CENTER-051, SETTINGS-PREFERENCES-018]
supersedes: [016-sword-wanderer-battle-island]
superseded_by: 040-running-signature-shimmer
owner: project-maintainer
created_at: 2026-09-13
---

# Replace the battle with selectable center styles

The user selected personal signature, orbit signature, running timer and thin
light flow after comparing live concepts. Fog resembled a display defect and
the thickened bar was rejected. The old battle remains in source and tests for
historical coverage, but is no longer in the live view hierarchy.

Store `floatingCenterStyle` and `floatingCenterText` using the same local
AppStorage pattern as status artwork. Default to signature and `Codex`; unknown
styles fall back safely. Normalize displayed text to one line and 12 Swift
Characters, preserving composed emoji. Keep text clipped/truncated inside the
existing 136pt center lane, using 11pt regular system monospaced text at reduced
contrast. This follows the quieter typography of the reference demonstration
without treating its web font as an installed native font.

Use the actual displayed primary session's `startedAt` and the existing
one-second model clock. No new timer, polling, usage request, task identity or
history is introduced. Idle/completed/missing-start timer states show signature.

Orbit and 96x3pt flow reuse the visible-only Core Animation lifecycle and its
preferred 8 FPS. Do not restart animation on a clock or text update. Stop for
completion, expanded headers, app motion off, Reduce Motion and detachment.
Signature and timer need no continuous decorative renderer. Physical-notch
centers stay clear of the camera; quota lanes and floating geometry stay intact.

Rejected: fog, thick bars, terminal/flipboard variants not selected by the user,
an animation that continues after completion, and new third-party features.

Verification: focused persistence/text/timer/layer/motion tests, full verify,
live settings readback and restart, then real-display legibility and motion.
