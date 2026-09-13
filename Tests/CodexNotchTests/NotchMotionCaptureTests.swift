import AppKit
import SwiftUI
import XCTest
@testable import CodexNotch

/// Opt-in visual fixture using the production view and panel, with synthetic data.
/// NOTCH_MOTION_CAPTURE=/absolute/path.mov swift test --filter NotchMotionCaptureTests
/// Add NOTCH_MOTION_CAPTURE_SCENARIO=dense, empty, completed or signature for visual checks.
final class NotchMotionCaptureTests: XCTestCase {
    @MainActor
    func testRecordOpeningCollapseAndReentry() async throws {
        guard let output = ProcessInfo.processInfo.environment["NOTCH_MOTION_CAPTURE"] else {
            throw XCTSkip("Set NOTCH_MOTION_CAPTURE to record the native motion fixture")
        }
        _ = NSApplication.shared
        let screen = try XCTUnwrap(NSScreen.main)
        let scenario = ProcessInfo.processInfo.environment["NOTCH_MOTION_CAPTURE_SCENARIO"]
        let dense = scenario == "dense"
        let empty = scenario == "empty"
        let completed = scenario == "completed"
        let signature = scenario == "signature"
        let expandedHeight = dense
            ? NotchExpandedLayout.taskContentSize(conversationCount: 5, isResetScheduleExpanded: true,
                                                  resetCreditCount: 3, hasFiveHourWindow: true).height + 30
            : (empty ? NotchExpandedLayout.quotaContentSize().height + 30 : 320)
        let area = NSRect(x: screen.frame.midX - 240, y: screen.frame.maxY - expandedHeight - 210,
                          width: 480, height: expandedHeight + 70)
        let backdrop = NSPanel(contentRect: area, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        backdrop.backgroundColor = NSColor(white: 0.92, alpha: 1)
        backdrop.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1)
        backdrop.hidesOnDeactivate = false
        backdrop.hasShadow = false
        backdrop.orderFrontRegardless()
        let compact = NSRect(x: area.midX - 106, y: area.maxY - 30, width: 212, height: 30)
        let expanded = NSRect(x: area.midX - 210, y: area.maxY - expandedHeight, width: 420, height: expandedHeight)
        let layout = NotchLayout(mode: .floatingBar, centerX: area.midX, hoverSensorFrame: compact,
                                 compactFrame: compact, quotaExpandedFrame: expanded, expandedFrame: expanded)
        let now = Date(timeIntervalSince1970: 1_789_200_000)
        let titles = dense
            ? ["核对额度与重置时间，检查较长的中文任务标题是否仍然清晰可读", "Review API changes",
               "检查刘海动画与任务状态", "验证无额度时的提示", "完成中文排版检查"]
            : ["Build the dashboard", "Review the animation"]
        let sessions = titles.enumerated().map { index, title in
            SessionActivity(threadID: "preview-\(index)", turnID: "preview", title: title, cwd: "/demo/project",
                            originator: nil, startedAt: now.addingTimeInterval(-120), lastActivityAt: now)
        }
        let windows = [UsageWindow(id: "weekly", kind: .weekly, usedPercent: 13,
                                   resetAt: now.addingTimeInterval(86_400))]
            + (dense ? [UsageWindow(id: "five-hour", kind: .rolling(hours: 5), usedPercent: 95,
                                   resetAt: now.addingTimeInterval(14_460))] : [])
        let credits = dense ? [ResetCredit(id: "soon", expiresAt: now.addingTimeInterval(7_200)),
                               ResetCredit(id: "later", expiresAt: now.addingTimeInterval(172_800)),
                               ResetCredit(id: "unknown")] : []
        let usage: UsageSnapshot? = empty ? nil : UsageSnapshot(
            windows: windows, resetCreditsAvailable: credits.count, resetCredits: credits, fetchedAt: now
        )
        let conversations = sessions.enumerated().map { index, session in
            ConversationSummary(session: session, activity: completed || (dense && index > 1)
                                ? .completed(completedAt: now.addingTimeInterval(-300))
                                : .running(startedAt: session.startedAt))
        }
        let content = ExpandedContent(sessions: empty || completed ? [] : Array(sessions.prefix(dense ? 2 : sessions.count)),
                                      conversations: empty ? [] : conversations,
                                      headerConversation: nil, usage: usage)
        let closed = empty ? NotchPresentationState.quotaCompact(nil)
            : (completed ? .completedCompact(sessions[0], usage: usage)
               : .workingCompact(primary: sessions[0], count: content.sessions.count, usage: usage))
        let opened = NotchPresentationState.expanded(content)
        let model = NotchViewModel()
        let controller = NotchWindowController()
        let suite = "NotchMotionCapture.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        if dense || signature {
            if dense { defaults.set("zh-Hans", forKey: AppLanguage.storageKey) }
            if signature {
                defaults.set(FloatingCenterStyle.signature.rawValue, forKey: FloatingCenterStyle.storageKey)
                defaults.set("专注当下", forKey: FloatingCenterText.storageKey)
            }
            controller.setRootView(NotchView(model: model).defaultAppStorage(defaults))
        } else {
            controller.setRootView(NotchView(model: model))
        }
        defer { controller.hideNotchPanel(); backdrop.orderOut(nil) }
        func show(_ state: NotchPresentationState, animated: Bool = true) {
            let target = layout.frame(for: state)
            let identifier = controller.prepare(layout: layout, state: state, animationsEnabled: animated)
            let started = model.update(state: state, now: now, layoutMode: .floatingBar,
                                      compactWidth: compact.width, compactHeight: compact.height,
                                      surfaceSize: target.size, isResetScheduleExpanded: dense,
                                      animationsEnabled: animated,
                                      onSurfaceAnimationCompleted: {
                controller.finishSurfaceAnimation(identifier: identifier, targetFrame: target)
            })
            controller.settleFrame(layout: layout, state: state, animationsEnabled: animated, animationWillComplete: started)
        }
        show(closed, animated: false)
        try await Task.sleep(for: .milliseconds(300))
        if signature { show(closed) }
        let recording = Process()
        recording.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        let top = try XCTUnwrap(NSScreen.screens.first).frame.maxY
        recording.arguments = ["-v", "-V", signature ? "18" : "8", "-R",
                               "\(Int(area.minX)),\(Int(top - area.maxY)),\(Int(area.width)),\(Int(area.height))", output]
        try recording.run()
        defer { if recording.isRunning { recording.terminate() } }
        try await Task.sleep(for: .seconds(1))
        if signature {
            // Repeated model updates must preserve a full shimmer cycle.
            for _ in 0..<5 {
                show(closed)
                try await Task.sleep(for: .seconds(1))
            }
            show(.completedCompact(sessions[0], usage: usage))
            try await Task.sleep(for: .seconds(4))
            show(.quotaCompact(usage))
            try await Task.sleep(for: .seconds(4))
            show(closed, animated: false)
            try await Task.sleep(for: .seconds(2))
            show(closed)
            try await Task.sleep(for: .milliseconds(2300))
            XCTAssertEqual(controller.window?.frame, compact)
            // ScreenCaptureKit startup/finalization can outlast the requested
            // capture duration; do not terminate it before the movie is saved.
            for _ in 0..<100 where recording.isRunning {
                try await Task.sleep(for: .milliseconds(100))
            }
            XCTAssertFalse(recording.isRunning, "Screen recording did not finish within the bounded finalization period")
            if !recording.isRunning {
                XCTAssertEqual(recording.terminationStatus, 0)
            }
            XCTAssertTrue(FileManager.default.fileExists(atPath: output))
            return
        }
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
