import Foundation
import SwiftUI

enum NotchPresentationMotion {
    static let expandDuration: TimeInterval = 0.38
    static let collapseDuration: TimeInterval = 0.30

    // Keep the island's motion soft, but do not let it overshoot beyond the
    // physical-notch canvas. The outer panel is already at its final size;
    // only this SwiftUI surface moves.
    static let expand = Animation.spring(
        response: 0.42,
        dampingFraction: 0.88,
        blendDuration: 0
    )
    static let collapse = Animation.spring(
        response: 0.30,
        dampingFraction: 0.96,
        blendDuration: 0
    )

    static func animation(forExpanding isExpanding: Bool) -> Animation {
        isExpanding ? expand : collapse
    }

    static func shouldAnimateSurface(
        changesSurface _: Bool,
        animationsEnabled _: Bool
    ) -> Bool {
        false
    }
}
