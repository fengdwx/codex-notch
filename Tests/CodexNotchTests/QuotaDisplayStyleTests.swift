import XCTest
@testable import CodexNotch

final class QuotaDisplayStyleTests: XCTestCase {
    func testOnlyRingAndWaveStylesAreAvailable() {
        XCTAssertEqual(
            QuotaDisplayStyle.allCases,
            [.clockwiseRing, .waveBall]
        )
    }

    func testStoredValueFallsBackToClockwiseRing() {
        XCTAssertEqual(
            QuotaDisplayStyle.fromStoredValue("unknown"),
            .clockwiseRing
        )
    }

    func testStyleMetadataIsUserFacing() {
        XCTAssertEqual(QuotaDisplayStyle.clockwiseRing.title, "顺时针圆环")
        XCTAssertEqual(QuotaDisplayStyle.waveBall.title, "波浪球")
        XCTAssertFalse(QuotaDisplayStyle.waveBall.subtitle.isEmpty)
    }

    func testClockwiseRingGapExpandsFromTwelveOClockAnchor() {
        let trim = QuotaRingMath.clockwiseTrim(progress: 0.43)
        XCTAssertEqual(trim.from, 0.57, accuracy: 0.0001)
        XCTAssertEqual(trim.to, 1, accuracy: 0.0001)
        XCTAssertEqual(QuotaRingMath.clockwiseStartAngleDegrees, -90)
    }

    func testCompactAppIconUsesOpticalCorrectionInsideSharedIndicatorContainer() {
        XCTAssertEqual(NotchCompactLayout.indicatorDiameter, 24)
        XCTAssertEqual(NotchCompactLayout.appMarkSize, 20)
        XCTAssertLessThan(
            NotchCompactLayout.appMarkSize,
            NotchCompactLayout.indicatorDiameter
        )
        XCTAssertLessThanOrEqual(
            NotchCompactLayout.indicatorDiameter,
            NotchCompactLayout.sideWingWidth
        )
    }

    func testQuotaIndicatorMotionRunsOnlyWhileATaskIsRunning() {
        XCTAssertTrue(
            QuotaIndicatorMotion.shouldAnimate(isTaskRunning: true, reduceMotion: false)
        )
        XCTAssertFalse(
            QuotaIndicatorMotion.shouldAnimate(isTaskRunning: false, reduceMotion: false)
        )
        XCTAssertFalse(
            QuotaIndicatorMotion.shouldAnimate(isTaskRunning: true, reduceMotion: true)
        )
    }

    func testRunningRingGradientCompletesOneFullOrbit() {
        XCTAssertEqual(QuotaRingGradientMotion.restingAngle, -90)
        XCTAssertEqual(QuotaRingGradientMotion.flowingAngle, 270)
        XCTAssertEqual(
            QuotaRingGradientMotion.flowingAngle - QuotaRingGradientMotion.restingAngle,
            360
        )
        XCTAssertGreaterThan(QuotaRingGradientMotion.duration, 0)
    }

    func testRunningRingGradientChangesAngleAcrossAnimationTimeline() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let quarterTurn = start.addingTimeInterval(
            QuotaRingGradientMotion.duration / 4
        )

        XCTAssertEqual(
            QuotaRingGradientMotion.angle(at: start, isAnimating: true),
            QuotaRingGradientMotion.restingAngle,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            QuotaRingGradientMotion.angle(at: quarterTurn, isAnimating: true),
            0,
            accuracy: 0.0001
        )
        XCTAssertNotEqual(
            QuotaRingGradientMotion.angle(at: start, isAnimating: true),
            QuotaRingGradientMotion.angle(at: quarterTurn, isAnimating: true)
        )
    }

    func testStoppedOrReducedMotionRingKeepsGradientAtRest() {
        let later = Date(timeIntervalSinceReferenceDate: 123.45)

        XCTAssertEqual(
            QuotaRingGradientMotion.angle(at: later, isAnimating: false),
            QuotaRingGradientMotion.restingAngle
        )
    }

    func testStoppedRingUsesSolidColorWhileRunningRingUsesGradient() {
        XCTAssertEqual(QuotaRingAppearance.colorMode(for: .running), .gradient)
        XCTAssertEqual(QuotaRingAppearance.colorMode(for: .idle), .solid)
        XCTAssertEqual(QuotaRingAppearance.colorMode(for: .completed), .solid)
    }

    func testRecentConversationLimitOffersOneThroughFiveAndFallsBackToTwo() {
        XCTAssertEqual(
            RecentConversationLimit.allCases.map(\.rawValue),
            [1, 2, 3, 4, 5]
        )
        XCTAssertEqual(
            RecentConversationLimit.fromStoredValue(99),
            .two
        )
    }

    func testVisibleNotchSurfaceIsAlwaysBlackAndHiddenCanvasStaysClear() {
        XCTAssertEqual(
            NotchSurfaceMaterial.resolve(isHidden: false),
            .black
        )
        XCTAssertEqual(
            NotchSurfaceMaterial.resolve(isHidden: true),
            .clear
        )
    }

}
