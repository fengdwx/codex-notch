---
status: active
contract_ids: [QUOTA-SEMANTICS-055]
supersedes: []
superseded_by: null
owner: project-maintainer
created_at: 2026-09-06
last_verified_commit: null
---

# Share the weekly quota color with status artwork

The user requested a theme matching the right quota ring. Resolve the status
accent through `UsageSnapshot.weeklyWindow` and the existing `QuotaColorScale`,
so quota boundaries and updates match the right ring and wave ball exactly.
Use neutral gray without weekly data, even when five-hour data exists.

The Codex foreground now keeps a white outline, black interior, and white
prompt under [decision 030](030-white-codex-flower-outline.md). Use the exact
accent for both brands' running echo in healthy and warning bands, including
its static motion-disabled version. Following the user's concern about an
alarming red pulse, the critical band uses a soft neutral-white running echo.
Keep the green completion echo/check
and the white ChatGPT foreground.
Settings retains its neutral brand sample and adds no new color preference.

Color changes update the echo layer's background inside a disabled-action
transaction, preserving an existing pulse and the shared visibility lifecycle.
No new image, timer, network request, quota palette, or geometry is required.

Rejected: a fixed green status theme (disagrees when quota turns yellow/red),
using five-hour quota (disagrees with the right lane), recoloring the prompt
(reduces legibility), or using a full-bright flower (competes with the number).

`StatusIconThemeTests` covers weekly color boundaries, missing weekly data,
white-prompt contrast, the critical band's neutral running cue, and live layer
recoloring without pulse replacement.
Existing asset, choice, motion, and quota guards remain. Full verification and
real-notch inspection are required for matching hues and perceived motion.
