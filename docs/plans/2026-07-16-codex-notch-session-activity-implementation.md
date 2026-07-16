# CodexNotch Session Activity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 构建一个独立的 macOS 刘海应用，在 ChatGPT（原 Codex）前台时显示真实 Codex 额度，在任意应用前台时持续显示运行中的 Codex 任务，并可精确跳回对应任务。

**Architecture:** 使用 AppKit `NSPanel` 负责刘海窗口和屏幕定位，SwiftUI 负责紧凑态与展开态 UI。额度由本地 Codex 登录态请求 usage 接口，任务状态由 FSEvents 加增量 JSONL 解析获得，纯状态 reducer 决定最终展示。

**Tech Stack:** Swift 5.9+ 语言模式、macOS 14+、AppKit、SwiftUI、Foundation、CoreServices/FSEvents、ServiceManagement、Swift Package Manager、XCTest。

---

## 实施原则

- 项目根目录：`/Users/david/projects/tmp/codex-notch`。
- 独立应用，不依赖 Atoll、CodexIsland、CodexBar、CC Switch、hooks 或 app-server。
- 每个任务按“失败测试 → 最小实现 → 测试通过 → 提交”推进。
- 不提交 token、auth 文件、真实 rollout、完整 usage 响应或用户消息正文。
- 当前机器存在 Swift 编译器与 SDK 小版本不匹配，Task 0 未通过前不进入业务代码。发布给普通用户的是已构建的 `.app`，普通用户不需要安装 Swift 或 Xcode。

### Task 0: 固定工具链并建立隔离工作区

**Files:**
- Existing: `/Users/david/projects/tmp/codex-notch/docs/plans/2026-07-16-codex-notch-session-activity-design.md`
- Existing: `/Users/david/projects/tmp/codex-notch/docs/plans/2026-07-16-codex-notch-session-activity-implementation.md`
- Create: `/Users/david/projects/tmp/codex-notch/.gitignore`

**Step 1: 检查当前工具链**

Run:

```bash
cd /Users/david/projects/tmp/codex-notch
xcode-select -p
xcrun swift --version
xcrun --show-sdk-path
```

Expected: Swift 编译器可以读取当前 macOS SDK。当前已知环境可能报“SDK built with Swift 6.2.3, compiler is Swift 6.2.4”一类不匹配错误。

**Step 2: 切换到匹配的完整 Xcode**

如果 `/Applications/Xcode.app` 已安装：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
xcrun swift --version
```

Expected: 命令无 SDK compatibility error。若未安装完整 Xcode，本步骤是开发者构建源码前的前置条件；普通用户使用 release app 不受影响。

**Step 3: 创建忽略规则**

```gitignore
.build/
DerivedData/
*.xcuserstate
CodexNotch.app/
*.dSYM/
.DS_Store
```

**Step 4: 初始化仓库并提交规划文档**

Run:

```bash
cd /Users/david/projects/tmp/codex-notch
git init
git branch -M main
git add .gitignore docs/plans
git commit -m "docs: define CodexNotch v1"
```

Expected: 首次提交成功，工作树干净。

**Step 5: 创建实施 worktree**

Run:

```bash
mkdir -p /Users/david/projects/tmp/codex-notch-worktrees
git worktree add /Users/david/projects/tmp/codex-notch-worktrees/v1 -b feat/codex-notch-v1
```

Expected: 新工作区位于 `/Users/david/projects/tmp/codex-notch-worktrees/v1`。后续命令均在该目录执行。

### Task 1: 建立可测试的 Swift 应用骨架

**Files:**
- Create: `Package.swift`
- Create: `Sources/CodexNotch/App/CodexNotchApp.swift`
- Create: `Sources/CodexNotch/App/AppDelegate.swift`
- Create: `Tests/CodexNotchTests/SmokeTests.swift`

**Step 1: 写失败的 smoke test**

```swift
import XCTest
@testable import CodexNotch

final class SmokeTests: XCTestCase {
    func testApplicationIdentifierIsStable() {
        XCTAssertEqual(AppIdentity.bundleIdentifier, "com.david.codexnotch")
    }
}
```

**Step 2: 创建 `Package.swift` 并运行测试**

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

**Step 3: 添加最小应用入口**

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

`AppDelegate` 先只设置 `.accessory` activation policy。

**Step 4: 验证并提交**

Run:

```bash
swift test --filter SmokeTests
git add Package.swift Sources Tests
git commit -m "chore: bootstrap native CodexNotch app"
```

Expected: 1 test passed。

### Task 2: 定义额度模型与动态窗口分类

**Files:**
- Create: `Sources/CodexNotch/Models/UsageSnapshot.swift`
- Create: `Sources/CodexNotch/Usage/UsageWindowClassifier.swift`
- Create: `Tests/CodexNotchTests/UsageWindowClassifierTests.swift`

**Step 1: 写分类失败测试**

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

**Step 2: 实现最小模型与分类器**

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

分类规则：6–8 天归为 weekly，接近 1 天归为 daily，可整除小时的短窗口显示实际小时数，其余显示自定义时长。不得根据 primary/secondary 字段名分类。

**Step 3: 验证边界并提交**

再补 `usedPercent > 100`、负值、未知秒数测试；规范化为 0–100。

Run:

```bash
swift test --filter UsageWindowClassifierTests
git add Sources/CodexNotch/Models Sources/CodexNotch/Usage Tests/CodexNotchTests/UsageWindowClassifierTests.swift
git commit -m "feat: classify Codex usage windows by duration"
```

Expected: 所有额度分类测试通过。

### Task 3: 读取本地认证并请求额度

**Files:**
- Create: `Sources/CodexNotch/Usage/CodexAuthReader.swift`
- Create: `Sources/CodexNotch/Usage/CodexUsageClient.swift`
- Create: `Sources/CodexNotch/Usage/UsageResponseDTO.swift`
- Create: `Tests/CodexNotchTests/CodexAuthReaderTests.swift`
- Create: `Tests/CodexNotchTests/CodexUsageClientTests.swift`
- Create: `Tests/Fixtures/auth-valid.json`
- Create: `Tests/Fixtures/usage-weekly-only.json`
- Create: `Tests/Fixtures/usage-multiple-windows.json`

**Step 1: 写 auth 和响应映射失败测试**

测试必须覆盖：

- 从临时 fixture 读取 access token 与 account ID。
- `CODEX_HOME` 覆盖默认目录。
- 只有 604800 秒窗口时只生成一张 weekly 卡。
- secondary 缺失时不报错。
- 401 映射为 `reauthenticationRequired`。

Run: `swift test --filter CodexAuthReaderTests && swift test --filter CodexUsageClientTests`

Expected: FAIL because reader and client do not exist。

**Step 2: 实现认证读取边界**

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

**Step 3: 实现可注入 URLSession 的 usage client**

请求固定为 `GET https://chatgpt.com/backend-api/wham/usage`，设置 `Authorization: Bearer ...`；存在 account ID 时设置 `ChatGPT-Account-Id`。DTO 所有非关键字段可选，解析 primary 和 secondary 时统一交给 `UsageWindowClassifier`。

禁止记录 request headers 和 response body。client 返回 `UsageSnapshot` 或结构化错误，不直接修改 UI。

**Step 4: 测试与提交**

Run:

```bash
swift test --filter CodexAuthReaderTests
swift test --filter CodexUsageClientTests
git add Sources/CodexNotch/Usage Tests
git commit -m "feat: fetch Codex quota from local login"
```

Expected: fixture 测试通过，测试输出不含 fixture token。

### Task 4: 解析 rollout JSONL 事件

**Files:**
- Create: `Sources/CodexNotch/Models/SessionActivity.swift`
- Create: `Sources/CodexNotch/Monitoring/RolloutEventParser.swift`
- Create: `Tests/CodexNotchTests/RolloutEventParserTests.swift`
- Create: `Tests/Fixtures/rollout-start-complete.jsonl`
- Create: `Tests/Fixtures/rollout-aborted.jsonl`
- Create: `Tests/Fixtures/rollout-malformed-line.jsonl`

**Step 1: 写事件序列失败测试**

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

**Step 2: 实现窄字段解析**

只解码顶层 `timestamp`、`type` 和 payload 中的 `id`、`type`、`turn_id`、`cwd`、`originator`。忽略 message content 和其他 response items。

```swift
enum RolloutEventKind: Equatable, Sendable {
    case sessionMeta(threadID: String, cwd: String?, originator: String?)
    case taskStarted(turnID: String?)
    case taskCompleted(turnID: String?)
    case turnAborted(turnID: String?)
}
```

坏行返回可忽略的 parse issue，不能 throw 终止整个文件。终止事件缺少 turn ID 时，结束该 rollout 当前的活动 turn。

**Step 3: 验证并提交**

Run:

```bash
swift test --filter RolloutEventParserTests
git add Sources/CodexNotch/Models/SessionActivity.swift Sources/CodexNotch/Monitoring Tests
git commit -m "feat: parse Codex rollout activity events"
```

Expected: started、complete、aborted、坏行恢复全部通过。

### Task 5: 增量读取文件并聚合多任务状态

**Files:**
- Create: `Sources/CodexNotch/Monitoring/IncrementalJSONLReader.swift`
- Create: `Sources/CodexNotch/Monitoring/ActiveSessionStore.swift`
- Create: `Sources/CodexNotch/Monitoring/RolloutActivityMonitor.swift`
- Create: `Sources/CodexNotch/Monitoring/FSEventChangeSource.swift`
- Create: `Tests/CodexNotchTests/IncrementalJSONLReaderTests.swift`
- Create: `Tests/CodexNotchTests/ActiveSessionStoreTests.swift`

**Step 1: 写增量和多任务失败测试**

覆盖以下行为：

- 第二次读取只返回 append 的新行。
- 文件长度小于旧 offset 时视为截断并从头读取。
- 两个活动任务按 `lastActivityAt` 倒序。
- complete 只移除对应任务。
- 冷启动时 6 小时无更新的 unmatched start 被清理。

Run: `swift test --filter IncrementalJSONLReaderTests && swift test --filter ActiveSessionStoreTests`

Expected: FAIL。

**Step 2: 实现可测试的 offset reader**

```swift
struct FileCursor: Equatable, Sendable {
    var offset: UInt64 = 0
    var remainder = Data()
}

protocol IncrementalReading: Sendable {
    func readNewLines(at url: URL, cursor: inout FileCursor) throws -> [Data]
}
```

只把以换行结尾的完整记录交给 parser；末尾半行留在 `remainder` 等下次 append。

**Step 3: 实现活动任务 store**

`ActiveSessionStore` 使用 actor 串行化状态。每个 rollout 维护 thread metadata 和当前 turn。公开快照为排序后的 `[SessionActivity]`，主任务永远是第一项。

**Step 4: 接入 FSEvents**

FSEvents 只负责通知“哪些路径可能变化”；实际读取仍经过 offset reader。启动扫描范围限定为 sessions 下最近 24 小时修改的 `.jsonl`。变化回调切回 actor，避免并发修改 cursors。

**Step 5: 测试与提交**

Run:

```bash
swift test --filter IncrementalJSONLReaderTests
swift test --filter ActiveSessionStoreTests
git add Sources/CodexNotch/Monitoring Tests/CodexNotchTests
git commit -m "feat: monitor active Codex sessions incrementally"
```

Expected: 多文件、截断、半行、过期清理测试全部通过。

### Task 6: 监听 ChatGPT 前台状态并实现 Codex 任务深链

**Files:**
- Create: `Sources/CodexNotch/Monitoring/FrontmostAppMonitor.swift`
- Create: `Sources/CodexNotch/Navigation/CodexThreadNavigator.swift`
- Create: `Tests/CodexNotchTests/CodexThreadNavigatorTests.swift`

**Step 1: 写深链失败测试**

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

**Step 2: 实现 workspace 监听**

启动时读取 `NSWorkspace.shared.frontmostApplication`，随后监听 `NSWorkspace.didActivateApplicationNotification`。目标是现在承载 Codex 任务的 ChatGPT，其 bundle ID 仍为 `com.openai.codex`。不能依赖显示名或安装路径，也不能把 ChatGPT Classic 误判为目标应用。

**Step 3: 实现导航降级**

有效 thread ID 用 `NSWorkspace.shared.open(codexURL)`；打开返回 false 时，使用 `NSWorkspace.shared.openApplication` 激活 bundle ID 为 `com.openai.codex` 的 ChatGPT。无活动任务时点击紧凑额度态也只激活该 ChatGPT 应用。

**Step 4: 验证并提交**

Run:

```bash
swift test --filter CodexThreadNavigatorTests
git add Sources/CodexNotch/Monitoring/FrontmostAppMonitor.swift Sources/CodexNotch/Navigation Tests
git commit -m "feat: detect Codex foreground and deep-link tasks"
```

Expected: URL 单测通过；手工 `open "codex://threads/<真实ID>"` 能跳到对应任务。

### Task 7: 用纯 reducer 决定刘海展示状态

**Files:**
- Create: `Sources/CodexNotch/State/NotchPresentationState.swift`
- Create: `Sources/CodexNotch/State/NotchPresentationReducer.swift`
- Create: `Tests/CodexNotchTests/NotchPresentationReducerTests.swift`

**Step 1: 写优先级失败测试**

必须覆盖：

- 活动任务 + 非 ChatGPT 前台 → working。
- 活动任务 + ChatGPT 前台 → 仍然 working。
- 无活动任务 + 刚完成 → completed。
- 完成提示过期 + ChatGPT 前台 → quota。
- 完成提示过期 + 其他应用 → hidden。
- hover + 多任务 → expanded，主任务为最近活跃。

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

**Step 2: 实现状态优先级**

reducer 的输入必须包含显式 `now`，测试不能直接依赖 `Date.now`。完成提示持续 3 秒；Codex 离开前台的 1.2 秒延迟由 coordinator 产生一个延迟后的 foreground 输入，不写进视图。

**Step 3: 测试与提交**

Run:

```bash
swift test --filter NotchPresentationReducerTests
git add Sources/CodexNotch/State Tests/CodexNotchTests/NotchPresentationReducerTests.swift
git commit -m "feat: define deterministic notch presentation states"
```

Expected: 状态优先级和时间边界全部通过。

### Task 8: 实现刘海几何计算与非激活面板

**Files:**
- Create: `Sources/CodexNotch/Window/NotchGeometry.swift`
- Create: `Sources/CodexNotch/Window/NotchPanel.swift`
- Create: `Sources/CodexNotch/Window/NotchWindowController.swift`
- Create: `Tests/CodexNotchTests/NotchGeometryTests.swift`

**Step 1: 写纯几何失败测试**

用人工构造的 screen frame、visible frame、左右 auxiliary rect 测试：

- 紧凑窗以刘海中心为轴。
- 展开后不超出屏幕左右边界。
- 没有 auxiliary rect 时返回 `.menuBarFallback`。

Run: `swift test --filter NotchGeometryTests`

Expected: FAIL。

**Step 2: 实现面板属性**

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

**Step 3: 连接 geometry 与 controller**

controller 监听 `NSApplication.didChangeScreenParametersNotification`，状态变化时只更新 frame 和 SwiftUI root view。hidden 时 `ignoresMouseEvents = true`；compact/expanded 时为 false。

**Step 4: 测试与提交**

Run:

```bash
swift test --filter NotchGeometryTests
git add Sources/CodexNotch/Window Tests/CodexNotchTests/NotchGeometryTests.swift
git commit -m "feat: position a nonactivating panel around the notch"
```

Expected: 几何测试通过，假数据 demo 不抢键盘焦点。

### Task 9: 构建紧凑态与展开态 SwiftUI

**Files:**
- Create: `Sources/CodexNotch/UI/NotchRootView.swift`
- Create: `Sources/CodexNotch/UI/WorkingCompactView.swift`
- Create: `Sources/CodexNotch/UI/QuotaCompactView.swift`
- Create: `Sources/CodexNotch/UI/CompletedCompactView.swift`
- Create: `Sources/CodexNotch/UI/ExpandedNotchView.swift`
- Create: `Sources/CodexNotch/UI/UsageWindowRow.swift`
- Create: `Sources/CodexNotch/UI/ActiveSessionRow.swift`
- Create: `Sources/CodexNotch/UI/NotchTheme.swift`

**Step 1: 建立静态 preview 数据**

准备单周窗口、双窗口、单任务、双任务、完成态和无额度错误态。preview 数据不得读取真实 auth 或 rollout。

**Step 2: 实现紧凑布局**

左侧显示 ChatGPT 图标、“Codex 工作中”或完成状态及 elapsed；右侧显示最重要额度窗口的剩余百分比。中间黑色区域与物理刘海融为一体。使用 monospaced digit 避免倒计时宽度抖动。

**Step 3: 实现展开布局**

hover 进入 expanded，离开后延迟 300ms 收起。多任务按最近活动排序，每行显示目录末级名、运行时长和跳转图标；额度区只渲染真实窗口。

**Step 4: 实现颜色和可访问性**

额度 used < 70% 为绿、70–90% 为橙、> 90% 为红；运行态使用系统蓝，完成态使用系统绿。为按钮添加 accessibility label，尊重 Reduce Motion。

**Step 5: 编译与提交**

Run:

```bash
swift build
git add Sources/CodexNotch/UI
git commit -m "feat: add compact and expanded notch views"
```

Expected: build succeeded，所有 preview 可渲染。

### Task 10: 组装 coordinator、刷新节奏和完成提示

**Files:**
- Create: `Sources/CodexNotch/App/AppCoordinator.swift`
- Create: `Sources/CodexNotch/State/AppStore.swift`
- Create: `Tests/CodexNotchTests/AppCoordinatorTests.swift`
- Modify: `Sources/CodexNotch/App/AppDelegate.swift`

**Step 1: 写调度失败测试**

使用 fake clock、fake usage client、fake activity monitor 验证：

- 启动刷新一次。
- Codex 激活时立即刷新。
- task_started 时立即刷新。
- 前台或运行中每 60 秒刷新。
- 完全隐藏时停止 60 秒轮询。
- 离开 ChatGPT 1.2 秒后才隐藏。
- task_complete 展示 3 秒。

Run: `swift test --filter AppCoordinatorTests`

Expected: FAIL。

**Step 2: 实现主线程 store**

`AppStore` 使用 `@MainActor`，保存 credentials 状态、usage snapshot、active sessions、recent completion、foreground 和 hover。所有异步数据先进入 store，再调用 reducer，UI 不直接访问文件或网络。

**Step 3: 实现 coordinator 生命周期**

启动 frontmost monitor、rollout monitor 和 usage refresh task；停止时取消 observers、FSEvent stream 和 timer。网络刷新必须去重，同一时刻只允许一个 usage 请求。

**Step 4: 测试与提交**

Run:

```bash
swift test --filter AppCoordinatorTests
swift test
git add Sources/CodexNotch/App Sources/CodexNotch/State Tests/CodexNotchTests/AppCoordinatorTests.swift
git commit -m "feat: coordinate quota and session activity"
```

Expected: 全量单测通过，无未取消异步任务警告。

### Task 11: 打包 `.app`、登录时启动和菜单栏降级

**Files:**
- Create: `Resources/Info.plist`
- Create: `Sources/CodexNotch/MenuBar/MenuBarController.swift`
- Create: `Sources/CodexNotch/Settings/SettingsView.swift`
- Create: `Sources/CodexNotch/Settings/LoginItemController.swift`
- Create: `scripts/build-app.sh`
- Create: `Tests/CodexNotchTests/LoginItemControllerTests.swift`

**Step 1: 创建 Info.plist**

必须包含：

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

**Step 2: 实现登录项控制器**

用 `SMAppService.mainApp.register()` 和 `unregister()`；设置页显示系统返回的真实状态。注册失败显示错误，不反复重试。

**Step 3: 实现无刘海菜单栏降级**

当 geometry 返回 fallback 时隐藏 panel，创建 `NSStatusItem`。菜单内容包含当前额度、活动任务列表、刷新、设置和退出。

**Step 4: 创建构建脚本**

脚本执行 release build，把二进制复制到 `.build/CodexNotch.app/Contents/MacOS/`，复制 Info.plist，最后执行 ad-hoc 签名。后续发布时再用 Developer ID 签名、公证并压缩为 `.dmg`；GitHub Release 同时提供 `.app.zip` 和源码。

```bash
codesign --force --deep --sign - .build/CodexNotch.app
codesign --verify --deep --strict .build/CodexNotch.app
```

**Step 5: 构建与提交**

普通用户的安装说明只包含下载、解压、拖入 Applications，不要求 Swift、Xcode 或命令行工具。源码贡献者说明使用 Xcode 15+ 或等价的 Swift 5.9+ 工具链。

Run:

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open .build/CodexNotch.app
git add Resources Sources/CodexNotch/MenuBar Sources/CodexNotch/Settings scripts Tests
git commit -m "feat: package CodexNotch as a login item app"
```

Expected: 签名验证成功，Dock 不出现图标，设置可开关登录时启动。普通用户安装 release app 时不需要 Swift、Xcode 或命令行工具。

### Task 12: 真实环境验收与隐私检查

**Files:**
- Create: `docs/testing/manual-acceptance.md`
- Create: `README.md`

**Step 1: 运行自动化测试**

Run:

```bash
swift test
./scripts/build-app.sh
codesign --verify --deep --strict .build/CodexNotch.app
```

Expected: tests passed，签名验证通过。

**Step 2: 执行真实交互矩阵**

逐项记录：

1. ChatGPT 前台空闲时显示 Codex 额度。
2. 切到其他应用 1.2 秒后隐藏。
3. 开始任务后切到其他应用仍常驻。
4. 两个任务同时运行时列表完整，主任务为最近活跃。
5. 点击每个任务跳到正确 Codex 任务。
6. 完成与 aborted 都清除运行态。
7. 断网后保留最后额度，任务监听不受影响。
8. 全屏、多个 Space、外接屏、睡眠唤醒位置正确。
9. 无刘海屏使用菜单栏降级。

**Step 3: 检查日志与产物**

Run:

```bash
rg -n "access_token|Authorization|Bearer|chatgpt.com/backend-api/wham/usage" .build README.md docs Sources Tests
git status --short
```

Expected: 源码可以包含 endpoint 名称，但构建产物和文档不包含真实 token、Authorization 值、真实响应或消息正文。

**Step 4: 完善 README 并提交**

README 说明系统要求、构建、启动、登录项、数据来源、内部 usage 接口可能变化、隐私边界与已知限制。

Run:

```bash
git add README.md docs/testing/manual-acceptance.md
git commit -m "docs: add build and acceptance guidance"
git status --short
```

Expected: 工作树干净。

## 完成定义

- 当前账号只有周额度时，界面只展示周额度。
- Codex 任务运行时，切到其他应用仍持续显示。
- 多任务时主任务选择和展开列表稳定。
- 点击能精确跳回对应 Codex 任务。
- 不需要辅助功能、屏幕录制、hooks 或 app-server。
- usage/API 故障与 rollout 解析故障彼此隔离。
- 全量测试、ad-hoc 签名和手工验收矩阵通过。
