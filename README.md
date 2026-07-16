# CodexNotch

CodexNotch 是一个独立的 macOS 原生小程序：Codex 任务运行时出现在刘海两侧，同时显示活动状态和周额度；空闲时保持隐藏，悬停实体刘海可查看额度。它不依赖 Atoll、CodexIsland、CC Switch 或其他宿主程序。

## 功能

- Codex 任务运行时，即使切换到其他应用，也在刘海旁保持工作状态；没有运行任务时完全隐藏。
- 空闲时只保留一个覆盖实体刘海的透明感应区域，鼠标移入后展开周额度、重置时刻和倒计时。
- 左侧使用高清 ChatGPT 标记和克制的呼吸动画，右侧显示周额度圆环。
- 周额度剩余不低于 20% 时圆环为绿色，低于 20% 时为红色；未返回周额度时显示灰色。
- 悬停展开当前活动任务、本周精确重置时刻和秒级倒计时；展开后的图标与圆环仍保持在刘海同高位置，点击任务直接打开 codex://threads/<thread-id>。
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
- 额度请求发送到 ChatGPT 的 usage 接口。
- 任务状态只解析本地 CODEX_HOME/sessions rollout JSONL 文件。
- 不记录 Authorization header、完整 usage 响应或用户消息正文。

usage 接口属于 ChatGPT 的内部接口，未来字段可能变化；接口异常时会保留最后一次成功的额度，任务监听仍然继续工作。

## 当前边界

这是 v1 preview。当前版本不提供终止 Codex 任务、成本统计、云同步、远程通知、宠物动画或 Mac App Store 分发。ChatGPT Classic 不属于监听目标。

## 许可证

本项目使用 MIT License，详见 [LICENSE](LICENSE)。
