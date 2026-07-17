# CodexNotch

简体中文 · [English](README.md)

CodexNotch 是一个独立的 macOS 原生小程序：Codex 任务运行时出现在刘海两侧，同时显示活动状态和周额度；空闲时也保留紧凑额度指示器，悬停实体刘海可展开详情。它不依赖 Atoll、CodexIsland、CC Switch 或其他宿主程序。

## 功能

- Codex 任务运行时，即使切换到其他应用，也在刘海旁保持工作状态；空闲时保留紧凑周额度指示器。
- 鼠标移入实体刘海后，卡片只从刘海位置向下展开，显示周额度、重置时刻、倒计时和最近对话。
- 左右紧凑指标都放在相同的 24pt 容器中：左侧 ChatGPT 标记按视觉重量校正为 22pt，运行任务时仅保留克制的静态蓝色图形回声，完成后显示一次绿色图形回声和对号；右侧可显示“12 点起点顺时针圆环”或“波浪球”。
- 应用包带有原创的深绿终端图标：顶部小刘海槽、终端标题栏和高对比绿色 `>_` 提示符，在 Finder、启动台和安装包中可辨识；不使用账号或对话数据生成图标。
- 展开卡片右下角的“设置”、右键刘海或应用菜单中的“设置…”都可切换额度指示器和展开时显示的最近聊天条数；设置窗口会自动置顶。实际刘海就是实时预览，因此设置窗口不再重复显示静态预览。数字始终显示在指标内部，波浪球只为字形加细描边，不遮挡液面；只有任务运行时液面才会起伏。修改会立即生效并保存在本机。
- 周额度剩余不低于 20% 时圆环为绿色，低于 20% 时为红色；运行任务时，渐变色沿对应剩余额度的圆环柔和流动；空闲、完成或启用 Reduce Motion 时保持静止。未返回周额度时显示灰色。
- 悬停展开当前活动任务、本周横向额度进度条和当前的精确重置时刻/秒级倒计时；展开正文的额度、重置和最近对话均使用更易读的字号。其下整行“可重置 N 次”均可点击，展开后逐条列出实际可用重置券的精确到期时刻和倒计时，不重复显示券名称。圆环只用于收起状态，点击任务直接打开 codex://threads/<thread-id>。
- 按接口返回的 limit_window_seconds 动态识别额度窗口，不写死 5 小时。
- 无刘海屏幕使用菜单栏 fallback，不读取或展示用户消息正文。

## 普通用户安装

普通用户只需要下载 Release 中的 CodexNotch-...zip，解压后将 CodexNotch.app 拖到“应用程序”文件夹。无需安装 Swift、Swift Package Manager 或 Xcode。

首次运行的本地 release 默认使用 ad-hoc 签名，macOS 可能提示无法验证开发者。可以在“系统设置 → 隐私与安全性”中选择仍要打开，或右键应用并选择“打开”。正式公开分发时建议使用 Developer ID 签名和公证。

运行前请先在 ChatGPT 中登录并使用 Codex。应用会读取默认目录 ~/.codex；如果你的 Codex 使用了其他目录，可以通过 CODEX_HOME 环境变量指定。

## 从源码构建

源码贡献者需要 macOS 14 或更高版本，以及 Xcode 15 / Swift 5.9 或更新版本：

~~~sh
swift test
./scripts/build_app.sh
open dist/CodexNotch.app
~~~

生成可发布压缩包：

~~~sh
./scripts/release.sh
~~~

脚本会先运行测试、构建 release .app、做代码签名校验，并生成 zip 与 SHA-256 文件。默认签名是本机可用的 ad-hoc 签名；只想跳过签名时可使用：

~~~sh
SIGN_IDENTITY=none ./scripts/build_app.sh
~~~

## 数据与隐私

- 认证令牌只从 CODEX_HOME/auth.json 读取并保存在进程内存，不写入 CodexNotch 的缓存或日志。
- 额度与可用重置券明细分别请求 ChatGPT 的只读 usage 和重置券接口。
- 任务状态只解析本地 CODEX_HOME/sessions rollout JSONL 文件。
- 不记录 Authorization header、完整 usage 响应或用户消息正文。

usage 接口属于 ChatGPT 的内部接口，未来字段可能变化；接口异常时会保留最后一次成功的额度，任务监听仍然继续工作。

## 当前边界

这是 v1 preview。当前版本不提供终止 Codex 任务、成本统计、云同步、远程通知、宠物动画或 Mac App Store 分发。ChatGPT Classic 不属于监听目标。

## 许可证

本项目使用 MIT License，详见 [LICENSE](LICENSE)。
