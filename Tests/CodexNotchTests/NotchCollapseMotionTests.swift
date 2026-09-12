import SwiftUI
import XCTest
@testable import CodexNotch

final class NotchCollapseMotionTests: XCTestCase {
    func testCloseMatchesRecordedTravelAndReturnsAfterPassingTheTarget() {
        // User's 30 FPS reference: 319px expanded, 74px at the trough,
        // then 79px settled. Time starts approximately at 3.983s.
        // Allow sampling/capture jitter; test the motion, not Bézier constants.
        let samples: [(time: Double, travel: Double)] = [
            (0.05, 103.0 / 240),
            (0.0833, 151.0 / 240),
            (0.15, 196.0 / 240),
            (0.25, 235.0 / 240),
            (0.35, 245.0 / 240),
            (0.50, 1)
        ]
        for sample in samples {
            let actual = NotchPresentationMotion.collapseCurve.value(at: sample.time / NotchPresentationMotion.collapseDuration)
            XCTAssertEqual(actual, sample.travel, accuracy: 0.06)
        }
        let trough = NotchPresentationMotion.collapseCurve.value(at: 0.7)
        XCTAssertGreaterThan(trough, 1.015, "A monotonic close loses the reference's return movement")
        XCTAssertLessThan(trough, 1.03, "The rebound should be restrained")
        XCTAssertEqual(NotchPresentationMotion.collapseCurve.value(at: 1), 1)
    }

    func testFloatingReboundRemainsVisibleWithoutClippingEitherIcon() {
        for height in [NotchFloatingBarLayout.preferredHeight, NotchFloatingBarLayout.autoHiddenMenuBarHeight] {
            let compact = CGSize(width: NotchFloatingBarLayout.compactWidth, height: height)
            let start = CGSize(width: 420, height: 580)
            let frames = (0...60).map { index -> CGSize in
                let travel = NotchPresentationMotion.collapseCurve.value(at: Double(index) / 60)
                let proposed = CGSize(width: start.width + (compact.width - start.width) * travel,
                                      height: start.height + (compact.height - start.height) * travel)
                return NotchAnimatedSurfaceFrame.visibleSize(proposed, compact: compact, mode: .floatingBar)
            }
            let minimumHeight = frames.map(\.height).min()!
            let minimumWidth = frames.map(\.width).min()!
            XCTAssertLessThan(minimumHeight, compact.height - 1)
            XCTAssertGreaterThanOrEqual(minimumHeight, compact.height * 0.94)
            XCTAssertGreaterThan(minimumHeight, (compact.height + NotchCompactLayout.indicatorDiameter) / 2 + 1)
            XCTAssertGreaterThanOrEqual(minimumWidth, compact.width * 0.992)
            XCTAssertEqual(frames.last, compact)
        }
    }

    func testPhysicalNotchCannotCompressItsCameraSafeFrameAndExpansionIsUnchanged() {
        let compact = CGSize(width: 300, height: 32)
        for proposed in [CGSize(width: 294, height: 24), CGSize(width: 280, height: 30), .zero] {
            let result = NotchAnimatedSurfaceFrame.visibleSize(proposed, compact: compact, mode: .notch)
            XCTAssertGreaterThanOrEqual(result.width, compact.width)
            XCTAssertGreaterThanOrEqual(result.height, compact.height)
        }
        for mode in [NotchLayoutMode.notch, .floatingBar] {
            for size in [compact, CGSize(width: 380, height: 180), CGSize(width: 426, height: 326)] {
                XCTAssertEqual(NotchAnimatedSurfaceFrame.visibleSize(size, compact: compact, mode: mode), size)
            }
            XCTAssertEqual(NotchAnimatedSurfaceFrame.visibleSize(CGSize(width: 180, height: 20), compact: .zero, mode: mode),
                           CGSize(width: 180, height: 20), "The hidden hover sensor must retain its own geometry")
        }
    }
}
