---
status: active
contract_ids: [SETTINGS-MOTION-021]
supersedes: []
owner: project-maintainer
created_at: 2026-09-13
---

# Independent app animation switch and concise Settings copy

The user explicitly asked to say only that disabling animations reduces
resource use, and to stop linking the app switch to system Reduce Motion.
This supersedes that requirement in SETTINGS-PREFERENCES-020 and all of its
inherited motion contracts, while preserving all other animation conditions.
It also replaces the system-linkage and CPU/GPU copy in decision 050.

This is an L2 behavior change. Use the same stored app switch for runtime
surface transitions, the live SwiftUI surface, and the Settings preview.
Remove system Reduce Motion inputs from those paths and the legacy battle
policy. Do not change system accessibility settings. Task, expansion,
visibility and detachment gates, static status, timing, layouts, quota and
task updates, defaults and stored preferences remain unchanged. Performance
tuning, animation redesign and releases are out of scope.

The Settings footer reads “关闭动画可减少开销，额度和任务状态照常更新。”
Screen hints use “刘海模式” and “无刘海或外接屏幕模式”, still based on the
actual display route. Style descriptions explain what users see.

Keep the existing app-switch tests, adapting the superseded system gate, and
host the live floating surface and preview under both app-switch values.
Check actual animation requests,
detached-layer inactivity, retained state and advancing clocks. Run focused
checks and full verification, then rebuild/restart and read the local Settings.
SwiftUI exposes accessibilityReduceMotion as read-only, so it cannot be
injected into these hosted tests. Audit that runtime, live view and preview no
longer read that environment value or the NSWorkspace equivalent; changing
the real system setting remains a separate hardware check, not a passed test.
Visual smoothness and physical-notch clearance still need hardware acceptance;
automated animation requests do not prove those outcomes.

## Verification

Focused motion/preference checks passed 23 tests. Full verification passed 92
contracts and 231 tests (2 existing opt-in skips, zero failures), release build,
bundle resources and signing checks. Source inspection found no remaining
system Reduce Motion reads in the app. The hosted live/preview test confirmed
both switch states, stopped detached layers and advancing clocks.

Restarted the verified local app and read the Chinese Appearance and Floating
Bar panes. The one-sentence animation footer and new screen description fit
without clipping. Turning the app switch off displayed the preview's off hint;
turning it back on removed that hint. Restored the user's original enabled
animation preference, retaining all other preferences. English visual layout,
real system-switch combinations, external-display changes and continuous
physical-notch motion remain unverified. System settings were not changed.

## User-facing explanation pass

The user narrowed the product review to Settings explanations. Keep this L2
follow-up limited to bilingual Settings names and copy. Preserve all control
behavior, preference keys, routing, the independent animation switch and
SETTINGS-MOTION-021; runtime changes, onboarding and new features are out of
scope. Use existing guards and the full build, then read the rebuilt Settings.

Describe where to find recent tasks, why a quota can replace the selected
left icon specifically beside a physical notch, how Off makes menu-bar space,
what each center style looks like, and what empty custom text displays. Give
an action for pending/failed login setup. Keep the accepted short animation
footer and screen-mode names. The preview explanation distinguishes example
data from the user's real task and quota. Avoid implementation vocabulary and
do not promise that attaching any display changes the active route.

The copy-only pass passed full verification (92 contracts, 231 tests with 2
existing skips and zero failures, bundle/build/signing checks). Restarted the
rebuilt local app and inspected all three Chinese Settings panes. Recent-task
instructions, left-side quota/Off guidance, the unchanged short animation
footer, screen applicability, sample-data caption and elapsed-style help were
visible without clipping. The check did not change preferences. English visual
layout and previously listed real-screen/motion checks remain unverified.

## Neutral Settings tone

The user found the explanation pass too conversational. This L2 follow-up
changes bilingual copy only, preserving SETTINGS-MOTION-021, SETTINGS-WINDOW-022,
all controls, storage and runtime behavior. Functional changes and layout
redesign are out of scope. Use concise, neutral product language: purpose,
visible result and necessary conditions. Avoid conversational encouragement,
implementation jargon and unnecessary repetition. Keep the accepted animation
resource-use explanation and screen-mode names. Run the existing full check
and read the rebuilt Settings; no new tests are needed for string rewrites.

The neutral-copy revision passed the full check: 93 contracts, 231 tests with
two existing skips and zero failures, plus bundle/build/signing validation.
Restarted the rebuilt app, read General and inspected the English Floating Bar
pane visually; the contextual paragraph and elapsed-style footer fit without
clipping. Retained the user's current English language, zero recent tasks and
elapsed style. Chinese strings were reviewed in source; the rewrite changes
no controls or window activation behavior.
