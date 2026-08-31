import XCTest
@testable import CodexNotch

final class CompactLeftIndicatorPolicyTests: XCTestCase {
    func testPhysicalNotchUsesReturnedFiveHourWindowInTheLeftLane() {
        XCTAssertTrue(
            CompactLeftIndicatorPolicy.showsFiveHourQuota(
                layoutMode: .notch,
                hasFiveHourWindow: true
            )
        )
        XCTAssertFalse(
            CompactLeftIndicatorPolicy.showsFiveHourQuota(
                layoutMode: .notch,
                hasFiveHourWindow: false
            )
        )
    }

    func testFloatingBarKeepsItsSeparateStatusLane() {
        XCTAssertFalse(
            CompactLeftIndicatorPolicy.showsFiveHourQuota(
                layoutMode: .floatingBar,
                hasFiveHourWindow: true
            )
        )
    }
}
