import Foundation

enum QuotaDisplayStyle: String, CaseIterable, Identifiable, Sendable {
    case clockwiseRing
    case waveBall

    static let storageKey = "quotaDisplayStyle"
    static let defaultStyle: QuotaDisplayStyle = .clockwiseRing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clockwiseRing:
            return "顺时针圆环"
        case .waveBall:
            return "波浪球"
        }
    }

    var subtitle: String {
        switch self {
        case .clockwiseRing:
            return "缺口从12点顺时针展开；运行时渐变流动"
        case .waveBall:
            return "任务运行时液面轻微起伏"
        }
    }

    var systemImage: String {
        switch self {
        case .clockwiseRing:
            return "arrow.clockwise"
        case .waveBall:
            return "water.waves"
        }
    }

    static func fromStoredValue(_ rawValue: String) -> QuotaDisplayStyle {
        Self(rawValue: rawValue) ?? Self.defaultStyle
    }
}

enum QuotaIndicatorMotion {
    static func shouldAnimate(isTaskRunning: Bool, reduceMotion: Bool) -> Bool {
        isTaskRunning && !reduceMotion
    }
}

enum QuotaRingGradientMotion {
    static let restingAngle = -90.0
    static let flowingAngle = restingAngle + 360.0
    static let duration = 1.8
}

enum QuotaRingActivity: Equatable {
    case idle
    case running
    case completed
}

enum QuotaRingColorMode: Equatable {
    case solid
    case gradient
}

enum QuotaRingAppearance {
    static func colorMode(for activity: QuotaRingActivity) -> QuotaRingColorMode {
        activity == .running ? .gradient : .solid
    }
}

enum QuotaRingMath {
    static let clockwiseStartAngleDegrees = -90.0

    static func clockwiseTrim(progress: CGFloat) -> (from: CGFloat, to: CGFloat) {
        let clamped = min(max(progress, 0), 1)
        return (1 - clamped, 1)
    }
}
