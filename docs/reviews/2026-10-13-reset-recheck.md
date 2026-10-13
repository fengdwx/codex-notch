# 额度重置功能复查（2026-10-13）

范围：查看重置机会、确认与取消、提交前核验、提交与结果刷新，以及本次窗口卡住修复。按 `QUOTA-RESET-059` 及继承的 `QUOTA-RESET-058` 检查；三路独立审查分别覆盖接口、UI/运行时、测试覆盖。

## 发现与修正

1. **P2：权威零次数与旧行不一致。** 当预检返回 `available_count=0`，同时仍带 `status=available` 的旧记录，原解析器会允许发起消费请求。独立模拟复现修复前请求 1 次，修复后请求 0 次。现在共享解析器将权威零次数统一视为空，展示和预检使用相同规则。未观察到真实服务端返回此矛盾响应。
2. **P3：结果窗存在时再次点击没有反馈。** 按钮已恢复可用，但运行时拒绝动作。现在将同一个结果窗置前，不新建确认，也不发送第二次请求。
3. **验证缺口：组件测试没有贯穿运行时。** 增加默认参数注入已有 view model/presenter；生产默认行为保持一致。新增测试调用实际 coordinator 的按钮回调，串联确认、收起、取消/提交和刷新。

## 验证证据

| 路径 | 结果及证据 |
| --- | --- |
| 取消后重新打开、关闭确认窗 | Runtime fixture 验证恢复 compact、清除 busy/pending、始终零 POST |
| 待确认与提交期间重复点击 | 同一个确认窗；确认前零 POST；提交和刷新期间总计一个 POST |
| 用完最后一次后的刷新 | 模拟服务返回空列表，旧行移除；额度只来自重新读取的数据 |
| 权威零次数夹带旧行 | Client/controller 与 runtime 两层回归验证零 POST、空列表 |
| 刷新时切换账号 | 不发布先前账号的读取结果，保留旧快照并明确报告刷新失败 |
| 预检期间停止运行 | 取消请求、隐藏窗口、清除状态，无迟到 POST 或结果窗 |
| Return、Escape 与重复关闭 | 窗口内键路由验证 Return 不确认、Escape 取消；回调至多一次 |
| 结果窗恢复 | 重新置前同一窗口，不新建确认、不重新提交 |
| 请求/隐私边界 | 真实 ID、到期与账号核验、全局单请求、幂等重试键、无自动重试、错误分类、敏感响应不落缓存均已复查 |

运行中版本所在的 managed worktree：最终 focused 检查 36 项通过；`scripts/verify.sh` 最终共执行 292 项：290 项通过、2 项原有可选录屏测试跳过、0 失败；102 条行为契约、release 构建、bundle 资源和签名验证通过。跳过的是 `NOTCH_SIGNATURE_FRAMES` 与 `NOTCH_MOTION_CAPTURE` 的原有 opt-in 录制用例，不是本次回归测试。

改动已同步回 `/Users/david/projects/codex-notch`。该目录的 99 条契约通过，`swift test --build-system native` 执行 286 项：284 项通过、2 项同样的 opt-in 录屏用例跳过、0 失败。两个工作目录原有基线不同，因此总测试数不同；当前实际运行的是保留较新 UI 基线的 managed 构建。

本机 Swift 6.4 使用先前已验证的 `--build-system native`，以保持资源 bundle 布局；没有修改或跳过普通测试。完整日志：`/tmp/codex-notch-full-recheck-final.log`。Mock 使用 UUID 临时 auth 目录、独立偏好以及拦截所有请求的 URLProtocol；无真实消费请求。该 fixture 的静态 backend 要求同进程串行执行。

已用通过验证的包替换并重新启动当前 managed worktree 下的 `dist/CodexNotch.app`，部署前后可执行文件 SHA-256 一致：`be63a8e1bb2c822ef35801ee6d538664001889b7ad05297978c271467ff42bcc`。此前包保留于 `/tmp/codex-notch-before-recheck.nGvFuR/CodexNotch.app`；没有发布或推送。

## 真实环境边界

此前用户与电脑操作共同确认：浅色按钮可见、确认窗可见、点击取消后窗口关闭且刘海回到 compact。本轮最终构建已重新启动，并核对实际路径及 compact 显示；这不能证明所有真实硬件交互均已复验。

随后用户明确反馈已完成实机检测：跨桌面（Space）切换、全屏两项均通过，没有问题。这两项记为用户实机验收通过。

实际消耗重置、真实服务端幂等行为、动画细节及收起后全部鼠标命中区域仍未单独验收。用户此次确认未涉及真实兑换；模拟成功响应不算真实兑换成功。

接口格式复核来源：[官方 Codex 请求实现](https://github.com/openai/codex/blob/main/codex-rs/backend-client/src/client/rate_limit_resets.rs)、[官方响应类型](https://github.com/openai/codex/blob/main/codex-rs/backend-client/src/types.rs)、[官方 banked resets 说明](https://help.openai.com/en/articles/20001498-how-banked-codex-resets-work)。这些源码观察不构成公开稳定 API 的承诺。
