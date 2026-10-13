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
        case .idle: return Color.white.opacity(0.6)
        }
    }

    var body: some View {
        Group {
            switch style {
            case .signature:
                HStack(spacing: 6) {
                    activityGlyph
                    signatureLabel
                }
            case .orbit:
                HStack(spacing: 6) {
                    activityGlyph
                    motionLayer.frame(width: 18, height: 18)
                    signatureLabel
                }
            case .elapsed:
                HStack(spacing: 6) {
                    activityGlyph
                    if let elapsed = FloatingCenterText.elapsedText(activity: activity, startedAt: startedAt, now: now) {
                        Text(elapsed)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(Color.white.opacity(0.82))
                    } else {
                        activityLabel
                    }
                }
            case .flow:
                VStack(spacing: 3) {
                    HStack(spacing: 5) {
                        activityGlyph
                        activityLabel
                    }
                    motionLayer.frame(width: 96, height: 2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
        .clipped()
        // The enclosing button retains the real task title and state.
        .accessibilityHidden(true)
    }

    private var activityGlyph: some View {
        Image(systemName: FloatingActivityPresentation.symbol(for: activity))
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 12, height: 12)
            .fixedSize()
    }

    private var activityLabel: some View {
        Text(FloatingActivityPresentation.title(for: activity, language: language))
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(activity == .completed ? color : Color.white.opacity(0.78))
            .lineLimit(1)
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
