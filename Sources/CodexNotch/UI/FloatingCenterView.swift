import SwiftUI

struct FloatingCenterView: View {
    let activity: QuotaRingActivity
    let startedAt: Date?
    let now: Date
    let isExpanded: Bool
    @Environment(\.notchMotionEnabled) private var motionEnabled
    @Environment(\.notchAppLanguage) private var language
    @AppStorage(FloatingCenterStyle.storageKey)
    private var styleRaw = FloatingCenterStyle.defaultStyle.rawValue
    @AppStorage(FloatingCenterText.storageKey)
    private var customText = FloatingCenterText.defaultText

    private var style: FloatingCenterStyle { .fromStoredValue(styleRaw) }
    private var signature: String { FloatingCenterText.displayText(customText) }
    private var color: Color {
        switch activity {
        case .running: return Color(red: 0.57, green: 0.78, blue: 0.94)
        case .completed: return Color(red: 0.48, green: 0.86, blue: 0.65)
        case .idle: return Color.white.opacity(0.4)
        }
    }

    var body: some View {
        Group {
            switch style {
            case .signature:
                signatureContent
            case .orbit:
                HStack(spacing: 7) {
                    motionLayer.frame(width: 18, height: 18)
                    signatureLabel
                }
            case .elapsed:
                if let elapsed = FloatingCenterText.elapsedText(activity: activity, startedAt: startedAt, now: now) {
                    HStack(spacing: 6) {
                        Text(language.localized(chinese: "运行", english: "RUN"))
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(color.opacity(0.85))
                        Text(elapsed)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(Color.white.opacity(0.82))
                    }
                } else {
                    signatureContent
                }
            case .flow:
                motionLayer.frame(width: 96, height: 3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
        .clipped()
        // The enclosing button retains the real task title and state.
        .accessibilityHidden(true)
    }

    private var signatureContent: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 4, height: 4)
            signatureLabel
        }
    }

    private var signatureLabel: some View {
        Text(signature)
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .tracking(0.2)
            .foregroundStyle(Color.white.opacity(0.7))
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var motionLayer: some View {
        FloatingCenterMotionLayer(
            style: style,
            activity: activity,
            isAnimating: FloatingCenterMotionPolicy.shouldAnimate(
                style: style, activity: activity,
                motionEnabled: motionEnabled, isExpanded: isExpanded
            )
        )
        .allowsHitTesting(false)
    }
}
