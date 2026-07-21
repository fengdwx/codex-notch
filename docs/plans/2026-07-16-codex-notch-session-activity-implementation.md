# CodexNotch Session Activity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an independent macOS notch app that shows real Codex quota while ChatGPT (formerly Codex) is frontmost, keeps running Codex tasks visible while any app is frontmost, and can navigate precisely back to the corresponding task.

**Architecture:** Use AppKit `NSPanel` for the notch window and screen positioning, and SwiftUI for compact and expanded UI. Request quota from the local Codex login state through the usage endpoint, parse task state from FSEvents plus incremental JSONL reads, and let a pure state reducer determine the final presentation.

**Tech Stack:** Swift 5.9+ language mode, macOS 14+, AppKit, SwiftUI, Foundation, CoreServices/FSEvents, ServiceManagement, Swift Package Manager, and XCTest.

---

## Implementation Principles

- Project root: `/Users/david/projects/tmp/codex-notch`.
- Independent app with no dependency on Atoll, CodexIsland, CodexBar, CC Switch, hooks, or app-server.
- Drive each task through “failing test → minimal implementation → passing test → commit”.
- Do not commit tokens, auth files, real rollouts, complete usage responses, or user-message bodies.
- The current machine has a minor Swift compiler/SDK mismatch; do not enter business code until Task 0 passes. Ordinary users receive a built `.app` and do not need Swift or Xcode.

### Task 0: Pin the Toolchain and Create an Isolated Worktree

**Files:**
- Existing: `/Users/david/projects/tmp/codex-notch/docs/plans/2026-07-16-codex-notch-session-activity-design.md`
- Existing: `/Users/david/projects/tmp/codex-notch/docs/plans/2026-07-16-codex-notch-session-activity-implementation.md`
- Create: `/Users/david/projects/tmp/codex-notch/.gitignore`

**Step 1: Check the current toolchain**

Run:

```bash
cd /Users/david/projects/tmp/codex-notch
xcode-select -p
xcrun swift --version
xcrun --show-sdk-path
```

Expected: The Swift compiler can read the current macOS SDK. The known environment may report a mismatch such as “SDK built with Swift 6.2.3, compiler is Swift 6.2.4”.

**Step 2: Switch to a matching full Xcode installation**

If `/Applications/Xcode.app` is installed:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
xcrun swift --version
```

Expected: The command produces no SDK compatibility error. If full Xcode is not installed, this is a prerequisite for source builds by developers; ordinary users of the release app are unaffected.

**Step 3: Create ignore rules**

```gitignore
.build/
DerivedData/
*.xcuserstate
CodexNotch.app/
*.dSYM/
.DS_Store
```

**Step 4: Initialize the repository and commit the plan documents**

Run:

```bash
cd /Users/david/projects/tmp/codex-notch
git init
git branch -M main
git add .gitignore docs/plans
git commit -m "docs: define CodexNotch v1"
```

Expected: The initial commit succeeds and the worktree is clean.

**Step 5: Create the implementation worktree**

Run:

```bash
mkdir -p /Users/david/projects/tmp/codex-notch-worktrees
git worktree add /Users/david/projects/tmp/codex-notch-worktrees/v1 -b feat/codex-notch-v1
```

Expected: The new worktree is at `/Users/david/projects/tmp/codex-notch-worktrees/v1`. Run subsequent commands from that directory.

### Task 1: Establish a Testable Swift App Skeleton

**Files:**
- Create: `Package.swift`
- Create: `Sources/CodexNotch/App/CodexNotchApp.swift`
- Create: `Sources/CodexNotch/App/AppDelegate.swift`
- Create: `Tests/CodexNotchTests/SmokeTests.swift`

**Step 1: Write the failing smoke test**

```swift
import XCTest
@testable import CodexNotch

final class SmokeTests: XCTestCase {
    func testApplicationIdentifierIsStable() {
        XCTAssertEqual(AppIdentity.bundleIdentifier, "com.david.codexnotch")
    }
}
```

**Step 2: Create `Package.swift` and run the test**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexNotch",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CodexNotch", targets: ["CodexNotch"])],
    targets: [
        .executableTarget(name: "CodexNotch"),
        .testTarget(name: "CodexNotchTests", dependencies: ["CodexNotch"])
    ],
    swiftLanguageVersions: [.v5]
)
```

Run: `swift test --filter SmokeTests`

Expected: FAIL because `AppIdentity` does not exist.

**Step 3: Add the minimal app entry point**

```swift
import SwiftUI

enum AppIdentity {
    static let bundleIdentifier = "com.david.codexnotch"
    static let chatGPTCodexBundleIdentifier = "com.openai.codex"
}

@main
struct CodexNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

For now, `AppDelegate` only sets the `.accessory` activation policy.

**Step 4: Verify and commit**

Run:

```bash
swift test --filter SmokeTests
git add Package.swift Sources Tests
git commit -m "chore: bootstrap native CodexNotch app"
```

Expected: 1 test passes.

### Task 2: Define the Quota Model and Dynamic Window Classification

**Files:**
- Create: `Sources/CodexNotch/Models/UsageSnapshot.swift`
- Create: `Sources/CodexNotch/Usage/UsageWindowClassifier.swift`
- Create: `Tests/CodexNotchTests/UsageWindowClassifierTests.swift`

**Step 1: Write failing classification tests**

```swift
func test604800SecondWindowIsWeekly() {
    XCTAssertEqual(UsageWindowClassifier.kind(seconds: 604_800), .weekly)
}

func test18000SecondWindowUsesDynamicRollingLabel() {
    XCTAssertEqual(UsageWindowClassifier.kind(seconds: 18_000), .rolling(hours: 5))
}

func testMissingWindowIsNotInvented() {
    let snapshot = UsageSnapshot(windows: [])
    XCTAssertTrue(snapshot.windows.isEmpty)
}
```

Run: `swift test --filter UsageWindowClassifierTests`

Expected: FAIL because usage types do not exist。

**Step 2: Implement the minimal model and classifier**

```swift
enum UsageWindowKind: Equatable, Sendable {
    case rolling(hours: Int)
    case daily
    case weekly
    case custom(seconds: Int)
}

struct UsageWindow: Equatable, Sendable, Identifiable {
    let id: String
    let kind: UsageWindowKind
    let usedPercent: Double
    let resetAt: Date?
    var remainingPercent: Double { max(0, 100 - usedPercent) }
}

struct UsageSnapshot: Equatable, Sendable {
    let windows: [UsageWindow]
    let fetchedAt: Date
    init(windows: [UsageWindow], fetchedAt: Date = .now) {
        self.windows = windows
        self.fetchedAt = fetchedAt
    }
}
```

Classification rules: classify 6–8 days as weekly, a near-one-day window as daily, a short window divisible into hours by its actual hour count, and all others by custom duration. Never classify from the primary/secondary field names.

**Step 3: Verify boundaries and commit**

Add tests for `usedPercent > 100`, negative values, and unknown durations; normalize to 0–100.

Run:

```bash
swift test --filter UsageWindowClassifierTests
git add Sources/CodexNotch/Models Sources/CodexNotch/Usage Tests/CodexNotchTests/UsageWindowClassifierTests.swift
git commit -m "feat: classify Codex usage windows by duration"
```

Expected: All quota-classification tests pass.

### Task 3: Read Local Authentication and Request Quota

**Files:**
- Create: `Sources/CodexNotch/Usage/CodexAuthReader.swift`
- Create: `Sources/CodexNotch/Usage/CodexUsageClient.swift`
- Create: `Sources/CodexNotch/Usage/UsageResponseDTO.swift`
- Create: `Tests/CodexNotchTests/CodexAuthReaderTests.swift`
- Create: `Tests/CodexNotchTests/CodexUsageClientTests.swift`
- Create: `Tests/Fixtures/auth-valid.json`
- Create: `Tests/Fixtures/usage-weekly-only.json`
- Create: `Tests/Fixtures/usage-multiple-windows.json`

**Step 1: Write failing auth and response-mapping tests**

Tests must cover:

- Reading the access token and account ID from a temporary fixture.
- `CODEX_HOME` overriding the default directory.
- Creating only one weekly card when the only window is 604800 seconds.
- No error when secondary is missing.
- Mapping 401 to `reauthenticationRequired`.

Run: `swift test --filter CodexAuthReaderTests && swift test --filter CodexUsageClientTests`

Expected: FAIL because reader and client do not exist。

**Step 2: Implement authentication-reading boundaries**

```swift
struct CodexCredentials: Sendable {
    let accessToken: String
    let accountID: String?
}

protocol CredentialsReading: Sendable {
    func read() throws -> CodexCredentials
}

struct CodexAuthReader: CredentialsReading {
    let environment: [String: String]
    let homeDirectory: URL

    func read() throws -> CodexCredentials {
        let root = environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) }
            ?? homeDirectory.appending(path: ".codex")
        let data = try Data(contentsOf: root.appending(path: "auth.json"))
        return try JSONDecoder().decode(AuthDTO.self, from: data).credentials
    }
}
```

**Step 3: Implement a usage client with an injectable URLSession**

Use the fixed request `GET https://chatgpt.com/backend-api/wham/usage` with `Authorization: Bearer ...`; set `ChatGPT-Account-Id` when an account ID exists. Make every non-critical DTO field optional, and send primary and secondary windows through `UsageWindowClassifier`.

Do not record request headers or response bodies. The client returns `UsageSnapshot` or a structured error and does not modify the UI directly.

**Step 4: Test and commit**

Run:

```bash
swift test --filter CodexAuthReaderTests
swift test --filter CodexUsageClientTests
git add Sources/CodexNotch/Usage Tests
git commit -m "feat: fetch Codex quota from local login"
```

Expected: Fixture tests pass and test output contains no fixture token.

### Task 4: Parse Rollout JSONL Events

**Files:**
- Create: `Sources/CodexNotch/Models/SessionActivity.swift`
- Create: `Sources/CodexNotch/Monitoring/RolloutEventParser.swift`
- Create: `Tests/CodexNotchTests/RolloutEventParserTests.swift`
- Create: `Tests/Fixtures/rollout-start-complete.jsonl`
- Create: `Tests/Fixtures/rollout-aborted.jsonl`
- Create: `Tests/Fixtures/rollout-malformed-line.jsonl`

**Step 1: Write failing event-sequence tests**

```swift
func testStartedThenCompletedLeavesNoActiveTurn() throws {
    let events = try fixtureEvents("rollout-start-complete")
    let result = ActiveSessionReducer.reduce(events)
    XCTAssertTrue(result.active.isEmpty)
    XCTAssertEqual(result.completed.count, 1)
}

func testMalformedLineDoesNotDiscardFollowingEvent() throws {
    let events = try fixtureEvents("rollout-malformed-line")
    XCTAssertTrue(events.contains { $0.kind == .taskStarted })
}
```

Run: `swift test --filter RolloutEventParserTests`

Expected: FAIL because parser does not exist。

**Step 2: Implement narrow-field parsing**

Decode only top-level `timestamp` and `type`, plus `id`, `type`, `turn_id`, `cwd`, and `originator` in the payload. Ignore message content and other response items.

```swift
enum RolloutEventKind: Equatable, Sendable {
    case sessionMeta(threadID: String, cwd: String?, originator: String?)
    case taskStarted(turnID: String?)
    case taskCompleted(turnID: String?)
    case turnAborted(turnID: String?)
}
```

Return a malformed line as an ignorable parse issue instead of throwing and terminating the file. If a termination event has no turn ID, end the current active turn for that rollout.

**Step 3: Verify and commit**

Run:

```bash
swift test --filter RolloutEventParserTests
git add Sources/CodexNotch/Models/SessionActivity.swift Sources/CodexNotch/Monitoring Tests
git commit -m "feat: parse Codex rollout activity events"
```

Expected: Started, complete, aborted, and malformed-line recovery all pass.

### Task 5: Read Files Incrementally and Aggregate Multiple-Task State

**Files:**
- Create: `Sources/CodexNotch/Monitoring/IncrementalJSONLReader.swift`
- Create: `Sources/CodexNotch/Monitoring/ActiveSessionStore.swift`
- Create: `Sources/CodexNotch/Monitoring/RolloutActivityMonitor.swift`
- Create: `Sources/CodexNotch/Monitoring/FSEventChangeSource.swift`
- Create: `Tests/CodexNotchTests/IncrementalJSONLReaderTests.swift`
- Create: `Tests/CodexNotchTests/ActiveSessionStoreTests.swift`

**Step 1: Write failing incremental and multiple-task tests**

Cover the following behavior:

- The second read returns only newly appended lines.
- A file shorter than the old offset is treated as truncated and read from the beginning.
- Two active tasks are sorted by descending `lastActivityAt`.
- A complete event removes only its corresponding task.
- An unmatched start with no update for six hours is cleaned up during cold start.

Run: `swift test --filter IncrementalJSONLReaderTests && swift test --filter ActiveSessionStoreTests`

Expected: FAIL。

**Step 2: Implement a testable offset reader**

```swift
struct FileCursor: Equatable, Sendable {
    var offset: UInt64 = 0
    var remainder = Data()
}

protocol IncrementalReading: Sendable {
    func readNewLines(at url: URL, cursor: inout FileCursor) throws -> [Data]
}
```

Pass only complete newline-terminated records to the parser; keep a trailing partial line in `remainder` until the next append.

**Step 3: Implement the active-task store**

`ActiveSessionStore` uses an actor to serialize state. Each rollout retains thread metadata and the current turn. The public snapshot is a sorted `[SessionActivity]`, with the primary task always first.

**Step 4: Connect FSEvents**

FSEvents only reports which paths may have changed; actual reads still go through the offset reader. Limit the launch scan to `.jsonl` files modified within the last 24 hours under sessions. Hop back to the actor in change callbacks to avoid concurrent cursor mutation.

**Step 5: Test and commit**

Run:

```bash
swift test --filter IncrementalJSONLReaderTests
swift test --filter ActiveSessionStoreTests
git add Sources/CodexNotch/Monitoring Tests/CodexNotchTests
git commit -m "feat: monitor active Codex sessions incrementally"
```

Expected: Multi-file, truncation, partial-line, and stale-cleanup tests all pass.

### Task 6: Monitor ChatGPT Foreground State and Deep-Link Codex Tasks

**Files:**
- Create: `Sources/CodexNotch/Monitoring/FrontmostAppMonitor.swift`
- Create: `Sources/CodexNotch/Navigation/CodexThreadNavigator.swift`
- Create: `Tests/CodexNotchTests/CodexThreadNavigatorTests.swift`

**Step 1: Write failing deep-link tests**

```swift
func testThreadURLUsesCodexScheme() throws {
    let url = try CodexThreadNavigator.threadURL(id: "019f-test")
    XCTAssertEqual(url.absoluteString, "codex://threads/019f-test")
}

func testInvalidThreadIDFallsBackToActivation() {
    XCTAssertNil(CodexThreadNavigator.threadURLIfValid(id: ""))
}
```

Run: `swift test --filter CodexThreadNavigatorTests`

Expected: FAIL。

**Step 2: Implement workspace monitoring**

Read `NSWorkspace.shared.frontmostApplication` at launch, then observe `NSWorkspace.didActivateApplicationNotification`. The target is ChatGPT, which currently hosts Codex tasks and still uses bundle ID `com.openai.codex`. Do not depend on the display name or installation path, and do not mistake ChatGPT Classic for the target app.

**Step 3: Implement navigation fallback**

Open a valid thread ID with `NSWorkspace.shared.open(codexURL)`; when opening returns false, use `NSWorkspace.shared.openApplication` to activate ChatGPT with bundle ID `com.openai.codex`. With no active task, clicking the compact quota state also activates only that ChatGPT app.

**Step 4: Verify and commit**

Run:

```bash
swift test --filter CodexThreadNavigatorTests
git add Sources/CodexNotch/Monitoring/FrontmostAppMonitor.swift Sources/CodexNotch/Navigation Tests
git commit -m "feat: detect Codex foreground and deep-link tasks"
```

Expected: URL unit tests pass; manually running `open "codex://threads/<real-id>"` opens the corresponding task.

### Task 7: Use a Pure Reducer to Determine Notch Presentation

**Files:**
- Create: `Sources/CodexNotch/State/NotchPresentationState.swift`
- Create: `Sources/CodexNotch/State/NotchPresentationReducer.swift`
- Create: `Tests/CodexNotchTests/NotchPresentationReducerTests.swift`

**Step 1: Write failing priority tests**

Must cover:

- Active task + non-ChatGPT frontmost → working.
- Active task + ChatGPT frontmost → still working.
- No active task + just completed → completed.
- Completion cue expired + ChatGPT frontmost → quota.
- Completion cue expired + another app frontmost → hidden.
- Hover + multiple tasks → expanded, with the most recently active task as primary.

```swift
enum NotchPresentationState: Equatable {
    case hidden
    case quotaCompact(UsageSnapshot?)
    case workingCompact(primary: SessionActivity, count: Int, usage: UsageSnapshot?)
    case completedCompact(SessionActivity)
    case expanded(ExpandedContent)
}
```

Run: `swift test --filter NotchPresentationReducerTests`

Expected: FAIL。

**Step 2: Implement state priority**

The reducer input must include an explicit `now`; tests must not depend directly on `Date.now`. The completion cue lasts 3 seconds; the coordinator produces a delayed foreground input for the 1.2-second delay after Codex leaves the foreground instead of putting that delay in the view.

**Step 3: Test and commit**

Run:

```bash
swift test --filter NotchPresentationReducerTests
git add Sources/CodexNotch/State Tests/CodexNotchTests/NotchPresentationReducerTests.swift
git commit -m "feat: define deterministic notch presentation states"
```

Expected: State priority and time boundaries all pass.

### Task 8: Implement Notch Geometry and a Nonactivating Panel

**Files:**
- Create: `Sources/CodexNotch/Window/NotchGeometry.swift`
- Create: `Sources/CodexNotch/Window/NotchPanel.swift`
- Create: `Sources/CodexNotch/Window/NotchWindowController.swift`
- Create: `Tests/CodexNotchTests/NotchGeometryTests.swift`

**Step 1: Write failing pure-geometry tests**

Use constructed screen frames, visible frames, and left/right auxiliary rects to test:

- The compact window is centered on the notch.
- Expansion stays within the screen's left and right boundaries.
- `.menuBarFallback` is returned when auxiliary rects are absent.

Run: `swift test --filter NotchGeometryTests`

Expected: FAIL。

**Step 2: Implement panel properties**

```swift
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

**Step 3: Connect geometry and controller**

The controller observes `NSApplication.didChangeScreenParametersNotification` and updates only the frame and SwiftUI root view when state changes. Set `ignoresMouseEvents = true` when hidden and false when compact or expanded.

**Step 4: Test and commit**

Run:

```bash
swift test --filter NotchGeometryTests
git add Sources/CodexNotch/Window Tests/CodexNotchTests/NotchGeometryTests.swift
git commit -m "feat: position a nonactivating panel around the notch"
```

Expected: Geometry tests pass and the fake-data demo does not steal keyboard focus.

### Task 9: Build the Compact and Expanded SwiftUI States

**Files:**
- Create: `Sources/CodexNotch/UI/NotchRootView.swift`
- Create: `Sources/CodexNotch/UI/WorkingCompactView.swift`
- Create: `Sources/CodexNotch/UI/QuotaCompactView.swift`
- Create: `Sources/CodexNotch/UI/CompletedCompactView.swift`
- Create: `Sources/CodexNotch/UI/ExpandedNotchView.swift`
- Create: `Sources/CodexNotch/UI/UsageWindowRow.swift`
- Create: `Sources/CodexNotch/UI/ActiveSessionRow.swift`
- Create: `Sources/CodexNotch/UI/NotchTheme.swift`

**Step 1: Create static preview data**

Prepare single-week-window, two-window, single-task, two-task, completed, and no-quota-error states. Preview data must not read real auth or rollout files.

**Step 2: Implement the compact layout**

Show the ChatGPT icon, “Codex working”, or the completed state with elapsed time on the left; show the most important quota window's remaining percentage on the right. Blend the central black area into the physical notch. Use monospaced digits to avoid countdown-width jitter.

**Step 3: Implement the expanded layout**

Hover enters expanded and collapses after a 300ms delay when the pointer leaves. Sort multiple tasks by recent activity; each row shows the leaf directory name, runtime, and navigation icon. The quota area renders only real windows.

**Step 4: Implement color and accessibility**

Quota used < 70% is green, 70–90% is orange, and > 90% is red; use system blue for running and system green for completed. Add accessibility labels to buttons and respect Reduce Motion.

**Step 5: Build and commit**

Run:

```bash
swift build
git add Sources/CodexNotch/UI
git commit -m "feat: add compact and expanded notch views"
```

Expected: The build succeeds and every preview renders.

### Task 10: Assemble the Coordinator, Refresh Cadence, and Completion Cue

**Files:**
- Create: `Sources/CodexNotch/App/AppCoordinator.swift`
- Create: `Sources/CodexNotch/State/AppStore.swift`
- Create: `Tests/CodexNotchTests/AppCoordinatorTests.swift`
- Modify: `Sources/CodexNotch/App/AppDelegate.swift`

**Step 1: Write failing scheduling tests**

Use a fake clock, fake usage client, and fake activity monitor to verify:

- One refresh at launch.
- Immediate refresh when Codex activates.
- Immediate refresh on `task_started`.
- Refresh every 60 seconds while frontmost or running.
- Stop the 60-second poll while fully hidden.
- Hide only 1.2 seconds after leaving ChatGPT.
- Show `task_complete` for 3 seconds.

Run: `swift test --filter AppCoordinatorTests`

Expected: FAIL。

**Step 2: Implement the main-thread store**

`AppStore` uses `@MainActor` and stores credentials state, usage snapshot, active sessions, recent completion, foreground, and hover. All asynchronous data enters the store first, then goes through the reducer; the UI does not access files or the network directly.

**Step 3: Implement coordinator lifetime**

Start the frontmost monitor, rollout monitor, and usage-refresh task; cancel observers, the FSEvent stream, and timers on stop. Deduplicate network refreshes so only one usage request can be active at a time.

**Step 4: Test and commit**

Run:

```bash
swift test --filter AppCoordinatorTests
swift test
git add Sources/CodexNotch/App Sources/CodexNotch/State Tests/CodexNotchTests/AppCoordinatorTests.swift
git commit -m "feat: coordinate quota and session activity"
```

Expected: All unit tests pass with no warnings about uncancelled asynchronous tasks.

### Task 11: Package the `.app`, Launch at Login, and Add Menu-Bar Fallback

**Files:**
- Create: `Resources/Info.plist`
- Create: `Sources/CodexNotch/MenuBar/MenuBarController.swift`
- Create: `Sources/CodexNotch/Settings/SettingsView.swift`
- Create: `Sources/CodexNotch/Settings/LoginItemController.swift`
- Create: `scripts/build-app.sh`
- Create: `Tests/CodexNotchTests/LoginItemControllerTests.swift`

**Step 1: Create Info.plist**

It must include:

```xml
<key>CFBundleIdentifier</key>
<string>com.david.codexnotch</string>
<key>CFBundleName</key>
<string>CodexNotch</string>
<key>CFBundleExecutable</key>
<string>CodexNotch</string>
<key>LSUIElement</key>
<true/>
<key>NSHighResolutionCapable</key>
<true/>
```

**Step 2: Implement the login-item controller**

Use `SMAppService.mainApp.register()` and `unregister()`; Settings shows the actual state returned by the system. Show an error on registration failure and do not retry repeatedly.

**Step 3: Implement the no-notch menu-bar fallback**

When geometry returns the fallback, hide the panel and create an `NSStatusItem`. The menu contains current quota, the active-task list, refresh, Settings, and Quit.

**Step 4: Create the build script**

The script runs a release build, copies the binary to `.build/CodexNotch.app/Contents/MacOS/`, copies Info.plist, and then applies ad-hoc signing. Later releases can use Developer ID signing, notarization, and `.dmg` packaging; the GitHub Release provides both `.app.zip` and source.

```bash
codesign --force --deep --sign - .build/CodexNotch.app
codesign --verify --deep --strict .build/CodexNotch.app
```

**Step 5: Build and commit**

Installation instructions for ordinary users contain only download, unzip, and drag into Applications; Swift, Xcode, and command-line tools are not required. Source contributors should use Xcode 15+ or an equivalent Swift 5.9+ toolchain.

Run:

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open .build/CodexNotch.app
git add Resources Sources/CodexNotch/MenuBar Sources/CodexNotch/Settings scripts Tests
git commit -m "feat: package CodexNotch as a login item app"
```

Expected: Signing verification succeeds, no Dock icon appears, and Settings can toggle launch at login. Ordinary users installing the release app do not need Swift, Xcode, or command-line tools.

### Task 12: Real-Environment Acceptance and Privacy Review

**Files:**
- Create: `docs/testing/manual-acceptance.md`
- Create: `README.md`

**Step 1: Run automated tests**

Run:

```bash
swift test
./scripts/build-app.sh
codesign --verify --deep --strict .build/CodexNotch.app
```

Expected: Tests pass and signing verification succeeds.

**Step 2: Execute the real-interaction matrix**

Record each item:

1. Codex quota appears while ChatGPT is frontmost and idle.
2. The notch hides 1.2 seconds after switching to another app.
3. The notch remains visible after starting a task and switching to another app.
4. With two tasks running, the list is complete and the primary task is the most recently active.
5. Clicking each task opens the correct Codex task.
6. Both completion and abort clear the running state.
7. The last quota remains after network loss and task monitoring is unaffected.
8. Position is correct in full screen, across multiple Spaces, on an external display, and after wake.
9. A no-notch display uses the menu-bar fallback.

**Step 3: Check logs and artifacts**

Run:

```bash
rg -n "access_token|Authorization|Bearer|chatgpt.com/backend-api/wham/usage" .build README.md docs Sources Tests
git status --short
```

Expected: Source may contain endpoint names, but build artifacts and documentation contain no real tokens, Authorization values, real responses, or message bodies.

**Step 4: Complete the README and commit**

The README documents system requirements, build, launch, login item, data sources, possible changes to the internal usage endpoint, privacy boundaries, and known limitations.

Run:

```bash
git add README.md docs/testing/manual-acceptance.md
git commit -m "docs: add build and acceptance guidance"
git status --short
```

Expected: The worktree is clean.

## Definition of Done

- When the current account has only a weekly window, the UI shows only weekly quota.
- The running Codex task remains visible after switching to another app.
- Primary-task selection and the expanded list are stable with multiple tasks.
- A click navigates precisely back to the corresponding Codex task.
- Accessibility permission, screen recording, hooks, and app-server are not required.
- Usage/API failures and rollout parsing failures remain isolated from each other.
- The full test suite, ad-hoc signing, and manual acceptance matrix pass.
