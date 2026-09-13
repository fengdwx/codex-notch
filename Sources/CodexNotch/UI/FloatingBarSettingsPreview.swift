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
        case .unavailable: return language.localized(chinese: "当前没有显示顶部横条", english: "No bar is showing at the top of the screen")
        }
    }

    func explanation(for language: AppLanguage) -> String {
        switch self {
        case .active:
            return language.localized(chinese: "所选样式将立即应用到屏幕顶部的横条。", english: "The selected style applies immediately to the bar at the top of the screen.")
        case .notched:
            return language.localized(chinese: "仅适用于无刘海或外接屏幕上的横条，不影响刘海两侧显示。无需外接屏幕，也可在下方预览。", english: "These settings apply to the bar on screens without a notch or on external displays. They do not affect the sides of the notch. The preview is available without an external display.")
        case .hidden:
            return language.localized(chinese: "可在下方预览无刘海或外接屏幕的样式，设置将自动保存。", english: "No-notch and external display styles remain available in the preview. Settings are saved automatically.")
        case .unavailable:
            return language.localized(chinese: "可在下方预览样式，设置将自动保存。", english: "Styles are available in the preview. Settings are saved automatically.")
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
        case .completed: return language.localized(chinese: "已完成", english: "Completed")
        }
    }
}

struct FloatingBarSettingsPreview: View {
    let style: FloatingCenterStyle
    let customText: String
    let state: FloatingPreviewState
    let language: AppLanguage
    let animationsEnabled: Bool
    // This fixed example never reads real tasks or starts a second task clock.
    private let sampleNow = Date(timeIntervalSince1970: 1_000)

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                StatusMark(style: .codex, size: 18)
                    .frame(width: NotchFloatingBarLayout.appLaneWidth)
                FloatingCenterContent(
                    style: style, customText: customText, activity: state.activity,
                    startedAt: sampleNow.addingTimeInterval(-138), now: sampleNow, isExpanded: false
                )
                .frame(width: NotchFloatingBarLayout.battleLaneWidth, height: 30)
                ZStack {
                    Circle().stroke(.white.opacity(0.4), lineWidth: 2)
                    Text("–").font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                }
                .frame(width: 20, height: 20)
                .frame(width: NotchFloatingBarLayout.quotaLaneWidth)
            }
            .padding(.horizontal, NotchFloatingBarLayout.horizontalInset)
            .frame(width: NotchFloatingBarLayout.compactWidth, height: 30)
            .background(.black, in: UnevenRoundedRectangle(bottomLeadingRadius: 9, bottomTrailingRadius: 9))
            .environment(\.notchAppLanguage, language)
            .environment(\.notchMotionEnabled, animationsEnabled)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(language.localized(
                chinese: "\(style.title(for: language))的\(state.title(for: language))示例",
                english: "\(style.title(for: language)) example: \(state.title(for: language))"
            ))

            Text(language.localized(chinese: "仅供预览，任务和额度为示例。", english: "Preview only. Tasks and quota use sample data."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }
}
