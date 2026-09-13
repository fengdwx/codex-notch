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
                signatureLabel
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
        signatureGlyphs
            .foregroundStyle(Color.white.opacity(style == .signature && shouldAnimate ? 0.3 : 0.7))
            .overlay {
                if style == .signature {
                    motionLayer.mask(signatureGlyphs.foregroundStyle(Color.white))
                }
            }
    }

    private var signatureGlyphs: some View {
        Text(signature)
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .tracking(0.2)
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
