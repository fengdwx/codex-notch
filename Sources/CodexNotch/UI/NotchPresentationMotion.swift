import Foundation
import SwiftUI

enum NotchPresentationMotion {
    static let expandDuration: TimeInterval = 0.65
    static let collapseDuration: TimeInterval = 0.60

    // Expansion has a restrained rebound inside a slightly larger canvas.
    // Collapse is critically damped so it never shrinks into the camera gap.
    static let expand = Animation.spring(
        response: 0.48,
        dampingFraction: 0.80,
        blendDuration: 0
    )
    static let collapse = Animation.spring(
        response: 0.38,
        dampingFraction: 1,
        blendDuration: 0
    )

    // Keep content timing independent from the spring: reveal after the shell
    // starts opening, and clear the details before the shell finishes closing.
    static let detailTransition: AnyTransition = .asymmetric(
        insertion: .opacity.animation(.easeOut(duration: 0.18).delay(0.10)),
        removal: .opacity.animation(.easeOut(duration: 0.10))
    )

    static func animation(forExpanding isExpanding: Bool) -> Animation {
        isExpanding ? expand : collapse
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
