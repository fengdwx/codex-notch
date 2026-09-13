---
status: active
contract_ids: [SETTINGS-PREFERENCES-020, SETTINGS-WINDOW-019, APP-LOGIN-001, APP-UPDATE-002]
supersedes: []
owner: project-maintainer
created_at: 2026-09-13
---

# Group Settings and make floating-only choices understandable on any screen

The maintainer found the long Settings form disorganized. The floating-center
paragraph did not explain why changing a style produces no visible change on
a physical-notch screen, where users cannot try another display configuration.

Use three native tabs in one 560x580pt window:

- General: launch at login, language, recent conversations, version and updates.
- Appearance: quota style, the left icon/Off choice and motion.
- Floating Bar: current applicability, an example preview, four center styles,
  and custom text where it can have an effect (including elapsed fallback).

Use system form typography, secondary footer text and native selection/focus
states, with 6pt spacing inside hints, 16pt outer insets and existing 11pt
monospaced center glyphs. Keep semantic system colors and the real black bar.
Choose concise labels and show only the selected style's explanation. Preserve
all existing storage keys, values, defaults, login approval/errors and update
actions. Native tabs, segmented controls and text fields keep keyboard access.

Move the existing screen-selection function unchanged to NotchScreenMetrics,
shared by the runtime and Settings. Determine applicability using the same
geometry route, not an assumption that an attached external screen or mirror
always uses a floating bar. Refresh the hint on appearance, app activation and
screen-configuration notifications. A hidden or unavailable surface must not
be described as currently applying floating settings.

The preview is explicitly an example, with no live quota, task or session data.
It reuses FloatingCenterContent from the live bar with parameterized style,
text and running/idle/completed state. The elapsed example is fixed at 02:18;
it starts no new clock or task. Orbit, shimmer and flow use the existing
visible-only layer renderer, respect app motion and Reduce Motion, and are
removed when leaving the tab. The layer lifecycle also stops when the window
is hidden or detached. Provide an accessibility label for the example.

This targeted interactive example explicitly replaces the inherited prohibition
on duplicate Settings previews only for floating-center education. It does not
add a second live quota preview, force a floating mode on a physical-notch Mac,
or alter real display routing, layout, motion, task state or quota semantics.
Longer explanatory paragraphs and disabling the controls on a notched display
were rejected because neither lets users understand and try the styles.

Verify applicability states, existing floating rendering/lifecycle and display
routing, the full build, and live Settings in both languages. Manually check
all styles, text, sample states, tab switching and reopening. Physical-notch
clearance and external-display attach/detach still require hardware acceptance.

## Verification on 2026-09-13

`./scripts/verify.sh` passed with 230 tests, including 2 existing opt-in skips,
and zero failures; the rebuilt local app passed bundle and signature checks.
Restarted that app and checked all three Chinese Settings panes. The physical
notch route showed the contextual notice; signature, orbit, elapsed and flow
choices updated the example. Elapsed showed 02:18; changing the sample to idle
updated its accessibility state. Flow removed the ineffective text field, and
switching back restored the existing signature text. The original preferences
were retained, including Chinese, signature/keep going, Codex, ring, motion on,
two recent tasks and launch at login off.

English visual layout, external-display attach/detach, physical menu clearance
and continuous animation remain unverified on hardware. This check does not
claim those paths passed.

## Plain-language copy follow-up

The user requested recognizable screen names and an explanation of the
animation switch's performance benefit. This is an L2 Settings copy change:
preserve SETTINGS-PREFERENCES-020, all preferences, screen routing and motion
behavior. Runtime changes, performance tuning, release and new modes are out
of scope. Use the existing route/motion guards and full verification, followed
by reading the updated Settings in the rebuilt app.

Use “刘海模式” and “无刘海或外接屏幕模式”, with the active label still chosen
from the real route. Explain the floating styles using the visible bar and
the preview, rather than abstract applicability or state terminology. Replace
long rendering descriptions with what users see while a task runs or ends.

The animation switch removes the requested repeating layer animations and
disables animated surface transitions. Explain the saved animation processing
as reduced CPU / GPU usage, while quota and task status continue to update.
This is not a measured performance or memory claim. If Reduce Motion is the
reason the example is still, say so instead of implying the app switch is off.
