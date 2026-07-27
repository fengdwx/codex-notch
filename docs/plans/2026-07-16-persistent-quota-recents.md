# Persistent Quota and Recent Conversations Implementation Plan

> **Superseded title-source note (2026-07-26):** Conversation labels now come
> only from Codex's read-only `threads.title` summary. See
> [decision 008](../decisions/008-local-thread-summary-titles.md); this
> historical plan's rollout-message-title steps must not be restored.

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep the quota notch visible, add truthful running/completed animation states, and show the two most recent real Codex conversations in the expanded panel.

**Architecture:** Extend rollout parsing with sanitized user-message titles, keep deduplicated recent completions in `ActiveSessionStore`, and derive compact/expanded presentation from one reducer. SwiftUI receives an explicit activity mode so the ring and conversation rows animate without changing quota semantics.

**Tech Stack:** Swift 6, SwiftUI, AppKit, XCTest, Swift Package Manager.

---

### Task 1: Parse conversation titles

**Files:**
- Modify: `Sources/CodexNotch/Models/SessionActivity.swift`
- Modify: `Sources/CodexNotch/Monitoring/RolloutEventParser.swift`
- Test: `Tests/CodexNotchTests/RolloutEventParserTests.swift`

**Step 1:** Add failing tests for `event_msg/user_message` parsing and whitespace-normalized, bounded titles.

**Step 2:** Run `swift test --filter RolloutEventParserTests` and confirm the new assertions fail.

**Step 3:** Add `userMessage` to `RolloutEventKind`, decode `payload.message`, and carry the latest title into the matching `SessionActivity`.

**Step 4:** Run the focused parser tests and confirm they pass.

### Task 2: Retain and deduplicate recent conversations

**Files:**
- Modify: `Sources/CodexNotch/Monitoring/ActiveSessionStore.swift`
- Modify: `Sources/CodexNotch/State/NotchPresentationState.swift`
- Test: `Tests/CodexNotchTests/ActiveSessionStoreTests.swift`

**Step 1:** Add failing tests for completed conversations sorted by time and deduplicated by thread ID.

**Step 2:** Keep active-session staleness at six hours while retaining completed summaries for 24 hours.

**Step 3:** Expose recent completions in the store snapshot and a two-row conversation summary in expanded state.

**Step 4:** Run `swift test --filter ActiveSessionStoreTests` and commit the data-model change.

### Task 3: Make compact quota persistent and model completion feedback

**Files:**
- Modify: `Sources/CodexNotch/State/NotchPresentationReducer.swift`
- Modify: `Sources/CodexNotch/App/NotchRuntimeCoordinator.swift`
- Modify: `Sources/CodexNotch/Window/NotchWindowController.swift`
- Test: `Tests/CodexNotchTests/NotchPresentationReducerTests.swift`

**Step 1:** Replace hidden-idle expectations with persistent `quotaCompact` expectations.

**Step 2:** Add tests for running priority, a 2.5-second completed state, expiry back to idle, and expanded recent conversations.

**Step 3:** Pass recent completions from the store through the runtime coordinator and reducer.

**Step 4:** Run the focused reducer tests and commit the state change.

### Task 4: Build the color scale and activity animations

**Files:**
- Modify: `Sources/CodexNotch/UI/NotchView.swift`
- Test: `Tests/CodexNotchTests/NotchTextTests.swift`

**Step 1:** Add tests for the clamped 0-to-100 quota hue scale.

**Step 2:** Use the interpolated quota color in the compact ring and expanded progress bar.

**Step 3:** Add idle, running, and completed ring modes. Running animates once from full to the actual value and uses a current-color travelling highlight; completed uses a one-shot current-color pulse. Respect Reduce Motion.

**Step 4:** Add a distinct completed animation to the left ChatGPT mark and run the focused tests.

### Task 5: Rebuild the expanded panel

**Files:**
- Modify: `Sources/CodexNotch/UI/NotchView.swift`
- Modify: `Sources/CodexNotch/Window/NotchGeometry.swift`
- Test: `Tests/CodexNotchTests/NotchGeometryTests.swift`

**Step 1:** Restore `%` only in the expanded quota value.

**Step 2:** Replace session cards with a grouped two-row recent-conversation list using animated running dots and completed checkmarks.

**Step 3:** Remove the heavy drop shadow, add a subtle attached-shape outline, and size expanded frames for zero or two rows.

**Step 4:** Run geometry tests and commit the visual change.

### Task 6: Verify and publish

**Files:**
- Verify: `dist/CodexNotch.app`
- Verify: `dist/CodexNotch-0.1.0-macOS-arm64.zip`

**Step 1:** Run `swift test`; expect all tests to pass.

**Step 2:** Run `RUN_TESTS=0 ./scripts/release.sh`; expect plist, code-signing, and archive verification to pass.

**Step 3:** Restart the built app and capture compact and expanded screenshots. Fix visual defects before delivery.

**Step 4:** Push the new commits to `main`, wait for GitHub Actions, and report the run URL and final commit IDs.
