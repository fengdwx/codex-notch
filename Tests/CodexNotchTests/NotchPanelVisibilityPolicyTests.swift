import XCTest
@testable import CodexNotch

final class NotchPanelVisibilityPolicyTests: XCTestCase {
    func testNotchPanelIsRestoredAfterAnAppSwitch() {
        XCTAssertTrue(
            NotchPanelVisibilityPolicy.shouldRestoreAfterApplicationSwitch(
                panelIsRequested: true,
                layoutMode: .notch
            )
        )
    }

    func testMenuBarFallbackDoesNotRestoreANotchPanelAfterAnAppSwitch() {
        XCTAssertFalse(
            NotchPanelVisibilityPolicy.shouldRestoreAfterApplicationSwitch(
                panelIsRequested: true,
                layoutMode: .menuBarFallback
            )
        )
    }

    func testAnUnrequestedNotchPanelDoesNotReappearAfterAnAppSwitch() {
        XCTAssertFalse(
            NotchPanelVisibilityPolicy.shouldRestoreAfterApplicationSwitch(
                panelIsRequested: false,
                layoutMode: .notch
            )
        )
    }
}
