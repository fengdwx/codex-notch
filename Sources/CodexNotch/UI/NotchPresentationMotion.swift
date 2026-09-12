import Foundation
import SwiftUI

enum NotchPresentationMotion {
    static let expandDuration: TimeInterval = 0.65
    static let collapseDuration: TimeInterval = 0.50

    // Keep the accepted opening. The reference close briefly passes its target
    // before returning; the surface frame bounds that excursion around icons.
    static let expand = Animation.spring(
        response: 0.42,
        dampingFraction: 0.80,
        blendDuration: 0
    )
    static let collapseCurve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.175, y: 0.885),
        endControlPoint: UnitPoint(x: 0.32, y: 1.1)
    )
    static let collapse = Animation.timingCurve(collapseCurve, duration: collapseDuration)
    private static let contentResize = Animation.spring(response: 0.45, dampingFraction: 1, blendDuration: 0)

    static let detailTransition: AnyTransition = .asymmetric(
        insertion: .scale(scale: 0.8, anchor: .top)
            .combined(with: .opacity)
            .animation(.smooth(duration: 0.35)),
        removal: dissolve
    )

    // Only the returning compact header dissolves in. Removing it on opening
    // remains immediate, so the previously accepted opening is unchanged.
    static let compactReturnTransition: AnyTransition = .asymmetric(
        insertion: dissolve.animation(.easeOut(duration: 0.30).delay(0.06)),
        removal: .identity
    )

    private static let dissolve: AnyTransition = .opacity
        .animation(.easeOut(duration: 0.25))
        .combined(with: .modifier(
            active: NotchContentBlur(radius: 6),
            identity: NotchContentBlur(radius: 0)
        ).animation(.easeOut(duration: 0.30)))
        .combined(with: .scale(scale: 0.96, anchor: .top)
            .animation(.smooth(duration: 0.35)))

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

private struct NotchContentBlur: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

/// Bound the spring's visible excursion without changing its timing or moving
/// the top center. At a physical notch the compact camera-safe frame is a floor.
/// A floating island can compress slightly while keeping its 22pt icons inside.
struct NotchAnimatedSurfaceFrame: ViewModifier, Animatable {
    var size: CGSize
    let compactSize: CGSize
    let layoutMode: NotchLayoutMode

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(size.width, size.height) }
        set { size = CGSize(width: newValue.first, height: newValue.second) }
    }

    static func visibleSize(_ proposed: CGSize, compact: CGSize, mode: NotchLayoutMode) -> CGSize {
        func dimension(_ value: CGFloat, minimum: CGFloat, allowance: CGFloat) -> CGFloat {
            guard value < minimum else { return value }
            guard allowance > 0 else { return minimum }
            // Smoothly limit the excursion: no hard stop or clipped final frame.
            return minimum - allowance * tanh((minimum - value) / allowance)
        }
        let floating = mode == .floatingBar
        return CGSize(
            width: dimension(proposed.width, minimum: compact.width,
                             allowance: floating ? compact.width * 0.008 : 0),
            height: dimension(proposed.height, minimum: compact.height,
                              allowance: floating ? compact.height * 0.06 : 0)
        )
    }

    func body(content: Content) -> some View {
        let visible = Self.visibleSize(size, compact: compactSize, mode: layoutMode)
        content.frame(width: visible.width, height: visible.height, alignment: .top)
    }
}
