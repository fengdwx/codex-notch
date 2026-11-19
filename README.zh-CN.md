<div align="center">

<img src="Resources/AppIcon.svg" width="180" alt="CodexNotch 应用图标">

# CodexNotch

**把周额度、5 小时明细、精确重置倒计时、实时任务状态与同工作区多账号切换，固定在 MacBook 刘海旁。**

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111111?logo=apple)](https://github.com/fengdwx/codex-notch/releases/latest)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)](Package.swift)
[![Latest release](https://img.shields.io/github/v/release/fengdwx/codex-notch?label=下载最新版&color=2ea44f)](https://github.com/fengdwx/codex-notch/releases/latest)
[![MIT License](https://img.shields.io/badge/License-MIT-4c8bf5)](LICENSE)
[![LINUX DO](https://img.shields.io/badge/LINUX-DO-FFB003.svg)](https://linux.do)

[**下载最新版**](https://github.com/fengdwx/codex-notch/releases/latest) · [**观看 1080p 演示视频**](docs/assets/codex-notch-demo-zh.mp4) · [**v2.1.0 更新说明**](docs/releases/2.1.0.md) · [English](README.md)

</div>

[![CodexNotch v2.1.0 中文产品演示](docs/assets/codex-notch-demo-zh-animated.gif)](docs/assets/codex-notch-demo-zh.mp4)

<p align="center"><sub>v2.1.0 真实界面演示（全脱敏示例数据）：刘海实时额度与任务状态、悬停对比备用账号并共用 <code>~/.codex</code> 切号、外接屏悬浮岛，以及全新 macOS 设置界面。</sub></p>

---

## 一眼看懂

CodexNotch 是一款独立的原生 macOS 应用，不依赖任何第三方刘海宿主。无论你在 IDE、浏览器还是终端里工作，ChatGPT/Codex 额度与任务状态都会常驻在物理刘海旁（无刘海或外接屏则以**外接屏悬浮岛**居中展示）。

| 你关心的 | CodexNotch 如何解决 |
| --- | --- |
| **额度常驻可见** | 右侧固定展示周额度（顺时针圆环或波浪球）；物理刘海且返回 5 小时额度时左侧显示 5h，否则展示选定的状态图标（`Codex` / `ChatGPT` / `关闭`）。 |
| **精确重置与机会** | 悬停展开查看 `5h` 与 `7d` 进度条、具体重置时间、秒级倒计时，以及可手动确认的「使用重置」机会到期明细。 |
| **任务脉搏与跳转** | 清晰区分运行中、空闲与约 5 秒绿色完成对勾；点击展开卡内任意进行中或近期对话，直接跳回 `codex://threads/<thread-id>`。 |
| **同区多账号切换** | 将多个账号安全保存在本机 `0700`/`0600` 保险库，悬停备用账号即可无跳变实时预览 `5h + 7d` 余量，共用同一份 `~/.codex` 项目与会话池。 |
| **轻量可控** | 支持全局快捷键 `⌥⌘N` 随时显隐、原生 macOS 设置窗（`Cmd+,`）实时预览与 Sparkle Ed25519 签名更新。 |

---

## 核心功能

### 1. 刘海与外接屏悬浮岛

- **刘海屏模式**：左右指示器严格锚定在 `24pt` 安全区容器内，避开物理摄像头遮挡；悬停时在预分配透明画布内纯粹向下平滑展开，收起后立即让出鼠标命中区域。
- **外接屏 / 无刘海模式（外接屏悬浮岛）**：在屏幕顶部居中显示药丸悬浮岛，支持 4 种中间样式，可在 **设置 → 外接屏悬浮岛** 中交互预览：
  - **个人签名**：运行时节奏条跳动并伴随文字微光（支持最多 12 个字符的自定义文字）。
  - **轨道签名**：运行时圆点沿文字旁圆环转动，空闲时保持静态圆环与短横。
  - **任务计时**：运行时显示当前任务已耗时（`MM:SS` / `H:MM:SS`）。
  - **极简光带**：运行时单条光带流动，空闲时收短变淡，完成时短暂亮起绿勾。
- **准确的窗口与色彩语义**：根据接口 `limit_window_seconds` 动态识别窗口周期，避免仅有 7 天额度的套餐被误标成 5 小时窗口；颜色按剩余比例呈现健康绿（`> 20%`）、预警黄（`11–20%`）、紧急红（`<= 10%`）或无数据灰。

### 2. 共用 `~/.codex` 的安全多账号切换

不再为每个账号复制动辄数 GB 的隔离 `CODEX_HOME`，所有账号共用同一套本地项目列表与对话记录：

1. **三种干净的添加方式**（**设置 → 账号**）：
   - **+ 网页登录**：通过独立隔离的 `app-server` 沙盒完成 OAuth 授权，无需退出当前正在使用的 Codex 客户端。
   - **导入 `auth.json` 文件**：直接导入已保存的凭据文件。
   - **导入当前本地登录**：收编当前 `~/.codex/auth.json` 登录状态。
2. **退出优先回存 + 防冲突 + 自动回滚**：
   - 切号前先非阻塞检查是否有外部独立 Codex CLI/IDE 进程正在占用 `auth.json`，避免静默覆盖冲突。
   - 先优雅退出 Codex 让其刷新落盘最新 token，再按新鲜度（`last_refresh` 与 JWT `iat`/`exp`）权威写回 Vault，防止旧令牌覆盖新令牌。
   - 原子写入目标 `auth.json` 并同步 `.codex-global-state.json` 项目与新建对话上下文；若重启失败则自动恢复原凭据并拉回原会话。
3. **按需账号抽屉与实时预览**：
   - 默认收起为 `36pt` 紧凑锚点栏（展示 `K/N` 可用账号概览与切号完成提示）。
   - 点击展开垂直抽屉，5 个及以上账号时自动提供「余量优先 / 最近使用 / 全部」筛选与卡片滚动。
   - 悬停备用账号卡片即可在顶部实时预览其 `5h + 7d` 额度而卡片高度零跳变；`401` 失效账号标注「需重新登录」，`402`/`403` 标注「不可用」并自动排除在健康备用数之外。

---

## 安装指南

支持 **Apple Silicon** 与 **macOS 14 Sonoma 及以上系统**（使用发行包无需安装 Xcode 或 Swift）。

1. 前往 [**GitHub Releases**](https://github.com/fengdwx/codex-notch/releases/latest) 下载最新版 `.dmg`（推荐）或 `.zip`。
2. 将 `CodexNotch.app` 拖入 `/Applications`（应用程序文件夹）。
3. 确保本机已登录使用过 ChatGPT / Codex，再启动 **CodexNotch**。
   - 当前公开包采用 ad-hoc 签名（暂未申请 Apple Developer ID 公证），首次打开如弹出系统提示，请在 **系统设置 → 隐私与安全性** 点击「仍要打开」，或右键应用选择「打开」。
   - 默认读取 `~/.codex`，若使用自定义目录可在启动前通过环境变量 `CODEX_HOME` 指定。

---

## 快捷操作与设置页面

使用全局快捷键 **`⌥⌘N`**、右键刘海/悬浮岛，或点击展开卡片右下角的显隐胶囊与设置按钮（**`Cmd+,`**）即可操作：

| 分页 / 入口 | 包含控制项 |
| --- | --- |
| **通用** | 登录时启动 · 中 / 英文界面实时切换（默认英文） · 展开卡最近任务数量（`隐藏`、`1`、`2`、`3`） |
| **外观** | 物理刘海顶部实时预览 · 右侧额度样式（`顺时针圆环` / `波浪球`） · 左侧显示（`Codex` / `ChatGPT` / `关闭`） · 动画效果开关（并配合系统「减少动态效果」） |
| **外接屏悬浮岛** | 无刘海/外接屏顶部实时预览（`运行中` / `空闲` / `完成提示`） · 中间样式与 12 字以内自定义签名 |
| **账号** | 右上角 **刷新全部** 与 **+ 网页登录** · `auth.json` / 本地登录导入 · 卡片行内改名与本机备注、单号刷新、在 Finder 中定位 `~/.codex`、导出、两步确认删除及切号/重启 |
| **侧边栏左下角** | **检查更新**（Sparkle Ed25519 验签手动更新） · **GitHub** 仓库直达 |

> 隐藏顶部显示后，再次按 **`⌥⌘N`** 或将鼠标移到物理刘海上缘热区即可重新呼出。

---

## 隐私与设计边界

- **凭据不出本机**：账号文件保存在 `~/Library/Application Support/CodexNotch/Accounts/Vault`（目录权限 `0700`、文件权限 `0600`），不上传云端、不写入普通日志。
- **只读与显式确认**：额度与重置次数查询仅调用只读接口；唯有当你主动点击并确认「使用重置」时才会兑换次数。
- **最小化本地日志读取**：任务运行状态仅解析 `CODEX_HOME/sessions` 下的 rollout JSONL；对话标题读取 `session_index.jsonl` 与只读 `state_5.sqlite` 标题列，不收集或缓存正文内容。
- **零遥测**：检查更新仅向 GitHub 拉取静态 `appcast.xml`，不回传任何凭据、配额或使用习惯。
- **明确不做的事**：仅监听当前版 Codex（`com.openai.codex`，不含已淘汰的 ChatGPT Classic `com.openai.chatgpt.classic`）；不会静默强杀后台任务，不做 API 费用账单估算，不做云同步或静默后台更新。

---

<details>
<summary><strong>从源码构建与验证</strong></summary>

需要 Xcode 16 或更新版本，构建目标为 macOS 14.0+（GitHub CI 在 `macos-15` + Xcode `16.2` 上验证）：

```sh
swift test
./scripts/verify.sh
./scripts/build_app.sh
open dist/CodexNotch.app
```

生成带 Sparkle 签名的分发制品与 `dist/appcast.xml`（需发布者钥匙串 Ed25519 私钥，流程见 [docs/updating.md](docs/updating.md) 与 [docs/agent-harness.md](docs/agent-harness.md)）：

```sh
RUN_TESTS=0 ./scripts/release.sh
```

本地调试如需跳过代码签名：

```sh
SIGN_IDENTITY=none ./scripts/build_app.sh
```

</details>

---

## 致谢与参考

CodexNotch 是一款完全独立的原生 macOS 应用，不依赖任何第三方刘海宿主框架；谨向在开发过程中提供技术启发、基础组件或交流反馈的开源项目与社区表示感谢：

- [**Atoll**](https://github.com/Ebullioscopic/Atoll) — 启发了 CodexNotch 的固定透明画布分层、阻尼弹簧过渡与刘海悬停交互架构（参见 [ADR 001](docs/decisions/001-fixed-canvas-notch-motion.md)、[ADR 035](docs/decisions/035-spring-card-transitions.md)、[ADR 045](docs/decisions/045-hover-response-and-shadow.md)）。
- [**Codex Account Switcher (`pengshengege/CodexAccountSwitcher`)**](https://github.com/pengshengege/CodexAccountSwitcher) — 启发了 CodexNotch 的独立 `CODEX_HOME` 沙盒 OAuth 登录、`0700`/`0600` 本地凭据保险库、账号本地备注，以及切换前先归档再原子替换 `~/.codex/auth.json` 并重启 Codex 的切号设计。
- [**Sparkle**](https://github.com/sparkle-project/Sparkle) — 提供基于 Ed25519 签名验证的应用内更新机制（[官方文档](https://sparkle-project.org/documentation/)）。
- **macOS 与 Codex 开源生态** — 感谢围绕本地 AI 配额监测与开发者体验做出探索的同类项目（如 [**CodexBar**](https://github.com/steipete/CodexBar)、[**CC Switch**](https://github.com/farion1231/cc-switch) 等），以及 [LINUX DO](https://linux.do) 社区提供的反馈与真机建议。

---

## 开源许可

基于 [MIT License](LICENSE) 开源。如果 CodexNotch 帮你把额度和任务状态稳稳留在眼前，欢迎点一颗 Star。
