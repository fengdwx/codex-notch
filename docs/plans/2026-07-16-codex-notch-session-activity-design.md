# CodexNotch 额度与任务状态设计

## 1. 产品结论

CodexNotch 是一个独立的 macOS 原生小程序，不是 Atoll、CodexIsland、CC Switch 或 CodexBar 的插件。它只做两件事：在刘海旁显示 ChatGPT 中 Codex 功能的额度；当 Codex 任务正在运行时，无论当前位于哪个应用，都持续显示任务状态并允许一键跳回对应任务。

macOS 没有公开的 Dynamic Island 插件接口，因此采用 AppKit 的无边框 `NSPanel` 模拟刘海岛。窗口根据 `NSScreen` 的安全区定位，使用非激活面板，不抢当前应用的键盘焦点。SwiftUI 只负责内容与动画，窗口生命周期、层级和点击行为交给 AppKit。

V1 不依赖 hooks、Codex app-server 或第三方后台进程。额度来自 Codex 本地登录态与 usage 接口；任务活动来自 Codex 已经写入的本地 rollout JSONL 文件。两条数据链路互相独立：额度接口失败不影响任务提醒，任务监听失败也不清空最后一次成功额度。

## 2. 核心交互

刘海状态按以下优先级决策：

1. 存在运行中任务：始终显示工作状态，优先级最高。
2. 最近任务刚完成：显示约 3 秒完成提示；如果 ChatGPT 在前台，随后回到额度状态。
3. ChatGPT（原 Codex，bundle ID 为 `com.openai.codex`）是前台应用且没有运行中任务：显示额度概览。
4. 其他情况：完全收起到物理刘海。

紧凑态参考音乐播放控件，围在刘海两侧：

```text
[ChatGPT 图标  Codex 工作中  02:18]  [周额度剩余 95%]
```

存在多个运行中任务时，最近收到活动事件的任务是主任务。紧凑态点击直接跳转主任务；鼠标悬停展开卡片，列出全部运行中任务，每一行都可跳转到对应 Codex 任务。展开顺序按最近活动时间倒序。

没有运行中任务时，紧凑态点击激活 ChatGPT；悬停展开额度详情。离开 ChatGPT 前台后延迟约 1.2 秒收起，避免快速切换应用时闪烁。完成态使用绿色短提示；运行态只使用轻微脉冲，不做宠物、音频或复杂动效。

## 3. 任务活动数据流

监听目录为 `CODEX_HOME/sessions`，默认 `~/.codex/sessions`。启动时扫描最近修改的 rollout 文件，之后用 FSEvents 获取目录变化，再按文件偏移量增量读取新增 JSONL，不重复解析整个历史。

关键事件映射如下：

| JSONL 内容 | 状态变化 |
|---|---|
| `session_meta.payload.id` | 保存任务 ID，用于深链跳转 |
| `event_msg.payload.type = task_started` | 将对应 turn 标记为运行中 |
| `event_msg.payload.type = task_complete` | 将对应 turn 标记为完成 |
| `event_msg.payload.type = turn_aborted` | 将对应 turn 标记为终止 |

每个活动记录保存 `threadID`、`turnID`、`cwd`、`originator`、开始时间、最后活动时间和 rollout 路径。主任务按最后活动时间选择，而不是按文件名选择。

应用异常退出可能造成只有 `task_started`、没有终止事件。V1 在冷启动恢复时只扫描最近 24 小时修改的文件；未结束任务若 6 小时没有任何文件更新，标记为过期并隐藏。这个阈值只是故障保护，不作为普通任务完成判断。解析坏行时跳过该行并继续监听，不能因为一条不完整 JSON 导致整个监控停止。

## 4. 精确跳转

当前 Codex 桌面应用注册了 `codex` URL scheme。任务点击使用：

```text
codex://threads/<thread-id>
```

通过 `NSWorkspace.shared.open` 打开。若任务 ID 缺失或 URL 无法打开，则降级为按 bundle identifier `com.openai.codex` 激活 ChatGPT，而不是静默失败。当前应用虽然显示名已改为 ChatGPT，但 bundle ID 和 `codex://` scheme 仍保留原值；ChatGPT Classic 不属于监听目标。窗口本身使用 `.nonactivatingPanel`，点击不会先把 CodexNotch 变成前台应用。

展开态的任务行显示项目目录末级名称、运行时长和状态，不读取或展示用户消息正文，减少隐私暴露。V1 不提供终止任务按钮，因为那会引入控制 Codex 运行时的额外风险和依赖。

## 5. 额度数据流

认证文件从 `CODEX_HOME/auth.json` 读取，默认 `~/.codex/auth.json`。只解析 `tokens.access_token` 和 `tokens.account_id`，令牌仅保存在进程内存，不写缓存、不出现在日志。请求 `https://chatgpt.com/backend-api/wham/usage`，成功后保存规范化的额度快照。

窗口类型必须由 `limit_window_seconds` 判断，不能假定 `primary_window` 一定是 5 小时或 `secondary_window` 一定是周额度。当前账号只返回 604800 秒窗口时，界面只显示周额度；未来出现多个窗口时动态增加。

刷新时机：

- 应用启动时刷新一次。
- ChatGPT（`com.openai.codex`）成为前台时立即刷新。
- 新任务开始时刷新。
- ChatGPT 在前台或存在运行中任务时，每 60 秒刷新。
- 完全隐藏时不高频轮询。

网络失败时保留最后一次成功值并显示更新时间。401/403 显示“请在 ChatGPT 重新登录”；字段缺失显示“额度暂不可用”。usage 是内部接口，字段将来可能变化，因此解码结构全部容忍缺失，UI 只渲染实际存在的数据。

## 6. 窗口与屏幕行为

窗口使用透明、无标题、不可激活的 `NSPanel`，层级为 `.popUpMenu`，行为包含 `.canJoinAllSpaces` 和 `.fullScreenAuxiliary`。定位根据 `safeAreaInsets`、`auxiliaryTopLeftArea`、`auxiliaryTopRightArea` 与当前屏幕 frame 计算，不写死当前 MacBook 的像素。

收起态不接收鼠标，避免遮挡菜单栏；紧凑态和展开态接收点击。监听屏幕参数变化，重新计算外接屏、分辨率切换、合盖与唤醒后的几何位置。若当前主屏没有物理刘海，V1 降级为菜单栏状态项，仍保留额度、任务列表与跳转能力。

窗口状态模型保持纯函数化：输入为前台应用、活动任务集合、最近完成事件、额度快照和悬停状态，输出为 `hidden`、`quotaCompact`、`workingCompact`、`completedCompact` 或 `expanded`。这样可以用单元测试覆盖优先级和延迟逻辑，不把业务判断散落在 SwiftUI 视图里。

## 7. 错误处理与隐私

- auth 文件不存在：提示先登录 Codex，任务监听继续工作。
- usage 请求失败：保留旧值并显示“更新于 …”。
- rollout 文件被截断或轮转：重置该文件偏移并重新构建状态。
- JSONL 单行损坏：跳过并记录不含正文的错误摘要。
- 深链失败：激活 ChatGPT（`com.openai.codex`）。
- 无刘海屏：菜单栏降级，不创建错位悬浮窗。
- 日志禁止记录 token、Authorization header、完整 usage 响应和用户消息正文。

## 8. V1 边界

V1 包含额度概览、运行中任务常驻、完成短提示、多任务列表、精确跳转、前台触发、全屏与多 Space 支持、无刘海降级和登录时启动。

V1 不包含 CC Switch 成本统计、5 小时硬编码、任务控制、宠物动画、音乐模块、插件系统、云同步、远程通知和 Mac App Store 分发。项目开源发布时提供已构建的 `.app.zip`，普通用户不需要安装 Swift 或 Xcode；源码贡献者再按 README 安装匹配的 Xcode 工具链。个人本地使用先采用 ad-hoc 签名；稳定后再考虑 Developer ID、公证和自动更新。

## 9. 验收场景

1. ChatGPT 前台且空闲：刘海展开额度，切走约 1.2 秒后隐藏。
2. Codex 发起任务后切到其他应用：刘海持续显示“工作中”。
3. 任务完成：显示绿色完成提示约 3 秒，然后按前台状态回到额度或隐藏。
4. 两个任务同时运行：主状态展示最近活跃任务，悬停可看到两个任务。
5. 点击主状态或任务行：直接打开对应 Codex 任务。
6. 账号只返回周窗口：只显示周额度，不制造 5 小时窗口。
7. usage 断网：任务状态正常，额度保留最后成功值。
8. rollout 出现坏行或 app 非正常退出：应用不崩溃，过期状态最终清理。
9. 全屏、切换 Space、外接显示器和唤醒后：窗口位置正确。
