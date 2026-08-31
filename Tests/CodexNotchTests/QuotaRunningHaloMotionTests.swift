import XCTest
@testable import CodexNotch

final class QuotaRunningHaloMotionTests: XCTestCase {
    func testHaloRunsOnlyForMotionEnabledVisibleNotchQuotaIndicators() {
        XCTAssertTrue(
            QuotaRunningHaloMotion.shouldAnimate(
                layoutMode: .notch,
                activity: .running,
                hasQuota: true,
                motionEnabled: true
            )
        )
        XCTAssertFalse(
            QuotaRunningHaloMotion.shouldAnimate(
                layoutMode: .notch,
                activity: .idle,
                hasQuota: true,
                motionEnabled: true
            )
        )
        XCTAssertFalse(
            QuotaRunningHaloMotion.shouldAnimate(
                layoutMode: .notch,
                activity: .completed,
                hasQuota: true,
                motionEnabled: true
            )
        )
        XCTAssertFalse(
            QuotaRunningHaloMotion.shouldAnimate(
                layoutMode: .notch,
                activity: .running,
                hasQuota: false,
                motionEnabled: true
            )
        )
        XCTAssertFalse(
            QuotaRunningHaloMotion.shouldAnimate(
                layoutMode: .floatingBar,
                activity: .running,
                hasQuota: true,
                motionEnabled: true
            )
        )
        XCTAssertFalse(
            QuotaRunningHaloMotion.shouldAnimate(
                layoutMode: .notch,
                activity: .running,
                hasQuota: true,
                motionEnabled: false
            )
        )
    }

    func testHaloRemainsInsideTheVisibleIndicatorSideClearanceAtEightFrames() {
        let visibleSideDiameter = NotchCompactLayout.indicatorDiameter
            + NotchCompactLayout.quotaIndicatorCameraClearance * 2

        XCTAssertGreaterThan(QuotaRunningHaloMotion.duration, 2.0)
        XCTAssertLessThan(QuotaRunningHaloMotion.duration, 3.5)
        XCTAssertGreaterThan(
            QuotaRunningHaloMotion.visualDiameter,
            NotchCompactLayout.indicatorDiameter
        )
        XCTAssertLessThanOrEqual(
            QuotaRunningHaloMotion.visualDiameter,
            visibleSideDiameter
        )
        XCTAssertLessThanOrEqual(
            QuotaRunningHaloMotion.visualDiameter,
            NotchCompactLayout.indicatorLaneWidth
        )
        XCTAssertLessThan(
            QuotaRunningHaloMotion.minimumOpacity,
            QuotaRunningHaloMotion.maximumOpacity
        )
        XCTAssertLessThan(QuotaRunningHaloMotion.minimumScale, 1)
        XCTAssertGreaterThanOrEqual(QuotaRunningHaloMotion.maximumScale, 1)
        XCTAssertEqual(
            QuotaLayerAnimationPolicy.preferredFramesPerSecond,
            8
        )
    }
}
