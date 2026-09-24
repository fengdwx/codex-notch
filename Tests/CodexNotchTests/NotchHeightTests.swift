import AppKit
import XCTest
@testable import CodexNotch

final class NotchHeightTests: XCTestCase {
    // Synthetic screen metrics exercise both sides of the former 28...32pt
    // clamp. These values do not identify particular MacBook models.
    private func metrics(height: CGFloat, menuBarHeight: CGFloat? = nil) -> NotchScreenMetrics {
        let screen = NSRect(x: -1512, y: 200, width: 1512, height: 982)
        return NotchScreenMetrics(
            frame: screen,
            visibleFrame: NSRect(
                x: screen.minX, y: screen.minY, width: screen.width,
                height: screen.height - (menuBarHeight ?? height + 1)
            ),
            safeAreaInsets: NSEdgeInsets(top: height, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: NSRect(
                x: screen.minX, y: screen.maxY - height, width: 663.5, height: height
            ),
            auxiliaryTopRightArea: NSRect(
                x: screen.minX + 848.5, y: screen.maxY - height, width: 663.5, height: height
            )
        )
    }

    func testCompactWingsAndHoverSensorMatchMeasuredCameraHeight() {
        for height in [CGFloat(24), 28, 29, 32, 37, 38] {
            let screen = metrics(height: height)
            for leftEnabled in [true, false] {
                let layout = NotchGeometry.layout(metrics: screen, leftIndicatorEnabled: leftEnabled)

                XCTAssertEqual(layout.mode, .notch)
                XCTAssertEqual(layout.compactFrame.height, height, accuracy: 0.001)
                XCTAssertEqual(layout.visibleCompactFrame.height, height, accuracy: 0.001)
                XCTAssertEqual(layout.hoverSensorFrame.height, height, accuracy: 0.001)
                XCTAssertEqual(layout.compactFrame.maxY, screen.frame.maxY, accuracy: 0.001)
                XCTAssertEqual(layout.compactFrame.minY, screen.frame.maxY - height, accuracy: 0.001)
                XCTAssertEqual(layout.hoverSensorFrame.minY, layout.compactFrame.minY, accuracy: 0.001)
                XCTAssertEqual(layout.compactFrame.midX, screen.frame.midX, accuracy: 0.001)
                XCTAssertEqual(layout.compactFrame.width, 257, accuracy: 0.001)
                XCTAssertEqual(layout.frame(for: .hidden), layout.hoverSensorFrame)

                // Growing the camera attachment must not consume detail space
                // or move the expanded card above the screen's top edge.
                XCTAssertEqual(layout.quotaExpandedFrame.maxY, screen.frame.maxY, accuracy: 0.001)
                XCTAssertEqual(layout.expandedFrame.maxY, screen.frame.maxY, accuracy: 0.001)
                XCTAssertEqual(layout.quotaExpandedFrame.height - height,
                               NotchExpandedLayout.quotaContentHeight, accuracy: 0.001)
                XCTAssertEqual(layout.expandedFrame.height - height,
                               NotchExpandedLayout.twoConversationContentHeight, accuracy: 0.001)
            }
        }
    }

    func testMenuBarVisibilityDoesNotChangePhysicalNotchHeight() {
        let shown = NotchGeometry.layout(metrics: metrics(height: 38, menuBarHeight: 39))
        let hidden = NotchGeometry.layout(metrics: metrics(height: 38, menuBarHeight: 0))

        XCTAssertEqual(shown.compactFrame.height, 38)
        XCTAssertEqual(hidden, shown)
    }

    func testDisplayChangesRestoreTheCurrentCameraHeightAfterFloatingMode() {
        let standard = NotchGeometry.layout(metrics: metrics(height: 32))
        let scaled = NotchGeometry.layout(metrics: metrics(height: 38))
        let floating = NotchGeometry.layout(metrics: NotchScreenMetrics(
            frame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: NSRect(x: 0, y: 0, width: 1920, height: 1050),
            safeAreaInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil
        ))
        let restored = NotchGeometry.layout(metrics: metrics(height: 38))

        XCTAssertEqual(standard.compactFrame.height, 32)
        XCTAssertEqual(scaled.compactFrame.height, 38)
        XCTAssertEqual(floating.mode, .floatingBar)
        XCTAssertEqual(floating.compactFrame, NSRect(x: 854, y: 1050, width: 212, height: 30))
        XCTAssertEqual(restored, scaled)
        XCTAssertEqual(NotchGeometry.layout(metrics: metrics(height: 32)), standard)
    }

    func testMissingCameraInsetRetainsTheExistingFallbackHeight() {
        let layout = NotchGeometry.layout(metrics: metrics(height: 0))

        XCTAssertEqual(layout.compactFrame.height, 28)
        XCTAssertEqual(layout.hoverSensorFrame.height, 28)
    }
}
