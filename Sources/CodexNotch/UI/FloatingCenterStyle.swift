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
        case .orbit: return language.localized(chinese: "轨道签名", english: "Orbit")
        case .elapsed: return language.localized(chinese: "运行计时", english: "Elapsed time")
        case .flow: return language.localized(chinese: "细流光", english: "Light flow")
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
        case .signature: return true
        case .orbit, .flow: return activity == .running
        case .elapsed: return false
        }
    }
}
