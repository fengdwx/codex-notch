---
status: superseded
contract_ids: [NOTCH-VISIBILITY-046]
supersedes: [014-top-attached-no-notch-activity-island]
superseded_by: 016-sword-wanderer-battle-island
owner: project-maintainer
created_at: 2026-08-10
---

# Use a Menu-Bar-Height Task Status Island on No-Notch Displays

## Context

Real-machine review found two failures in the first top-attached activity island.
Its 32pt rectangle extended beyond the local 30pt menu-bar boundary, and the
left and right indicators were laid out against the full rectangle without
allowing for the narrower lower-corner envelope. The original code-drawn pixel
battle was also rejected as visually crude. The user selected the cleaner
task-status direction represented by Vibe Island.

## Decision

- Measure the menu-bar reservation from `screen.frame.maxY -
  screen.visibleFrame.maxY`. Cap the island at 30pt and never exceed a measured
  menu bar of at least 24pt; use a 28pt top-attached fallback when it is hidden.
- Use a 212pt compact width with explicit 8pt outer safety insets, 30pt icon and
  quota lanes, and a 136pt middle status lane.
- Keep the existing Codex state mark on the left and weekly quota on the right.
  Render the resolved task title as one truncated line in the middle; localized
  idle, running, and completed labels are fallbacks only.
- Center the title optically between symmetric indicator centers. Keep running
  and completed titles neutral white; completion green belongs only to the
  checkmark and quota indicator so a long title cannot make the island right-heavy.
- Remove the warrior/slime renderer and all decorative battle motion.
- Carry the measured compact height through compact and expanded rendering so
  the detail card begins below the exact attachment height.
- Keep physical-notch geometry and behavior unchanged.

## Rejected Alternatives

- **Retouch the code-drawn pixel battle**: Better spacing would not fix the
  weak art direction or make the center more informative.
- **Use a fixed 32pt no-notch height**: It crosses the 30pt menu bar observed on
  the target machine.
- **Remove the center lane entirely**: It avoids art risk but returns to an
  unexplained empty gap instead of showing the active task.

## Consequences and Verification

The no-notch surface becomes wider than the rejected battle version but every
point carries status information. Geometry and title-selection tests cover the
measured height and fallback logic. Real-machine screenshots must still confirm
the curved safety margin, long-title truncation, and compact-to-expanded motion.
