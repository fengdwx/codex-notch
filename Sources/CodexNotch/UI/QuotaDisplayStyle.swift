import Foundation

enum QuotaDisplayStyle: String, CaseIterable, Identifiable, Sendable {
    case clockwiseRing
    case waveBall

    static let storageKey = "quotaDisplayStyle"
    static let defaultStyle: QuotaDisplayStyle = .clockwiseRing

    var id: String { rawValue }

    var title: String {
        title(for: .chinese)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .clockwiseRing:
            return language.localized(chinese: "顺时针圆环", english: "Clockwise ring")
        case .waveBall:
            return language.localized(chinese: "波浪球", english: "Wave ball")
        }
    }

    var subtitle: String {
        subtitle(for: .chinese)
    }

    func subtitle(for language: AppLanguage) -> String {
        switch self {
        case .clockwiseRing:
            return language.localized(
                chinese: "缺口从12点顺时针展开；运行时渐变流动",
                english: "The gap starts at 12 o'clock; the gradient flows while running"
            )
        case .waveBall:
            return language.localized(
                chinese: "任务运行时液面轻微起伏",
                english: "The liquid level gently moves while running"
            )
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

enum CompletionParticleTone: Equatable {
    case success
    case highlight
    case coral
}

struct CompletionParticleSpec: Equatable {
    let angleDegrees: Double
    let startRadius: CGFloat
    let travelDistance: CGFloat
    let diameter: CGFloat
    let delay: TimeInterval
    let tone: CompletionParticleTone

    var endRadius: CGFloat {
        startRadius + travelDistance
    }
}

struct CompletionSparkSpec: Equatable {
    let angleDegrees: Double
    let radius: CGFloat
    let diameter: CGFloat
    let delay: TimeInterval
    let tone: CompletionParticleTone
}

enum QuotaIndicatorMotion {
    static let completionParticleTravelDuration: TimeInterval = 0.72
    static let completionIgnitionDuration: TimeInterval = 0.14
    static let completionSparkDuration: TimeInterval = 0.31
    static let completionSparkGlowRadius: CGFloat = 1.2
    static let completionFireworkHorizontalScale: CGFloat = 0.82
    static let completionInnerParticles: [CompletionParticleSpec] = [
        .init(
            angleDegrees: -126,
            startRadius: 2.4,
            travelDistance: 5.2,
            diameter: 2.3,
            delay: 0,
            tone: .highlight
        ),
        .init(
            angleDegrees: -82,
            startRadius: 2.8,
            travelDistance: 5.05,
            diameter: 1.8,
            delay: 0.06,
            tone: .success
        ),
        .init(
            angleDegrees: -38,
            startRadius: 2.5,
            travelDistance: 5.05,
            diameter: 2.4,
            delay: 0.02,
            tone: .success
        ),
        .init(
            angleDegrees: 8,
            startRadius: 3.0,
            travelDistance: 4.85,
            diameter: 1.8,
            delay: 0.10,
            tone: .highlight
        ),
        .init(
            angleDegrees: 54,
            startRadius: 2.6,
            travelDistance: 5.05,
            diameter: 2.2,
            delay: 0.04,
            tone: .success
        ),
        .init(
            angleDegrees: 118,
            startRadius: 2.9,
            travelDistance: 4.9,
            diameter: 1.9,
            delay: 0.12,
            tone: .success
        ),
        .init(
            angleDegrees: 188,
            startRadius: 2.7,
            travelDistance: 4.85,
            diameter: 2.4,
            delay: 0.08,
            tone: .highlight
        )
    ]

    // The exterior burst is deliberately uniform around the full circle. The
    // physical camera may mask its left half, but the animation itself remains
    // geometrically symmetric for real-hardware comparison.
    static let completionOuterParticles: [CompletionParticleSpec] = [
        .init(
            angleDegrees: -180,
            startRadius: 10.0,
            travelDistance: 4.2,
            diameter: 2.2,
            delay: 0.05,
            tone: .coral
        ),
        .init(
            angleDegrees: -150,
            startRadius: 10.1,
            travelDistance: 4.1,
            diameter: 2.0,
            delay: 0.08,
            tone: .success
        ),
        .init(
            angleDegrees: -120,
            startRadius: 10.2,
            travelDistance: 3.9,
            diameter: 2.1,
            delay: 0.02,
            tone: .highlight
        ),
        .init(
            angleDegrees: -90,
            startRadius: 10.0,
            travelDistance: 4.0,
            diameter: 2.0,
            delay: 0,
            tone: .success
        ),
        .init(
            angleDegrees: -60,
            startRadius: 10.2,
            travelDistance: 3.9,
            diameter: 2.1,
            delay: 0.02,
            tone: .highlight
        ),
        .init(
            angleDegrees: -30,
            startRadius: 10.1,
            travelDistance: 4.1,
            diameter: 2.0,
            delay: 0.08,
            tone: .success
        ),
        .init(
            angleDegrees: 0,
            startRadius: 10.0,
            travelDistance: 4.2,
            diameter: 2.2,
            delay: 0.05,
            tone: .coral
        ),
        .init(
            angleDegrees: 30,
            startRadius: 10.1,
            travelDistance: 4.1,
            diameter: 2.0,
            delay: 0.08,
            tone: .success
        ),
        .init(
            angleDegrees: 60,
            startRadius: 10.2,
            travelDistance: 3.9,
            diameter: 2.1,
            delay: 0.02,
            tone: .highlight
        ),
        .init(
            angleDegrees: 90,
            startRadius: 10.0,
            travelDistance: 4.0,
            diameter: 2.0,
            delay: 0,
            tone: .success
        ),
        .init(
            angleDegrees: 120,
            startRadius: 10.2,
            travelDistance: 3.9,
            diameter: 2.1,
            delay: 0.02,
            tone: .highlight
        ),
        .init(
            angleDegrees: 150,
            startRadius: 10.1,
            travelDistance: 4.1,
            diameter: 2.0,
            delay: 0.08,
            tone: .success
        )
    ]

    static let completionEndpointSparks: [CompletionSparkSpec] = [
        .init(
            angleDegrees: -180,
            radius: 14.2,
            diameter: 3.8,
            delay: 0.49,
            tone: .coral
        ),
        .init(
            angleDegrees: -135,
            radius: 14.2,
            diameter: 3.6,
            delay: 0.44,
            tone: .highlight
        ),
        .init(
            angleDegrees: -90,
            radius: 14.0,
            diameter: 3.4,
            delay: 0.52,
            tone: .success
        ),
        .init(
            angleDegrees: -45,
            radius: 14.2,
            diameter: 3.6,
            delay: 0.44,
            tone: .highlight
        ),
        .init(
            angleDegrees: 0,
            radius: 14.2,
            diameter: 3.8,
            delay: 0.49,
            tone: .coral
        ),
        .init(
            angleDegrees: 45,
            radius: 14.2,
            diameter: 3.6,
            delay: 0.44,
            tone: .highlight
        ),
        .init(
            angleDegrees: 90,
            radius: 14.0,
            diameter: 3.4,
            delay: 0.52,
            tone: .success
        ),
        .init(
            angleDegrees: 135,
            radius: 14.2,
            diameter: 3.6,
            delay: 0.44,
            tone: .highlight
        )
    ]

    static var completionParticles: [CompletionParticleSpec] {
        completionInnerParticles + completionOuterParticles
    }

    static var completionFireworkTotalDuration: TimeInterval {
        let particleEnd = completionParticleTravelDuration
            + (completionParticles.map(\.delay).max() ?? 0)
        let sparkEnd = completionSparkDuration
            + (completionEndpointSparks.map(\.delay).max() ?? 0)
        return max(max(particleEnd, sparkEnd), completionIgnitionDuration)
    }

    static func completionParticleProgress(
        elapsed: TimeInterval,
        delay: TimeInterval
    ) -> CGFloat {
        guard completionParticleTravelDuration > 0 else { return 1 }
        return min(
            max(
                CGFloat((elapsed - delay) / completionParticleTravelDuration),
                0
            ),
            1
        )
    }

    static func completionParticleOpacity(progress: CGFloat) -> Double {
        let clamped = min(max(progress, 0), 1)
        if clamped < 0.08 {
            return Double(clamped / 0.08)
        }
        if clamped <= 0.58 {
            return 1
        }
        return Double((1 - clamped) / 0.42)
    }

    static func completionParticleScale(progress: CGFloat) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        if clamped < 0.22 {
            return 0.72 + 0.28 * (clamped / 0.22)
        }
        return 1 - 0.18 * ((clamped - 0.22) / 0.78)
    }

    static func completionParticleGlowRadius(
        tone: CompletionParticleTone
    ) -> CGFloat {
        tone == .highlight ? 1.4 : 0.9
    }

    static func completionIgnitionProgress(elapsed: TimeInterval) -> CGFloat {
        guard completionIgnitionDuration > 0 else { return 1 }
        return min(
            max(CGFloat(elapsed / completionIgnitionDuration), 0),
            1
        )
    }

    static func completionIgnitionOpacity(progress: CGFloat) -> Double {
        let clamped = min(max(progress, 0), 1)
        return sin(Double(clamped) * .pi)
    }

    static func completionSparkProgress(
        elapsed: TimeInterval,
        delay: TimeInterval
    ) -> CGFloat {
        guard completionSparkDuration > 0 else { return 1 }
        return min(
            max(CGFloat((elapsed - delay) / completionSparkDuration), 0),
            1
        )
    }

    static func completionSparkOpacity(progress: CGFloat) -> Double {
        let clamped = min(max(progress, 0), 1)
        if clamped < 0.18 {
            return Double(clamped / 0.18)
        }
        if clamped <= 0.55 {
            return 1
        }
        return Double((1 - clamped) / 0.45)
    }

    static func completionSparkScale(progress: CGFloat) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        if clamped < 0.35 {
            return 0.45 + 0.70 * (clamped / 0.35)
        }
        return 1.15 - 0.45 * ((clamped - 0.35) / 0.65)
    }

    static func completionParticleOffset(
        spec: CompletionParticleSpec,
        progress: CGFloat
    ) -> CGSize {
        let clamped = min(max(progress, 0), 1)
        let eased = 1 - (1 - clamped) * (1 - clamped)
        let radius = spec.startRadius + spec.travelDistance * eased
        let radians = spec.angleDegrees * .pi / 180

        return CGSize(
            width: cos(radians) * radius * completionFireworkHorizontalScale,
            height: sin(radians) * radius
        )
    }

    static func completionSparkOffset(spec: CompletionSparkSpec) -> CGSize {
        let radians = spec.angleDegrees * .pi / 180
        return CGSize(
            width: cos(radians) * spec.radius
                * completionFireworkHorizontalScale,
            height: sin(radians) * spec.radius
        )
    }

    static func shouldAnimate(isTaskRunning: Bool, reduceMotion: Bool) -> Bool {
        isTaskRunning && !reduceMotion
    }
}

enum QuotaRingGradientMotion {
    static let restingAngle = -90.0
    static let flowingAngle = restingAngle + 360.0
    static let duration = 1.8

    static func angle(at date: Date, isAnimating: Bool) -> Double {
        guard isAnimating else { return restingAngle }

        let elapsed = date.timeIntervalSinceReferenceDate
        let remainder = elapsed.truncatingRemainder(dividingBy: duration)
        let cycleTime = remainder >= 0 ? remainder : remainder + duration
        let progress = cycleTime / duration
        return restingAngle + (flowingAngle - restingAngle) * progress
    }
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

    static func containedStrokeInset(lineWidth: CGFloat) -> CGFloat {
        max(0, lineWidth) / 2
    }

    static func clockwiseTrim(progress: CGFloat) -> (from: CGFloat, to: CGFloat) {
        let clamped = min(max(progress, 0), 1)
        return (1 - clamped, 1)
    }
}
