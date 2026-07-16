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

}
