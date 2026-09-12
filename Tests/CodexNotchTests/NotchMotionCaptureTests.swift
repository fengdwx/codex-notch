import AppKit
import SwiftUI
import XCTest
@testable import CodexNotch

/// Opt-in visual fixture using the production view and panel, with synthetic data.
/// NOTCH_MOTION_CAPTURE=/absolute/path.mov swift test --filter NotchMotionCaptureTests
final class NotchMotionCaptureTests: XCTestCase {
    @MainActor
    func testRecordOpeningCollapseAndReentry() async throws {
        guard let output = ProcessInfo.processInfo.environment["NOTCH_MOTION_CAPTURE"] else {
            throw XCTSkip("Set NOTCH_MOTION_CAPTURE to record the native motion fixture")
        }
        _ = NSApplication.shared
        let screen = try XCTUnwrap(NSScreen.main)
        let area = NSRect(x: screen.frame.midX - 240, y: screen.frame.maxY - 530, width: 480, height: 390)
        let backdrop = NSPanel(contentRect: area, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        backdrop.backgroundColor = NSColor(white: 0.92, alpha: 1)
        backdrop.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1)
        backdrop.hidesOnDeactivate = false
        backdrop.hasShadow = false
        backdrop.orderFrontRegardless()
        let compact = NSRect(x: area.midX - 106, y: area.maxY - 30, width: 212, height: 30)
        let expanded = NSRect(x: area.midX - 210, y: area.maxY - 320, width: 420, height: 320)
        let layout = NotchLayout(mode: .floatingBar, centerX: area.midX, hoverSensorFrame: compact,
                                 compactFrame: compact, quotaExpandedFrame: expanded, expandedFrame: expanded)
        let now = Date(timeIntervalSince1970: 1_789_200_000)
        let sessions = ["Build the dashboard", "Review the animation"].enumerated().map { index, title in
            SessionActivity(threadID: "preview-\(index)", turnID: "preview", title: title, cwd: "/demo/project",
                            originator: nil, startedAt: now.addingTimeInterval(-120), lastActivityAt: now)
        }
        let usage = UsageSnapshot(windows: [UsageWindow(id: "weekly", kind: .weekly, usedPercent: 13,
                                                      resetAt: now.addingTimeInterval(86_400))], resetCreditsAvailable: 0, fetchedAt: now)
        let content = ExpandedContent(sessions: sessions,
                                      conversations: sessions.map { ConversationSummary(session: $0, activity: .running(startedAt: $0.startedAt)) },
                                      headerConversation: nil, usage: usage)
        let closed = NotchPresentationState.workingCompact(primary: sessions[0], count: 2, usage: usage)
        let opened = NotchPresentationState.expanded(content)
        let model = NotchViewModel()
        let controller = NotchWindowController()
        controller.setRootView(NotchView(model: model))
        defer { controller.hideNotchPanel(); backdrop.orderOut(nil) }
        func show(_ state: NotchPresentationState, animated: Bool = true) {
            let target = layout.frame(for: state)
            let identifier = controller.prepare(layout: layout, state: state, animationsEnabled: animated)
            let started = model.update(state: state, now: now, layoutMode: .floatingBar,
                                      compactWidth: compact.width, compactHeight: compact.height,
                                      surfaceSize: target.size, animationsEnabled: animated,
                                      onSurfaceAnimationCompleted: {
                controller.finishSurfaceAnimation(identifier: identifier, targetFrame: target)
            })
            controller.settleFrame(layout: layout, state: state, animationsEnabled: animated, animationWillComplete: started)
        }
        show(closed, animated: false)
        try await Task.sleep(for: .milliseconds(300))
        let recording = Process()
        recording.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        let top = try XCTUnwrap(NSScreen.screens.first).frame.maxY
        recording.arguments = ["-v", "-V", "8", "-R",
                               "\(Int(area.minX)),\(Int(top - area.maxY)),\(Int(area.width)),\(Int(area.height))", output]
        try recording.run()
        defer { if recording.isRunning { recording.terminate() } }
        try await Task.sleep(for: .seconds(1))
        show(opened)
        try await Task.sleep(for: .milliseconds(1500))
        show(closed)
        try await Task.sleep(for: .milliseconds(1500))
        show(opened)
        try await Task.sleep(for: .milliseconds(1500))
        show(closed)
        try await Task.sleep(for: .milliseconds(140))
        show(opened)
        try await Task.sleep(for: .milliseconds(860))
        show(closed)
        try await Task.sleep(for: .milliseconds(1700))
        XCTAssertEqual(controller.window?.frame, compact)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output))
    }
}
