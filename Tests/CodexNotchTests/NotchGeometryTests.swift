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
        XCTAssertEqual(layout.compactFrame.midX, 1512, accuracy: 0.1)
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
