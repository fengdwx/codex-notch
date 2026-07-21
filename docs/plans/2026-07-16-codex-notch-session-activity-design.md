# CodexNotch Quota and Task-State Design

## 1. Product Conclusions

CodexNotch is an independent native macOS app, not an Atoll, CodexIsland, CC Switch, or CodexBar plugin. It does two things: display ChatGPT Codex quota beside the notch, and continuously show task status in any foreground app while a Codex task is running, with one-click navigation back to that task.

macOS has no public Dynamic Island plugin API, so the app uses an AppKit borderless `NSPanel` to simulate a notch island. The window is positioned from `NSScreen` safe areas and uses a nonactivating panel so it does not steal keyboard focus from the current app. SwiftUI owns content and animation; AppKit owns window lifetime, level, and click behavior.

V1 does not depend on hooks, Codex app-server, or a third-party background process. Quota comes from the local Codex login state and usage endpoint; task activity comes from local rollout JSONL files already written by Codex. The two data paths are independent: a quota failure does not stop task reminders, and a monitoring failure does not clear the last successful quota.

## 2. Core Interaction

Notch state follows this priority order:

1. A task is running: always show the working state; highest priority.
2. A task just completed: show a completion cue for about 3 seconds, then return to quota if ChatGPT is frontmost.
3. ChatGPT (formerly Codex, bundle ID `com.openai.codex`) is frontmost with no running task: show the quota overview.
4. Otherwise: collapse fully into the physical notch.

The compact state resembles a music playback control wrapped around both sides of the notch:

```text
[ChatGPT icon  Codex working  02:18]  [95% weekly quota remaining]
```

When multiple tasks are running, the task with the most recent activity event is primary. Clicking the compact state opens the primary task; hovering expands a card listing every running task, and each row opens its corresponding Codex task. Expanded order is descending by recent activity.

With no running task, clicking the compact state activates ChatGPT and hovering expands quota details. After ChatGPT leaves the foreground, collapse after about 1.2 seconds to avoid flicker during fast app switching. The completed state uses a short green cue; the running state uses only a subtle pulse, with no pet, audio, or complex effects.

## 3. Task-Activity Data Flow

The monitored directory is `CODEX_HOME/sessions`, defaulting to `~/.codex/sessions`. On launch, scan recently modified rollout files; then use FSEvents for directory changes and read appended JSONL incrementally by file offset instead of reparsing the entire history.

Key event mappings:

| JSONL content | State change |
|---|---|
| `session_meta.payload.id` | Save the task ID for deep-link navigation |
| `event_msg.payload.type = task_started` | Mark the corresponding turn as running |
| `event_msg.payload.type = task_complete` | Mark the corresponding turn as completed |
| `event_msg.payload.type = turn_aborted` | Mark the corresponding turn as aborted |

Each activity record stores `threadID`, `turnID`, `cwd`, `originator`, start time, last activity time, and rollout path. Choose the primary task by last activity time, not by filename.

An abnormal app exit can leave a `task_started` event without a termination event. During V1 cold-start recovery, scan only files modified in the last 24 hours; mark an unfinished task stale and hide it after 6 hours without a file update. This threshold is a failure guard, not the normal task-completion rule. Skip malformed lines and continue monitoring; one incomplete JSON record must not stop the monitor.

## 4. Precise Navigation

The current Codex desktop app registers the `codex` URL scheme. Task clicks use:

```text
codex://threads/<thread-id>
```

Open it with `NSWorkspace.shared.open`. If the task ID is missing or the URL cannot be opened, fall back to activating ChatGPT by bundle identifier `com.openai.codex` instead of failing silently. Although the current app's display name is ChatGPT, the bundle ID and `codex://` scheme retain their original values; ChatGPT Classic is not a monitoring target. The window itself uses `.nonactivatingPanel`, so a click does not first make CodexNotch frontmost.

Expanded task rows show the leaf project-directory name, runtime, and status. They do not read or display user-message bodies, reducing privacy exposure. V1 does not provide a task-termination button because controlling the Codex runtime would introduce additional risk and dependencies.

## 5. Quota Data Flow

Read the authentication file from `CODEX_HOME/auth.json`, defaulting to `~/.codex/auth.json`. Parse only `tokens.access_token` and `tokens.account_id`; keep the token in process memory only, never in a cache or log. Request `https://chatgpt.com/backend-api/wham/usage` and save a normalized quota snapshot on success.

Determine window type from `limit_window_seconds`; do not assume `primary_window` is always five hours or `secondary_window` is always weekly. If the current account returns only a 604800-second window, show only weekly quota; add more windows dynamically if they appear later.

Refresh timing:

- Refresh once at app launch.
- Refresh immediately when ChatGPT (`com.openai.codex`) becomes frontmost.
- Refresh when a new task starts.
- Refresh every 60 seconds while ChatGPT is frontmost or a task is running.
- Do not poll frequently while fully hidden.

On network failure, retain the last successful value and show its update time. Show “Sign in to ChatGPT again” for 401/403 and “Quota unavailable” when fields are missing. Usage is an internal endpoint whose fields may change, so decoding structures tolerate missing fields and the UI renders only data that exists.

## 6. Window and Screen Behavior

The window is a transparent, untitled, nonactivating `NSPanel` at `.popUpMenu` level with `.canJoinAllSpaces` and `.fullScreenAuxiliary` behavior. Position it from `safeAreaInsets`, `auxiliaryTopLeftArea`, `auxiliaryTopRightArea`, and the current screen frame rather than hard-coding pixels for the current MacBook.

The collapsed state does not receive mouse events so it cannot cover the menu bar; compact and expanded states accept clicks. Listen for screen-parameter changes and recalculate geometry after display connection, resolution changes, lid closure, and wake. If the main screen has no physical notch, V1 falls back to a menu-bar status item while retaining quota, task-list, and navigation capabilities.

Keep the window state model functional: inputs are the frontmost app, active-task set, recent completion event, quota snapshot, and hover state; outputs are `hidden`, `quotaCompact`, `workingCompact`, `completedCompact`, or `expanded`. This makes priority and delay logic testable without scattering business decisions across SwiftUI views.

## 7. Error Handling and Privacy

- Missing auth file: prompt the user to sign in to Codex while task monitoring continues.
- Failed usage request: retain the old value and show “Updated …”.
- Truncated or rotated rollout file: reset that file's offset and rebuild its state.
- Malformed JSONL line: skip it and record an error summary without message content.
- Failed deep link: activate ChatGPT (`com.openai.codex`).
- No-notch display: use the menu-bar fallback and do not create a misaligned floating window.
- Logs must not contain tokens, Authorization headers, complete usage responses, or user-message bodies.

## 8. V1 Boundaries

V1 includes a quota overview, persistent running-task status, a short completion cue, multiple-task listing, precise navigation, foreground triggers, full-screen and multi-Space support, no-notch fallback, and launch at login.

V1 does not include CC Switch cost statistics, a hard-coded five-hour window, task control, pet animation, a music module, a plugin system, cloud sync, remote notifications, or Mac App Store distribution. The open-source project provides a built `.app.zip`; ordinary users do not need Swift or Xcode, while source contributors install the matching Xcode toolchain described in the README. Local use starts with ad-hoc signing; Developer ID signing, notarization, and automatic updates can be considered after the app is stable.

## 9. Acceptance Scenarios

1. ChatGPT is frontmost and idle: the notch expands quota, then hides about 1.2 seconds after switching away.
2. Start a Codex task and switch to another app: the notch continues to show “Working”.
3. Task completes: show a green completion cue for about 3 seconds, then return to quota or hide based on the foreground app.
4. Two tasks run simultaneously: the primary state shows the most recently active task, and hover reveals both.
5. Click the primary state or a task row: open the corresponding Codex task directly.
6. The account returns only a weekly window: show only weekly quota and do not invent a five-hour window.
7. Usage network is unavailable: task state continues normally and quota retains its last successful value.
8. A rollout contains a malformed line or the app exits abnormally: the app does not crash and stale state is eventually cleared.
9. After full screen, Space changes, an external display, and wake: the window is positioned correctly.
