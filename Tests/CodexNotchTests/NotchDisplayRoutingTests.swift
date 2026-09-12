import AppKit
import XCTest
@testable import CodexNotch

final class NotchDisplayRoutingTests: XCTestCase {
    // NOTCH-VISIBILITY-048 supersedes the former mirror-suppression contract.
    // These are the live Mi Monitor mirror-master metrics from the incident.
    private var mirrorMasterMetrics: NotchScreenMetrics {
        NotchScreenMetrics(
            frame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: NSRect(x: 0, y: 0, width: 1920, height: 1050),
            safeAreaInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil
        )
    }

    func testMirroredNoNotchCoordinateSpaceKeepsFloatingIslandAtScreenTop() {
        let layout = NotchGeometry.layout(metrics: mirrorMasterMetrics)

        XCTAssertEqual(layout.mode, .floatingBar)
        XCTAssertEqual(layout.compactFrame, NSRect(x: 854, y: 1050, width: 212, height: 30))
        XCTAssertFalse(
            NotchPanelVisibilityPolicy.shouldUseMenuBarFallback(
                layoutMode: layout.mode,
                displayIsEnabled: true
            )
        )
        XCTAssertEqual(layout.expandedFrame.maxY, layout.compactFrame.maxY)
        XCTAssertLessThan(layout.expandedFrame.minY, layout.compactFrame.minY)
    }

    func testMirroredIslandStillHonorsDisplayOffAndAppSwitchRecovery() {
        let layout = NotchGeometry.layout(metrics: mirrorMasterMetrics)

        XCTAssertTrue(
            NotchPanelVisibilityPolicy.shouldUseMenuBarFallback(
                layoutMode: layout.mode,
                displayIsEnabled: false
            )
        )
        XCTAssertTrue(
            NotchPanelVisibilityPolicy.shouldRestoreAfterApplicationSwitch(
                panelIsRequested: true,
                layoutMode: layout.mode,
                displayIsEnabled: true
            )
        )
        XCTAssertFalse(
            NotchPanelVisibilityPolicy.shouldRestoreAfterApplicationSwitch(
                panelIsRequested: true,
                layoutMode: layout.mode,
                displayIsEnabled: false
            )
        )
    }

    func testLeavingMirrorMasterUsesFreshPhysicalNotchGeometry() {
        let mirrored = NotchGeometry.layout(metrics: mirrorMasterMetrics)
        let physical = NotchGeometry.layout(metrics: NotchScreenMetrics(
            frame: NSRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: NSRect(x: 0, y: 0, width: 1512, height: 949),
            safeAreaInsets: NSEdgeInsets(top: 32, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: NSRect(x: 0, y: 950, width: 663, height: 32),
            auxiliaryTopRightArea: NSRect(x: 848, y: 950, width: 664, height: 32)
        ))

        XCTAssertEqual(physical.mode, .notch)
        XCTAssertEqual(physical.compactFrame.maxY, 982)
        XCTAssertEqual(physical.compactFrame.midX, 755.5)
        XCTAssertEqual(physical.compactFrame.width, 257)
        XCTAssertNotEqual(physical.compactFrame, mirrored.compactFrame)
        XCTAssertEqual(NotchGeometry.layout(metrics: mirrorMasterMetrics), mirrored)
    }
}
