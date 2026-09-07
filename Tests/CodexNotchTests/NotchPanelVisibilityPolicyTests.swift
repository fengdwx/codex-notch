import XCTest
@testable import CodexNotch

final class NotchPanelVisibilityPolicyTests: XCTestCase {
    func testNotchPanelIsRestoredAfterAnAppSwitch() {
        XCTAssertTrue(
            NotchPanelVisibilityPolicy.shouldRestoreAfterApplicationSwitch(
                panelIsRequested: true,
                layoutMode: .notch,
                displayIsEnabled: true
            )
        )
    }

    func testFullScreenAppSwitchStillRestoresTheRequestedPanel() {
        XCTAssertTrue(
            NotchPanelVisibilityPolicy.shouldRestoreAfterApplicationSwitch(
                panelIsRequested: true,
                layoutMode: .notch,
                displayIsEnabled: true
            )
        )
    }

    func testMenuBarFallbackDoesNotRestoreANotchPanelAfterAnAppSwitch() {
        XCTAssertFalse(
            NotchPanelVisibilityPolicy.shouldRestoreAfterApplicationSwitch(
                panelIsRequested: true,
                layoutMode: .menuBarFallback,
                displayIsEnabled: true
            )
        )
    }

    func testFloatingBarIsRestoredAfterAnAppSwitch() {
        XCTAssertTrue(
            NotchPanelVisibilityPolicy.shouldRestoreAfterApplicationSwitch(
                panelIsRequested: true,
                layoutMode: .floatingBar,
                displayIsEnabled: true
            )
        )
    }

    func testDisabledFloatingBarKeepsTheHoverRecoveryPath() {
        XCTAssertFalse(
            NotchPanelVisibilityPolicy.shouldUseMenuBarFallback(
                layoutMode: .floatingBar,
                displayIsEnabled: false
            )
        )
        XCTAssertFalse(
            NotchPanelVisibilityPolicy.shouldUseMenuBarFallback(
                layoutMode: .floatingBar,
                displayIsEnabled: true
            )
        )
    }

    func testAnUnrequestedNotchPanelDoesNotReappearAfterAnAppSwitch() {
        XCTAssertFalse(
            NotchPanelVisibilityPolicy.shouldRestoreAfterApplicationSwitch(
                panelIsRequested: false,
                layoutMode: .notch,
                displayIsEnabled: true
            )
        )
    }

    func testHiddenRecoverySensorRestoresAfterAnAppSwitch() {
        XCTAssertTrue(
            NotchPanelVisibilityPolicy.shouldRestoreAfterApplicationSwitch(
                panelIsRequested: true,
                layoutMode: .notch,
                displayIsEnabled: false
            )
        )
    }

    func testHiddenDisplayKeepsOnlyTheNotchHoverSensor() {
        XCTAssertTrue(
            NotchPanelVisibilityPolicy.shouldKeepHiddenHoverSensor(
                layoutMode: .notch,
                displayIsEnabled: false
            )
        )
        XCTAssertFalse(
            NotchPanelVisibilityPolicy.shouldKeepHiddenHoverSensor(
                layoutMode: .menuBarFallback,
                displayIsEnabled: false
            )
        )
        XCTAssertFalse(
            NotchPanelVisibilityPolicy.shouldKeepHiddenHoverSensor(
                layoutMode: .notch,
                displayIsEnabled: true
            )
        )
        XCTAssertTrue(
            NotchPanelVisibilityPolicy.shouldKeepHiddenHoverSensor(
                layoutMode: .floatingBar,
                displayIsEnabled: false
            )
        )
    }

    func testHiddenFloatingSensorRestoresOnlyWhenRequested() {
        for requested in [true, false] {
            XCTAssertEqual(
                NotchPanelVisibilityPolicy.shouldRestoreAfterApplicationSwitch(
                    panelIsRequested: requested,
                    layoutMode: .floatingBar,
                    displayIsEnabled: false
                ),
                requested
            )
        }
    }

    func testNotchPanelJoinsAnotherAppsFullScreenSpace() {
        let panel = NotchPanel(contentRect: .zero)

        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertFalse(panel.collectionBehavior.contains(.fullScreenNone))
    }
}
