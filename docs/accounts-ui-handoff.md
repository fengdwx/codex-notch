# 账号切换 UI 交接说明

> 目的：把 CodexNotch 里已经做好的账号能力交接给交互/视觉设计，避免重做底层。
> 现状是「能用但不精致」，交互与排版都可以推翻重做。

## 1. 代码与运行状态

| 项 | 值 |
| --- | --- |
| 仓库 | `/Users/david/projects/codex-notch-accounts`（`~/projects/codex-notch` 的独立 worktree） |
| 分支 | `feat/accounts-isolation`，基于 `origin/main` v0.2.6 |
| 最新提交 | `b8a21b0 feat(accounts): show per-account 5h/7d quota in the notch list` |
| 已安装 | `/Applications/CodexNotch.app`（0.2.6，本地构建，已 ad-hoc 签名并运行） |
| 回归 | `swift test` 334 通过 / 2 跳过；`./scripts/verify.sh` 通过 |

改 UI 只需要碰 `Sources/CodexNotch/UI/` 和 `Window/NotchGeometry.swift` 里的两个高度常数，底层不用动。

## 2. 底层已经有的能力（可直接用）

`AccountsService.shared`（`ObservableObject`）：

```swift
@Published private(set) var accounts: [AccountProfile]
@Published private(set) var activeAccountID: UUID?
var activeAccount: AccountProfile? { get }
func switchTo(_ id: UUID) async throws        // 退出 Codex → 用该账号 home 重启
func refreshStaleQuotas(ttl: TimeInterval = 120) async
func refreshQuota(for id: UUID) async throws
func importSession(_ data: Data) throws -> AccountProfile
func exportSession(_ id: UUID) throws -> Data
func rename(_ id: UUID, to: String) throws
func updateNote(_ id: UUID, note: String) throws
func delete(_ id: UUID, removeHome: Bool = true) throws
func homeURL(for id: UUID) -> URL
```

`AccountProfile` 可用字段：

```swift
id: UUID
displayName: String          // 用户可改
email: String?
accountIdentifier: String?   // chatgpt_account_id
planType: String?            // "plus" / "pro"
note: String?
importedAt: Date
lastCheckedAt: Date?         // 决定额度是否过期
lastUsedAt: Date?
quota: AccountQuota?
```

`AccountQuota`：

```swift
primaryUsedPercent: Double?     // 5h（可能没有）
primaryResetsAt: Date?
secondaryUsedPercent: Double?   // 7d
secondaryResetsAt: Date?
planType: String?
checkedAt: Date?
```

注意：接口返回的是 **usedPercent**；展示时要算 `100 - used`。5h 窗口不是每个账号都有，可能为 `nil`。

## 3. 当前 UI（待重做）

位置：展开卡里，额度区下方、「最近对话」上方。代码在
`Sources/CodexNotch/UI/AccountSwitchList.swift`，插入点在
`Sources/CodexNotch/UI/NotchView.swift` 的 `ExpandedNotchView.detailContent`：

```swift
QuotaWindowsProgressView(...)

AccountSwitchList(service: .shared, language: language)

if !content.conversations.isEmpty { ... }
```

当前每行（高 34pt）：

```
(i) ioueva527  PLUS  ✓      5h 97%    7d 14%
    ioueva527@gmail.com      2:14      3d4h
```

- 20pt 圆形首字母头像
- 名称 + 套餐 + 当前账号绿勾
- 邮箱小字
- 右侧两列：`5h`/`7d` 剩余百分比 + 重置倒计时（7.5pt）
- 当前账号行有淡淡的 accent 底色
- **点行直接切换**（当前账号行点了无动作），切换中该行转圈、其他行禁用
- 展开时 `.task` 触发一次 `refreshStaleQuotas()`，超过 2 分钟才请求

高度由 `Window/NotchGeometry.swift` 决定：

```swift
static let accountListHeaderHeight: CGFloat = 20
static let accountRowHeight: CGFloat = 34

static func accountListHeight(accountCount: Int) -> CGFloat {
    guard accountCount > 1 else { return 0 }
    return 12 + accountListHeaderHeight + CGFloat(accountCount) * accountRowHeight
}
```

4 个账号 → 卡片增高 168pt；`NotchRuntimeCoordinator` 在计算 `expandedContentSize`/`quotaExpandedContentSize` 时会把它加进去，所以改行高必须同步改这两个常数，否则列表会被裁切。

## 4. 硬约束（设计时必须遵守）

- 卡片固定宽 `NotchExpandedLayout.width = 420`；展开卡高度按内容计算，最大不能超出屏幕可用高度。
- notch 面板是非激活 `NSPanel`，只响应鼠标；不能用依赖键盘、焦点、系统菜单的方案。
- 交互必须满足 `docs/agent-harness.md`：悬停只向下展开、收起后不再拦截鼠标、真机确认（自动化测试不能替代）。
- 账号切换是破坏性操作：会退出 Codex、中断正在跑的任务。设计上需要能防误触，但当前实现是「单击即切」（用户明确要一次点击）。
- 不能把 token 写日志或发网络；`auth.json` 只在本地 Vault（`0700/0600`）。
- 只有 1 个账号时列表应隐藏，不占高度。
- 改动涉及 contract `docs/contracts/behavior-contracts.yaml` 的 `ACCOUNTS-ISOLATION-064`（scope 含 `notch-account-entry`）与 decision `docs/decisions/011-per-account-codex-home.md`。

## 5. 已知的「丑」与可改点

- 行内字号 7.5–11.5pt 混排，重置倒计时在 Retina 下偏小。
- 头像圆、行底色、勾选都是通用 SwiftUI 样式，没有用 notch 自己的视觉语言；`NotchPalette` 目前是 `private`，需要时可以开放或换成本地色值。
- 行高 34pt × 4 + 标题，让卡片明显变高，「最近对话」被往下推。
- 没有展开/收起的过渡，没有 hover 高亮。
- 没有处理 >5 个账号（当前会全部列出，继续长高）。
- 切换失败只有控制台/行恢复，没有可见错误提示。

## 6. 数据与文件

```
~/Library/Application Support/CodexNotch/Accounts/
  accounts.json                     # {version, accounts[], activeAccountID}
  Vault/<uuid>.authdata             # auth.json 原样，0600
  Homes/<uuid>/codex/               # 每账号 CODEX_HOME
  Homes/<uuid>/userdata/            # 每账号 Electron profile
```

首次启动会从旧 `Codex Account Switcher` 的 `accounts.json` + `AuthVault` 自动导入，所以现有 4 个账号不需要重新登录。

## 7. 验证与回滚

```sh
cd ~/projects/codex-notch-accounts
swift test                 # 334 tests
./scripts/verify.sh        # 全量：contract、测试、构建、签名校验
```

真机检查项：列表是否被裁切、行高与字号、展开/收起是否顺畅、切换后额度/最近任务是否跟随新账号、`~/.codex/auth.json` 是否保持不变。

回滚：`~/Backups/` 下有替换前的 `CodexNotch-0.2.6-*.app`，拷回 `/Applications` 即可；账号数据独立于 app bundle，回滚不会丢。
