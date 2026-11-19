import SwiftUI

enum FloatingSettingsContext: Equatable {
    case active, notched, hidden, unavailable

    init(layoutMode: NotchLayoutMode?, displayEnabled: Bool) {
        if !displayEnabled { self = .hidden }
        else if layoutMode == .floatingBar { self = .active }
        else if layoutMode == .notch { self = .notched }
        else { self = .unavailable }
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .active: return language.localized(chinese: "当前：无刘海或外接屏幕模式", english: "Current mode: no notch / external display")
        case .notched: return language.localized(chinese: "当前：刘海模式", english: "Current mode: notch")
        case .hidden: return language.localized(chinese: "顶部显示已隐藏", english: "The top display is hidden")
        case .unavailable: return language.localized(chinese: "当前未显示顶部悬浮岛", english: "No floating island is showing at the top")
        }
    }

    func explanation(for language: AppLanguage) -> String {
        switch self {
        case .active:
            return language.localized(
                chinese: "所选样式将立即应用到无刘海或外接屏顶部的悬浮岛。",
                english: "The selected style applies immediately to the top floating island on notchless or external displays."
            )
        case .notched:
            return language.localized(
                chinese: "仅适用于无刘海或外接屏顶部的悬浮岛，不影响刘海两侧显示；无需外接屏幕也可在下方预览。",
                english: "Applies only to the floating island on notchless or external displays without affecting the notch. You can preview it below anytime."
            )
        case .hidden:
            return language.localized(
                chinese: "可在下方预览无刘海或外接屏悬浮岛样式，设置将自动保存。",
                english: "Floating island styles for notchless or external displays remain available in the preview. Settings are saved automatically."
            )
        case .unavailable:
            return language.localized(
                chinese: "可在下方预览悬浮岛样式，设置将自动保存。",
                english: "Floating island styles are available in the preview. Settings are saved automatically."
            )
        }
    }
}

enum FloatingPreviewState: String, CaseIterable, Identifiable {
    case running, idle, completed
    var id: String { rawValue }
    var activity: QuotaRingActivity {
        switch self {
        case .running: return .running
        case .idle: return .idle
        case .completed: return .completed
        }
    }
    func title(for language: AppLanguage) -> String {
        switch self {
        case .running: return language.localized(chinese: "运行中", english: "Running")
        case .idle: return language.localized(chinese: "空闲", english: "Idle")
        case .completed: return language.localized(chinese: "完成提示", english: "Completion cue")
        }
    }
}

struct FloatingBarSettingsPreview: View {
    let style: FloatingCenterStyle
    let customText: String
    let state: FloatingPreviewState
    let language: AppLanguage
    let animationsEnabled: Bool
    var quotaStyle: QuotaDisplayStyle = .clockwiseRing
    var iconStyle: StatusIconStyle = .defaultStyle
    var showsFiveHourQuota = false
    // This fixed example never reads real tasks or starts a second task clock.
    private let sampleNow = Date(timeIntervalSince1970: 1_000)
    private let sampleQuota = UsageWindow(id: "settings-example", kind: .weekly, usedPercent: 25)

    var body: some View {
        VStack(spacing: 14) {
            sampleBar
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(language.localized(
                chinese: "\(style.title(for: language))的\(state.title(for: language))示例，示例额度 75%",
                english: "\(style.title(for: language)) example: \(state.title(for: language)), sample quota 75%"
            ))

            Text(language.localized(
                chinese: "仅供预览，额度为示例。实际完成提示约 5 秒后消失，不影响历史记录。",
                english: "Sample data only. The live completion cue lasts about 5 seconds; history is retained."
            ))
                .modifier(SettingsHelpTextStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    /// Exposes the exact fixture surface for static rendering regression checks.
    var sampleBar: some View {
        let windows = showsFiveHourQuota
            ? [UsageWindow(id: "settings-five-hour", kind: .rolling(hours: 5), usedPercent: 40), sampleQuota]
            : [sampleQuota]
        let shape = NotchSurfaceShape(
            layoutMode: .floatingBar, shoulderDepth: 6, bottomRadius: 14,
            leadingInset: iconStyle.showsLeftIndicator ? 0 : NotchFloatingBarLayout.appLaneWidth
        )
        return FloatingBarContent(
            activity: state.activity,
            usage: UsageSnapshot(windows: windows, fetchedAt: sampleNow),
            quotaDisplayStyle: quotaStyle, iconStyle: iconStyle,
            centerStyle: style, customText: customText,
            startedAt: sampleNow.addingTimeInterval(-138), now: sampleNow,
            quotaActivity: .idle, quotaMotionEnabled: false
        )
        .frame(width: NotchFloatingBarLayout.compactWidth, height: NotchFloatingBarLayout.preferredHeight)
        .background(.black, in: shape)
        .clipShape(shape)
        .environment(\.notchAppLanguage, language)
        .environment(\.notchMotionEnabled, animationsEnabled)
    }
}
