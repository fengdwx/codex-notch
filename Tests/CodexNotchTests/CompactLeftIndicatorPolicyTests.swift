import XCTest
@testable import CodexNotch

final class CompactLeftIndicatorPolicyTests: XCTestCase {
    func testPhysicalNotchUsesReturnedFiveHourWindowInTheLeftLane() {
        XCTAssertEqual(
            CompactLeftIndicatorPolicy.content(
                layoutMode: .notch,
                hasFiveHourWindow: true
            ),
            .fiveHourQuota
        )
    }

    func testPhysicalNotchRestoresStatusIconWithoutFiveHourWindow() {
        XCTAssertEqual(
            CompactLeftIndicatorPolicy.content(
                layoutMode: .notch,
                hasFiveHourWindow: false
            ),
            .appStatus
        )
    }

    func testFloatingBarUsesFiveHourQuotaAndRestoresStatusWithoutIt() {
        XCTAssertEqual(
            CompactLeftIndicatorPolicy.content(
                layoutMode: .floatingBar,
                hasFiveHourWindow: true
            ),
            .fiveHourQuota
        )
        XCTAssertEqual(
            CompactLeftIndicatorPolicy.content(
                layoutMode: .floatingBar,
                hasFiveHourWindow: false
            ),
            .appStatus
        )
    }
}
