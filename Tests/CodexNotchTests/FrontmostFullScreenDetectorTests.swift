import XCTest
@testable import CodexNotch

final class FullScreenVisibilityTests: XCTestCase {
    func testFrontmostFullScreenWindowDoesNotOverrideRequestedVisibility() {
        XCTAssertTrue(
            NotchPanelVisibilityPolicy.shouldRestoreAfterApplicationSwitch(
                panelIsRequested: true,
                layoutMode: .notch,
                displayIsEnabled: true
            )
        )
    }

    func testNativeFullScreenSpaceAllowsTheNotchPanel() {
        let panel = NotchPanel(contentRect: .zero)

        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertFalse(panel.collectionBehavior.contains(.fullScreenNone))
    }
}
