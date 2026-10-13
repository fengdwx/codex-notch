---
status: active
contract_ids: [ACTIVITY-FEEDBACK-060, QUOTA-RESET-059, NOTCH-HEIGHT-001, SETTINGS-MOTION-021]
supersedes: [044-signature-without-status-dot]
owner: project-maintainer
created_at: 2026-10-14
---

# Two steady activity states and brief completion feedback

The user approved two persistent states, running and idle, plus a roughly
five-second green completion cue. A completed turn is an event, not a permanent
activity state or a claim that the user's whole request passed acceptance.
The previous reducer derived completion from retained history, keeping the
island completed indefinitely. It also discarded the distinction between
task_complete and turn_aborted. Both behaviors conflict with this decision.

This is an L2 change. Preserve weekly/five-hour quota semantics and placement,
left-indicator Off geometry, fixed-canvas downward hover/collapse, all reset
consent and cancellation guarantees, language, preference keys/defaults,
signature text and its existing five-second decorative shimmer, app-controlled
motion and visible-only animation lifecycle. Authentication, reset requests,
releases, physical-notch dual-quota redesign, new notification permissions,
unread queues, acknowledgment buttons and history deletion are out of scope.

## Activity and feedback

- Retain normal completion versus explicit abortion in terminal records.
  Both may remain in recent history; an aborted turn is labelled Stopped and
  never produces the green completion cue. Missing/expired activity is not a
  successful completion.
- After initial discovery is complete, a new normal completion can trigger
  feedback for five seconds from observation. A per-runtime tracker owns the
  transient cue independently of history. Initial discovery, old records,
  duplicate scans, title/usage refresh and app restart do not replay history.
- On expiry show the current running state if any work remains, otherwise
  idle. A newly started task interrupts an older completion cue immediately.
  Other already-running tasks remain in the data during brief feedback.
- Hover and navigation do not acknowledge, delete or extend feedback. The
  existing one-second clock must expire it even when the session snapshot is
  unchanged. History remains count-limited at display, including count zero,
  without an age cutoff or new persistent history/notification cache.

## Readable floating presentation

The 212x30 floating bar keeps the existing lane geometry. It needs static
shape cues for busy, idle and just-finished states, including when the left
icon is Off or replaced by a five-hour quota. Distinct non-dot activity glyphs
in the center are permitted in place of the inherited no-indicator assumption;
do not restore the former four-pixel colored status dot. Retain the user's
signature and stored style. Motion/color are supporting cues, not the only
way to tell states apart. The minimal flow uses a blue moving line while
running, a neutral static line while idle and a clear green check on completion.
Elapsed mode shows a localized idle/completion state when not timing a task,
instead of falling back to the same signature in both states.

Settings must share the real pure floating renderer with fixture data and no
real actions, account reads or extra task timer. Its completion option is
labelled Completion cue and explains the five-second live duration. A preview
may pin a sample state so it can be inspected. Keep native keyboard controls,
the current selected style, quota style, icon/Off choice and animation setting.
Keep its quota fixed at 75 percent and static, as required by UI-READABILITY-058.
Physical-notch dual-quota geometry and priority are unchanged; the new center
glyph is not drawn in the camera cutout and cannot prove that route's static
state legibility. Real-hardware reporting must separate that limitation.

## Verification

Locate/add guards for live completion and exact timeout, concurrent work,
new-start priority, startup/discovery baseline, unchanged-snapshot expiry,
duplicate/old events, aborted turns, preserved history and count zero. Retain
existing regression tests; update incompatible expectations with this explicit
superseding contract. Verify shared preview/live rendering across styles and
states, disabled animation, left Off/five-hour replacement and localization.
Run full scripts/verify.sh, rebuild and restart the exact running bundle, then
inspect the real Settings and a live task transition. Synthetic fixtures and
static screenshots are not acceptance of live timing or physical-notch motion.

## Alternatives and consequences

Persistent completion was rejected because retained history would keep the
island in a success state even when nothing is running. An unread queue or
acknowledgment button was rejected because it adds inbox management to a
glanceable status utility. A brief cue can be missed while the user is away;
recent conversations remain the place to find those results. This cue means a
normal turn ended, not that the user's outcome has been independently accepted.

## Validation, 2026-10-14

- The old history-driven completion regression failed before implementation.
  State/parser/monitor/runtime focused checks then passed 58 tests, including
  a real temporary JSONL file, the coordinator's scheduled timer, unchanged
  snapshots and zero visible history. No account or real reset was used.
- Static render guards compare state silhouettes with RGB removed, and exercise
  every floating style, both languages, left Off and five-hour replacement.
  UI focused checks passed 20 tests with one opt-in capture test skipped.
- Full scripts/verify.sh passed 313 tests with two opt-in capture tests skipped
  and no failures, followed by production build, bundled-resource and signing
  verification. Swift 6.4 used its native build backend because the default
  backend changes this project's resource bundle layout; no resource assertions
  were weakened. The full run includes the final initial-scan sequence barrier.
- Restarted the exact previously running managed-worktree app and verified its
  new process path. Native UI inspection confirmed the live running signature,
  all three signature previews, timer completion text, flow idle/running,
  orbit layout, and all three signature previews with motion and the left icon
  disabled. Restored the original signature, text, Codex icon and animations.
- The real-account completion-to-five-second-expiry transition was not observed
  end to end in this session. The timer path is covered by the runtime fixture,
  but real hardware confirmation remains required. The current screen uses the
  floating layout: physical camera clearance, dual-quota state legibility and
  real-notch animation/hover acceptance are not claimed by these screenshots.
