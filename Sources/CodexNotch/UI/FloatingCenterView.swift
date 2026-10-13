import SwiftUI

struct FloatingCenterView: View {
    let activity: QuotaRingActivity
    let startedAt: Date?
    let now: Date
    let isExpanded: Bool
    @AppStorage(FloatingCenterStyle.storageKey)
    private var styleRaw = FloatingCenterStyle.defaultStyle.rawValue
    @AppStorage(FloatingCenterText.storageKey)
    private var customText = FloatingCenterText.defaultText

    var body: some View {
        FloatingCenterContent(
            style: .fromStoredValue(styleRaw), customText: customText,
            activity: activity, startedAt: startedAt, now: now, isExpanded: isExpanded
        )
    }
}

/// Shared rendering for the live island and the explicitly labelled Settings demo.
struct FloatingCenterContent: View {
    let style: FloatingCenterStyle
    let customText: String
    let activity: QuotaRingActivity
    let startedAt: Date?
    let now: Date
    let isExpanded: Bool
    @Environment(\.notchMotionEnabled) private var motionEnabled
    @Environment(\.notchAppLanguage) private var language

    private var signature: String { FloatingCenterText.displayText(customText) }
    private var color: Color { FloatingActivityPresentation.tint(for: activity) }

    var body: some View {
        Group {
            switch style {
            case .signature:
                HStack(spacing: 6) {
                    FloatingActivityMark(activity: activity)
                    signatureLabel
                }
            case .orbit:
                HStack(spacing: 6) {
                    FloatingOrbitActivityMark(activity: activity, isAnimating: shouldAnimate)
                    signatureLabel
                }
            case .elapsed:
                HStack(spacing: 6) {
                    if activity == .running {
                        Image(systemName: "clock")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(color)
                            .frame(width: 16, height: 16)
                        Text(FloatingCenterText.elapsedText(activity: activity, startedAt: startedAt, now: now) ?? "--:--")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(Color.white.opacity(0.88))
                    } else {
                        FloatingActivityMark(activity: activity)
                        activityLabel
                    }
                }
            case .flow:
                flowContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
        .clipped()
        // The enclosing button retains the real task title and state.
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var flowContent: some View {
        switch activity {
        case .running:
            Capsule()
                .fill(color.opacity(0.32))
                .overlay {
                    if shouldAnimate {
                        motionLayer
                    } else {
                        Capsule()
                            .fill(LinearGradient(
                                colors: [.clear, color, Color.white.opacity(0.9), color, .clear],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: 32)
                    }
                }
                .frame(width: 96, height: 4)
                .clipShape(Capsule())
        case .idle:
            Capsule()
                .fill(Color.white.opacity(0.4))
                .frame(width: 64, height: 2)
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 18, height: 18)
        }
    }

    private var activityLabel: some View {
        Text(FloatingActivityPresentation.title(for: activity, language: language))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(activity == .completed ? color : Color.white.opacity(0.48))
            .lineLimit(1)
    }

    private var signatureLabel: some View {
        signatureGlyphs
            .foregroundStyle(Color.white.opacity(signatureOpacity))
            .overlay {
                if style == .signature {
                    motionLayer.mask(signatureGlyphs.foregroundStyle(Color.white))
                }
            }
    }

    private var signatureOpacity: Double {
        switch activity {
        case .running: return style == .signature && shouldAnimate ? 0.66 : 0.88
        case .idle: return 0.48
        case .completed: return 0.78
        }
    }

    private var signatureGlyphs: some View {
        Text(signature)
            .font(.system(size: 11, weight: .medium))
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var shouldAnimate: Bool {
        FloatingCenterMotionPolicy.shouldAnimate(
            style: style, activity: activity,
            motionEnabled: motionEnabled, isExpanded: isExpanded
        )
    }

    private var motionLayer: some View {
        FloatingCenterMotionLayer(
            style: style,
            activity: activity,
            isAnimating: shouldAnimate
        )
        .allowsHitTesting(false)
    }
}

/// A quiet, fixed-size state mark leaves the signature itself in focus.
struct FloatingActivityMark: View {
    let activity: QuotaRingActivity

    var body: some View {
        Group {
            switch activity {
            case .running:
                Capsule().frame(width: 2, height: 8)
            case .idle:
                Capsule().frame(width: 6, height: 1.5)
            case .completed:
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .foregroundStyle(FloatingActivityPresentation.tint(for: activity))
        .frame(width: 16, height: 16)
        .fixedSize()
    }
}

/// The orbit is the activity mark; a second status symbol would repeat it.
struct FloatingOrbitActivityMark: View {
    let activity: QuotaRingActivity
    let isAnimating: Bool

    var body: some View {
        ZStack {
            if activity == .completed {
                FloatingActivityMark(activity: .completed)
            } else {
                Circle()
                    .stroke(FloatingActivityPresentation.tint(for: activity).opacity(0.35), lineWidth: 1)
                    .frame(width: 12, height: 12)
                if activity == .running {
                    if isAnimating {
                        FloatingCenterMotionLayer(style: .orbit, activity: .running, isAnimating: true)
                            .frame(width: 16, height: 16)
                            .allowsHitTesting(false)
                    } else {
                        Circle()
                            .fill(FloatingActivityPresentation.tint(for: .running))
                            .frame(width: 3.5, height: 3.5)
                            .offset(y: -6)
                    }
                } else {
                    Capsule()
                        .fill(FloatingActivityPresentation.tint(for: .idle))
                        .frame(width: 6, height: 1.5)
                }
            }
        }
        .frame(width: 16, height: 16)
        .fixedSize()
    }
}

extension FloatingActivityPresentation {
    static func tint(for activity: QuotaRingActivity) -> Color {
        switch activity {
        case .running: return Color(red: 0.57, green: 0.78, blue: 0.94)
        case .completed: return Color(red: 0.48, green: 0.86, blue: 0.65)
        case .idle: return Color.white.opacity(0.6)
        }
    }
}
