import Foundation

enum UsageWindowClassifier {
    static func kind(seconds: Int) -> UsageWindowKind {
        let normalized = max(0, seconds)

        if (6 * 86_400 ... 8 * 86_400).contains(normalized) {
            return .weekly
        }

        if abs(normalized - 86_400) <= 3_600 {
            return .daily
        }

        if normalized > 0, normalized < 7 * 86_400, normalized.isMultiple(of: 3_600) {
            return .rolling(hours: normalized / 3_600)
        }

        return .custom(seconds: seconds)
    }

    static func clampPercent(_ value: Double) -> Double {
        min(100, max(0, value))
    }
}
