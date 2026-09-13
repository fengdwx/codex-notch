import AppKit
import SwiftUI
import XCTest
@testable import CodexNotch

final class HiddenLeftWingTests: XCTestCase {
    private func metrics(notched: Bool) -> NotchScreenMetrics {
        NotchScreenMetrics(
            frame: NSRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: NSRect(x: 0, y: 0, width: 1512, height: 950),
            safeAreaInsets: NSEdgeInsets(top: notched ? 32 : 0, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: notched ? NSRect(x: 0, y: 950, width: 663, height: 32) : nil,
            auxiliaryTopRightArea: notched ? NSRect(x: 848, y: 950, width: 664, height: 32) : nil
        )
    }

    func testOffReleasesLeftMenuSpaceWithoutMovingRightQuotaOrExpandedCard() {
        for notched in [true, false] {
            let on = NotchGeometry.layout(metrics: metrics(notched: notched))
            let off = NotchGeometry.layout(metrics: metrics(notched: notched), leftIndicatorEnabled: false)
            let visible = off.frame(for: .quotaCompact(nil))
            XCTAssertEqual(visible.minX, notched ? 663 : on.compactFrame.minX + 30)
            XCTAssertEqual(visible.maxX, on.compactFrame.maxX)
            XCTAssertEqual(visible.maxY, on.compactFrame.maxY)
            XCTAssertFalse(visible.contains(CGPoint(x: on.compactFrame.minX + 5, y: visible.midY)))
            XCTAssertEqual(off.expandedFrame, on.expandedFrame)
            XCTAssertEqual(off.quotaExpandedFrame, on.quotaExpandedFrame)
            XCTAssertEqual(off.compactFrame, on.compactFrame, "Content keeps its original coordinate system")
            let sensor = off.frame(for: .hidden)
            XCTAssertGreaterThanOrEqual(sensor.minX, visible.minX)
            XCTAssertEqual(sensor.maxY, visible.maxY)
        }
    }

    func testCroppedSurfaceDoesNotDrawOrHitTestInReleasedSpace() {
        let rect = CGRect(x: 0, y: 0, width: 257, height: 32)
        let shape = NotchSurfaceShape(layoutMode: .notch, shoulderDepth: 6, bottomRadius: 14, leadingInset: 36)
        XCTAssertEqual(shape.path(in: rect).boundingRect.minX, 36)
        XCTAssertFalse(shape.path(in: rect).contains(CGPoint(x: 20, y: 16)))
        XCTAssertTrue(shape.path(in: rect).contains(CGPoint(x: 230, y: 16)))
    }

    @MainActor
    func testPanelReclaimsTheLeftWingAndKeepsHostingCoordinatesAcrossExpansion() throws {
        _ = NSApplication.shared
        let controller = NotchWindowController()
        controller.setRootView(Color.clear)
        let panel = try XCTUnwrap(controller.window)
        defer { controller.hideNotchPanel() }
        let compact = CGRect(x: -10_000, y: 1_000, width: 257, height: 32)
        let expanded = CGRect(x: compact.midX - 210, y: 750, width: 420, height: 282)
        var layout = NotchLayout(mode: .notch, centerX: compact.midX,
                                 hoverSensorFrame: compact.insetBy(dx: 36, dy: 0),
                                 compactFrame: compact, quotaExpandedFrame: expanded, expandedFrame: expanded)
        let closed = NotchPresentationState.quotaCompact(nil)
        let opened = NotchPresentationState.expanded(ExpandedContent(sessions: [], conversations: [], headerConversation: nil, usage: nil))
        controller.prepare(layout: layout, state: closed, animationsEnabled: false)
        XCTAssertEqual(panel.frame, compact)
        layout.compactLeadingInset = 36
        let offFrame = layout.frame(for: closed)

        func assertContentAnchored() throws {
            let hosting = try XCTUnwrap(panel.contentView?.subviews.first)
            XCTAssertEqual(panel.frame.minX + hosting.frame.midX, compact.midX, accuracy: 0.01)
        }

        let hiding = controller.prepare(layout: layout, state: closed)
        controller.settleFrame(layout: layout, state: closed, animationWillComplete: true)
        controller.finishSurfaceAnimation(identifier: hiding, targetFrame: offFrame)
        XCTAssertEqual(panel.frame, offFrame, "The removed wing must no longer be inside the actual NSPanel")
        try assertContentAnchored()
        let opening = controller.prepare(layout: layout, state: opened)
        try assertContentAnchored()
        controller.finishSurfaceAnimation(identifier: opening, targetFrame: expanded)
        let closing = controller.prepare(layout: layout, state: closed)
        controller.settleFrame(layout: layout, state: closed, animationWillComplete: true)
        let reopening = controller.prepare(layout: layout, state: opened)
        let canvas = panel.frame
        controller.finishSurfaceAnimation(identifier: closing, targetFrame: offFrame)
        XCTAssertEqual(panel.frame, canvas, "A stale collapse cannot clip a reopened card")
        controller.finishSurfaceAnimation(identifier: reopening, targetFrame: expanded)
        controller.prepare(layout: layout, state: closed, animationsEnabled: false)
        controller.settleFrame(layout: layout, state: closed, animationsEnabled: false)
        XCTAssertEqual(panel.frame, offFrame)
        try assertContentAnchored()
        layout.compactLeadingInset = 0
        controller.prepare(layout: layout, state: closed, animationsEnabled: false)
        XCTAssertEqual(panel.frame, compact)
        try assertContentAnchored()
    }
}
