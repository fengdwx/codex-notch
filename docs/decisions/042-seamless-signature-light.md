---
status: superseded
contract_ids: [FLOATING-CENTER-055, SETTINGS-PREFERENCES-018]
supersedes: [041-continuous-signature-shimmer]
superseded_by: 043-faster-signature-light
owner: project-maintainer
created_at: 2026-09-13
---

# Move a repeating light band without pauses or dark intervals

The previous six-second keyframe sweep held still during its first 15 percent
and last 20 percent, and its single highlight moved fully outside the text.
The user wants slower travel with light always moving within the word.

This L2 change retains decision 041's all-state motion, six-second period,
fonts, glyph mask, static dot and visibility/accessibility gates. Use two
identical soft gradient periods in one layer and translate by one text-width
at constant speed. At wraparound the visible pixels match, and each phase
contains the next highlight before the previous one leaves. The faint minimum
illumination is part of the gradient; no new timer, layer polling, font change,
setting, quota or card-animation change is introduced.

Rejected: making the old sweep longer again, brightening the entire static
label, adding only a second isolated flash, or hiding a jump with a pause.
Acceptance adds per-phase rendered illumination and movement checks to the
live fixture, retains state and stop guards, and verifies the bundle and the
installed app. A full-cycle recording is needed to judge the actual appearance.

Validation on 2026-09-13: the original sweep failed the live illumination and
movement guards, reproducing both the all-dim interval and endpoint holds.
After the change all twelve focused checks passed, including 58 live samples
across a complete cycle, task-state changes and disabled motion. Full
verification passed with 206 tests and two opt-in fixtures skipped, followed
by release build, bundle/resource and signing checks. The installed executable
matched the verified build, ran under launchd and showed an opaque 212x30
top-center window. An eight-second recording of the installed custom text
confirmed continuous slow movement with no all-dim pause across the repeat.
