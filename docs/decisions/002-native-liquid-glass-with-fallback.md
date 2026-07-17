---
status: superseded
contract_ids: [EXPANDED-APPEARANCE-009, NOTCH-MOTION-002]
supersedes: []
superseded_by: 003-abandon-cross-window-liquid-glass
owner: project-maintainer
created_at: 2026-07-17
last_verified_commit: 916f72b
---

# 展开表面使用原生 Liquid Glass，并兼容旧系统

## 背景

展开卡片需要提供最新 macOS 风格的玻璃外观，同时项目仍以 macOS 14 为最低部署版本。材质变化不能破坏既有固定透明画布和只向下展开的窗口边界。

## 决策

- 默认外观为玻璃，并在设置页提供玻璃、黑色的实时分段选择。
- macOS 26 及以上只在整个展开表面应用一次 SwiftUI `glassEffect`，使用轻微深色 tint 保证白色正文可读，并启用系统指针交互效果。
- macOS 14 和 15 使用 `ultraThinMaterial` 加轻微深色遮罩作为兼容降级，不伪造 Liquid Glass 动画。
- 紧凑刘海和黑色选项继续使用纯黑表面；隐藏态保持完全透明。
- 材质只由 SwiftUI 绘制，不改变 `NotchWindowController` 的固定画布准备、回收和面板 frame 策略。

## 被拒绝的方案

- **把最低系统版本提升到 macOS 26**：会无必要地放弃现有 macOS 14、15 用户。
- **手写多层模糊和高光冒充 Liquid Glass**：无法跟随系统材质行为，且维护成本高。
- **给每个额度行、重置行和聊天行分别加玻璃**：会使信息层级浑浊，也增加合成开销。
- **用窗口透明度或 frame 动画表达材质切换**：会破坏固定画布边界，并重新带来跳动风险。

## 后果与验证

- 自动测试锁定默认值、可选项以及“只在可见展开态使用玻璃”的状态映射。
- 完整验证必须覆盖 macOS 14 部署目标编译和 app bundle 检查。
- 系统玻璃的真实折射、指针响应、文字对比度以及展开收起观感仍需在物理刘海机器上人工确认。
