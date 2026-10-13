import Foundation

enum FloatingCenterStyle: String, CaseIterable, Identifiable, Sendable {
    case signature
    case orbit
    case elapsed
    case flow

    static let storageKey = "floatingCenterStyle"
    static let defaultStyle: Self = .signature
    var id: String { rawValue }

    static func fromStoredValue(_ value: String?) -> Self {
        value.flatMap(Self.init(rawValue:)) ?? defaultStyle
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .signature: return language.localized(chinese: "个人签名", english: "Signature")
        case .orbit: return language.localized(chinese: "轨道签名", english: "Orbit text")
        case .elapsed: return language.localized(chinese: "任务计时", english: "Task timer")
        case .flow: return language.localized(chinese: "极简光带", english: "Minimal flow")
        }
    }

    var usesCustomText: Bool { self == .signature || self == .orbit }

    func explanation(for language: AppLanguage) -> String {
        switch self {
        case .signature:
            return language.localized(chinese: "运行时文字明亮、微光流动；空闲时文字变淡，光标变为短横。", english: "Bright text and a subtle shimmer while running; quiet text and a dash while idle.")
        case .orbit:
            return language.localized(chinese: "运行时圆点沿轨道转动；空闲时显示静态圆环与短横。", english: "A bead orbits while running; a quiet ring and dash indicate idle.")
        case .elapsed:
            return language.localized(chinese: "运行时显示时钟与已用时间；空闲时显示“空闲”，完成时短暂提示。", english: "A clock and elapsed time while running, Idle while resting, and a brief completion cue.")
        case .flow:
            return language.localized(chinese: "居中的单条光带：运行时流动，空闲时收短变淡，完成时短暂显示绿勾。", english: "One centered light: flowing while running, shorter and dimmer while idle, with a brief green check on completion.")
        }
    }
}

/// Shapes and words retain the state when motion and color cannot help.
enum FloatingActivityPresentation {
    static func title(for activity: QuotaRingActivity, language: AppLanguage) -> String {
        switch activity {
        case .running: return language.localized(chinese: "运行中", english: "Running")
        case .idle: return language.localized(chinese: "空闲", english: "Idle")
        case .completed: return language.localized(chinese: "刚完成", english: "Finished")
        }
    }
}

enum FloatingCenterText {
    static let storageKey = "floatingCenterText"
    static let defaultText = "Codex"
    static let maximumCharacters = 12

    static func normalized(_ text: String) -> String {
        String(text.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(maximumCharacters))
    }

    static func displayText(_ text: String) -> String {
        let value = normalized(text)
        return value.isEmpty ? defaultText : value
    }

    static func elapsedText(activity: QuotaRingActivity, startedAt: Date?, now: Date) -> String? {
        guard activity == .running, let startedAt, startedAt > .distantPast else { return nil }
        let interval = now.timeIntervalSince(startedAt)
        guard interval.isFinite, interval < Double(Int.max) else { return nil }
        let seconds = Int(max(0, interval).rounded(.down))
        if seconds >= 3_600 {
            return "\(seconds / 3_600):" + String(format: "%02d:%02d", seconds / 60 % 60, seconds % 60)
        }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

enum FloatingCenterMotionPolicy {
    static func shouldAnimate(
        style: FloatingCenterStyle,
        activity: QuotaRingActivity,
        motionEnabled: Bool,
        isExpanded: Bool
    ) -> Bool {
        guard motionEnabled, !isExpanded else { return false }
        switch style {
        case .signature, .orbit, .flow: return activity == .running
        case .elapsed: return false
        }
    }
}
