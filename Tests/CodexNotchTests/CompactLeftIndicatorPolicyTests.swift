import XCTest
@testable import CodexNotch

final class CompactLeftIndicatorPolicyTests: XCTestCase {
    func testOffHidesTheEntireLeftLaneEvenWhenFiveHourQuotaExists() {
        for mode in [NotchLayoutMode.notch, .floatingBar] {
            for hasQuota in [false, true] {
                XCTAssertEqual(CompactLeftIndicatorPolicy.content(
                    layoutMode: mode, hasFiveHourWindow: hasQuota, iconStyle: .off
                ), .hidden)
                for style in [StatusIconStyle.codex, .chatGPT] {
                    XCTAssertEqual(CompactLeftIndicatorPolicy.content(
                        layoutMode: mode, hasFiveHourWindow: hasQuota, iconStyle: style
                    ), hasQuota ? .fiveHourQuota : .appStatus)
                }
            }
        }
    }

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
