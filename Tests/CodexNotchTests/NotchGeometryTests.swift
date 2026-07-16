import AppKit
import XCTest
@testable import CodexNotch

final class NotchGeometryTests: XCTestCase {
    func testCompactFrameIsCenteredBetweenAuxiliaryAreas() {
        let metrics = NotchScreenMetrics(
            frame: NSRect(x: 0, y: 0, width: 3024, height: 1964),
            visibleFrame: NSRect(x: 0, y: 0, width: 3024, height: 1964),
            safeAreaInsets: NSEdgeInsets(top: 74, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: NSRect(x: 0, y: 1900, width: 600, height: 64),
            auxiliaryTopRightArea: NSRect(x: 2424, y: 1900, width: 600, height: 64)
        )

        let layout = NotchGeometry.layout(
            metrics: metrics,
            compactSize: NSSize(width: 420, height: 42),
            expandedSize: NSSize(width: 720, height: 180)
        )

        XCTAssertEqual(layout.mode, .notch)
        XCTAssertEqual(layout.hoverSensorFrame.midX, 1512, accuracy: 0.1)
        XCTAssertEqual(layout.compactFrame.midX, 1512, accuracy: 0.1)
        XCTAssertEqual(layout.quotaExpandedFrame.midX, 1512, accuracy: 0.1)
        XCTAssertEqual(layout.expandedFrame.midX, 1512, accuracy: 0.1)
    }

    func testExpandedFrameStaysInsideVisibleScreenBounds() {
        let metrics = NotchScreenMetrics(
            frame: NSRect(x: 0, y: 0, width: 1200, height: 800),
            visibleFrame: NSRect(x: 0, y: 0, width: 1200, height: 800),
            safeAreaInsets: NSEdgeInsets(top: 40, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: NSRect(x: 0, y: 760, width: 200, height: 40),
            auxiliaryTopRightArea: NSRect(x: 1000, y: 760, width: 200, height: 40)
        )

        let layout = NotchGeometry.layout(
            metrics: metrics,
            compactSize: NSSize(width: 420, height: 42),
            expandedSize: NSSize(width: 1600, height: 180)
        )

        XCTAssertGreaterThanOrEqual(layout.expandedFrame.minX, metrics.visibleFrame.minX)
        XCTAssertLessThanOrEqual(layout.expandedFrame.maxX, metrics.visibleFrame.maxX)
        XCTAssertEqual(layout.expandedFrame.maxY, metrics.frame.maxY, accuracy: 0.1)
    }

    func testDefaultCompactFrameStaysCloseToNotchGap() {
        let metrics = NotchScreenMetrics(
            frame: NSRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: NSRect(x: 0, y: 0, width: 1512, height: 949),
            safeAreaInsets: NSEdgeInsets(top: 32, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: NSRect(x: 0, y: 950, width: 663, height: 32),
            auxiliaryTopRightArea: NSRect(x: 848, y: 950, width: 664, height: 32)
        )

        let layout = NotchGeometry.layout(metrics: metrics)

        XCTAssertEqual(layout.mode, .notch)
        XCTAssertEqual(layout.hoverSensorFrame.minX, 663, accuracy: 0.1)
        XCTAssertEqual(layout.hoverSensorFrame.width, 185, accuracy: 0.1)
        XCTAssertEqual(layout.hoverSensorFrame.height, 32, accuracy: 0.1)
        XCTAssertEqual(layout.hoverSensorFrame.maxY, 982, accuracy: 0.1)
        XCTAssertEqual(layout.compactFrame.width, 261, accuracy: 0.1)
        XCTAssertEqual(layout.compactFrame.height, 32, accuracy: 0.1)
        XCTAssertEqual(layout.compactFrame.midX, 755.5, accuracy: 0.1)
        XCTAssertEqual(layout.compactFrame.maxY, 982, accuracy: 0.1)
        XCTAssertEqual(layout.quotaExpandedFrame.width, 420, accuracy: 0.1)
        XCTAssertEqual(layout.quotaExpandedFrame.height, 94, accuracy: 0.1)
        XCTAssertEqual(layout.quotaExpandedFrame.maxY, 982, accuracy: 0.1)
        XCTAssertEqual(layout.expandedFrame.width, 420, accuracy: 0.1)
        XCTAssertEqual(layout.expandedFrame.height, 150, accuracy: 0.1)
        XCTAssertEqual(layout.expandedFrame.maxY, 982, accuracy: 0.1)
    }

    func testMissingAuxiliaryAreasUseMenuBarFallback() {
        let metrics = NotchScreenMetrics(
            frame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
            safeAreaInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil
        )

        XCTAssertEqual(NotchGeometry.layout(metrics: metrics).mode, .menuBarFallback)
    }
}
