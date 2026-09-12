import Foundation
import SwiftUI

enum NotchPresentationMotion {
    static let expandDuration: TimeInterval = 0.65
    static let collapseDuration: TimeInterval = 0.60

    // Expansion has a restrained rebound inside a slightly larger canvas.
    // Collapse is critically damped so it never shrinks into the camera gap.
    static let expand = Animation.spring(
        response: 0.42,
        dampingFraction: 0.80,
        blendDuration: 0
    )
    static let collapse = Animation.spring(
        response: 0.45,
        dampingFraction: 1,
        blendDuration: 0
    )

    // Move the laid-out detail layer with the shell. A delayed insertion and
    // 0.10s removal left an empty black slab for most of each transition.
    // Top-anchored scaling preserves text layout while visually gathering it
    // toward the compact header; opacity finishes over the same movement.
    static let detailTransition: AnyTransition = .scale(scale: 0.8, anchor: .top)
        .combined(with: .opacity)
        .animation(.smooth(duration: 0.35))

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
