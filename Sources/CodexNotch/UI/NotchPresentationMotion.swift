import Foundation
import SwiftUI

enum NotchPresentationMotion {
    static let expandDuration: TimeInterval = 0.65
    static let collapseDuration: TimeInterval = 0.50

    // Let the outer shell land and rebound, while content keeps a stable scale.
    // The surface frame bounds both opening and closing excursions.
    static let expand = Animation.spring(
        response: 0.48,
        dampingFraction: 0.68,
        blendDuration: 0
    )
    static let collapseCurve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.175, y: 0.885),
        endControlPoint: UnitPoint(x: 0.32, y: 1.1)
    )
    static let collapse = Animation.timingCurve(collapseCurve, duration: collapseDuration)
    private static let contentResize = Animation.spring(response: 0.45, dampingFraction: 1, blendDuration: 0)

    // Render type at its final size throughout. The shell supplies the elastic
    // movement; a small translation/reveal avoids visibly resampling glyphs.
    static let detailTransition: AnyTransition = .asymmetric(
        insertion: .modifier(
            active: NotchContentAppearance(opacity: 0, offsetY: -4, blurRadius: 1.5),
            identity: .visible
        ).animation(.easeOut(duration: 0.24).delay(0.035)),
        removal: .modifier(
            active: NotchContentAppearance(opacity: 0, offsetY: -6, blurRadius: 3),
            identity: .visible
        ).animation(.easeOut(duration: 0.18))
    )

    // Keep the returning status recognizable as the details leave. It should
    // be crisp well before the shell's compression/return, without a blank bar.
    static let compactReturnTransition: AnyTransition = .asymmetric(
        insertion: .modifier(
            active: NotchContentAppearance(opacity: 0.65, offsetY: 0, blurRadius: 1),
            identity: .visible
        ).animation(.easeOut(duration: 0.16)),
        removal: .identity
    )

    static func animation(forExpanding isExpanding: Bool, isCollapsingCard: Bool) -> Animation {
        if isExpanding { return expand }
        return isCollapsingCard ? collapse : contentResize
    }

    static func shouldAnimateSurface(
        changesSurface: Bool,
        animationsEnabled: Bool
    ) -> Bool {
        changesSurface && animationsEnabled
    }

    static func canvasFrame(for target: CGRect, isExpanded: Bool, animationsEnabled: Bool) -> CGRect {
        guard isExpanded, animationsEnabled else { return target }
        // Preserve the screen-top anchor; make room only beside/below it.
        return CGRect(x: target.minX - 8, y: target.minY - 8,
                      width: target.width + 16, height: target.height + 8)
    }
}

private struct NotchContentAppearance: ViewModifier {
    let opacity: Double
    let offsetY: CGFloat
    let blurRadius: CGFloat

    static let visible = Self(opacity: 1, offsetY: 0, blurRadius: 0)

    func body(content: Content) -> some View {
        content
            .offset(y: offsetY)
            .blur(radius: blurRadius)
            .opacity(opacity)
    }
}

/// Bound the spring's visible excursion without changing its timing or moving
/// the top center. At a physical notch the compact camera-safe frame is a floor.
/// A floating island can compress slightly while keeping its 22pt icons inside.
struct NotchAnimatedSurfaceFrame: ViewModifier, Animatable {
    var size: CGSize
    let compactSize: CGSize
    let layoutMode: NotchLayoutMode
    var expandedLimit: CGSize? = nil

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(size.width, size.height) }
        set { size = CGSize(width: newValue.first, height: newValue.second) }
    }

    static func visibleSize(
        _ proposed: CGSize, compact: CGSize, mode: NotchLayoutMode, expandedLimit: CGSize? = nil
    ) -> CGSize {
        func dimension(_ value: CGFloat, minimum: CGFloat, allowance: CGFloat) -> CGFloat {
            guard value < minimum else { return value }
            guard allowance > 0 else { return minimum }
            // Smoothly limit the excursion: no hard stop or clipped final frame.
            return minimum - allowance * tanh((minimum - value) / allowance)
        }
        let floating = mode == .floatingBar
        var result = CGSize(
            width: dimension(proposed.width, minimum: compact.width,
                             allowance: floating ? compact.width * 0.008 : 0),
            height: dimension(proposed.height, minimum: compact.height,
                              allowance: floating ? compact.height * 0.06 : 0)
        )
        if let target = expandedLimit {
            // Keep the landing inside the canvas's existing 8pt clearance even
            // for tall cards. Only the shell moves; detail layout stays fixed.
            if result.width > target.width {
                result.width = target.width + 6 * tanh((result.width - target.width) / 6)
            }
            if result.height > target.height {
                result.height = target.height + 8 * tanh((result.height - target.height) / 8)
            }
        }
        return result
    }

    func body(content: Content) -> some View {
        let visible = Self.visibleSize(size, compact: compactSize, mode: layoutMode, expandedLimit: expandedLimit)
        content.frame(width: visible.width, height: visible.height, alignment: .top)
    }
}
