import AppKit
import SwiftUI
import XCTest
@testable import CodexNotch

final class NotchHoverFeedbackTests: XCTestCase {
    func testHoverKeepsTopCenterAndReservesShadowSpaceOnlyWhileActive() {
        let compact = CGRect(x: 854, y: 1050, width: 212, height: 30)
        let hover = NotchPresentationMotion.hoverSurfaceSize(compact.size, isHovering: true, animationsEnabled: true)
        XCTAssertEqual(hover, CGSize(width: 216, height: 32))
        let canvas = NotchPresentationMotion.settledCanvasFrame(
            for: compact, isExpanded: false, isHovering: true, animationsEnabled: true
        )
        XCTAssertEqual(canvas.midX, compact.midX)
        XCTAssertEqual(canvas.maxY, compact.maxY)
        XCTAssertEqual(canvas.width, 240)
        XCTAssertEqual(canvas.height, 44)
        for (hovering, enabled) in [(false, true), (true, false)] {
            XCTAssertEqual(NotchPresentationMotion.hoverSurfaceSize(compact.size, isHovering: hovering, animationsEnabled: enabled), compact.size)
            XCTAssertEqual(NotchPresentationMotion.settledCanvasFrame(for: compact, isExpanded: false, isHovering: hovering, animationsEnabled: enabled), compact)
        }
        XCTAssertEqual(NotchPresentationMotion.hoverSurfaceSize(.zero, isHovering: true, animationsEnabled: true), .zero)
    }

    @MainActor
    func testAbortedHoverAndCollapseReclaimCanvasWithoutCuttingOffReentry() throws {
        _ = NSApplication.shared
        let controller = NotchWindowController()
        controller.setRootView(Color.clear)
        let panel = try XCTUnwrap(controller.window)
        defer { controller.hideNotchPanel() }
        let compact = CGRect(x: -10_000, y: 1_000, width: 212, height: 30)
        let expanded = CGRect(x: -10_104, y: 750, width: 420, height: 280)
        let layout = NotchLayout(mode: .floatingBar, centerX: compact.midX, hoverSensorFrame: compact,
                                 compactFrame: compact, quotaExpandedFrame: expanded, expandedFrame: expanded)
        let closed = NotchPresentationState.quotaCompact(nil)
        let opened = NotchPresentationState.expanded(ExpandedContent(sessions: [], conversations: [], headerConversation: nil, usage: nil))
        controller.prepare(layout: layout, state: closed, animationsEnabled: false)
        let entered = controller.prepare(layout: layout, state: closed, isHovering: true)
        let hoverCanvas = panel.frame
        XCTAssertFalse(controller.isCardTransitionInFlight)
        XCTAssertEqual(controller.prepare(layout: layout, state: closed, isHovering: true), entered)
        let exited = controller.prepare(layout: layout, state: closed)
        controller.settleFrame(layout: layout, state: closed, animationWillComplete: true)
        XCTAssertEqual(panel.frame, hoverCanvas, "A short hover must finish shrinking before its canvas is reclaimed")
        controller.finishSurfaceAnimation(identifier: entered, targetFrame: compact)
        XCTAssertEqual(panel.frame, hoverCanvas)
        controller.finishSurfaceAnimation(identifier: exited, targetFrame: compact)
        XCTAssertEqual(panel.frame, compact)

        let opening = controller.prepare(layout: layout, state: opened)
        XCTAssertTrue(controller.isCardTransitionInFlight)
        controller.finishSurfaceAnimation(identifier: opening, targetFrame: expanded)
        XCTAssertFalse(controller.isCardTransitionInFlight)
        XCTAssertEqual(panel.frame, CGRect(x: -10_116, y: 738, width: 444, height: 292))
        let closing = controller.prepare(layout: layout, state: closed)
        controller.settleFrame(layout: layout, state: closed, animationWillComplete: true)
        XCTAssertTrue(controller.isCardTransitionInFlight)
        let reopening = controller.prepare(layout: layout, state: opened)
        let reopenedCanvas = panel.frame
        controller.finishSurfaceAnimation(identifier: closing, targetFrame: compact)
        XCTAssertEqual(panel.frame, reopenedCanvas)
        controller.finishSurfaceAnimation(identifier: reopening, targetFrame: expanded)
        controller.prepare(layout: layout, state: closed, isHovering: true, animationsEnabled: false)
        controller.settleFrame(layout: layout, state: closed, animationsEnabled: false)
        XCTAssertEqual(panel.frame, compact, "Disabled motion must immediately remove decorative clearance")
    }
}
