import AppKit
import QuartzCore
import SwiftUI
import XCTest
@testable import CodexNotch

final class FloatingCenterTests: XCTestCase {
    private struct CenterProbe: NSViewRepresentable {
        let view: NSView
        func makeNSView(context: Context) -> NSView { view }
        func updateNSView(_ nsView: NSView, context: Context) {}
    }
    func testChoicesAndSignatureSurviveRestartWithoutChangingRuntimeDataPreferences() throws {
        let suite = "FloatingCenterTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let initial = NotchRuntimePreferences.read(from: defaults)
        XCTAssertEqual(FloatingCenterStyle.fromStoredValue(nil), .signature)
        XCTAssertEqual(FloatingCenterStyle.fromStoredValue("unknown"), .signature)
        XCTAssertEqual(Set(FloatingCenterStyle.allCases), [.signature, .orbit, .elapsed, .flow])
        for style in FloatingCenterStyle.allCases {
            defaults.set(style.rawValue, forKey: FloatingCenterStyle.storageKey)
            defaults.set("专注当下", forKey: FloatingCenterText.storageKey)
            let reopened = try XCTUnwrap(UserDefaults(suiteName: suite))
            XCTAssertEqual(FloatingCenterStyle.fromStoredValue(reopened.string(forKey: FloatingCenterStyle.storageKey)), style)
            XCTAssertEqual(reopened.string(forKey: FloatingCenterText.storageKey), "专注当下")
            XCTAssertEqual(NotchRuntimePreferences.read(from: reopened), initial)
        }
    }

    func testSignatureIsOneBoundedLineWithoutSplittingComposedCharacters() {
        XCTAssertEqual(FloatingCenterText.displayText(" \n\t"), "Codex")
        XCTAssertEqual(FloatingCenterText.displayText("  Keep\n going  "), "Keep going")
        let family = "👨‍👩‍👧‍👦"
        XCTAssertEqual(FloatingCenterText.displayText(String(repeating: family, count: 13)), String(repeating: family, count: 12))
        XCTAssertEqual(FloatingCenterText.displayText("abcdefghijklmnop"), "abcdefghijkl")
    }

    func testTimerUsesTaskStartAndReturnsToSignatureWhenNotRunning() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(FloatingCenterText.elapsedText(activity: .running, startedAt: start, now: start.addingTimeInterval(158.9)), "02:38")
        XCTAssertEqual(FloatingCenterText.elapsedText(activity: .running, startedAt: start, now: start.addingTimeInterval(3_661)), "1:01:01")
        XCTAssertEqual(FloatingCenterText.elapsedText(activity: .running, startedAt: start, now: start.addingTimeInterval(-5)), "00:00")
        for activity in [QuotaRingActivity.idle, .completed] {
            XCTAssertNil(FloatingCenterText.elapsedText(activity: activity, startedAt: start, now: start.addingTimeInterval(500)))
        }
        XCTAssertNil(FloatingCenterText.elapsedText(activity: .running, startedAt: nil, now: start))
        XCTAssertNil(FloatingCenterText.elapsedText(activity: .running, startedAt: .distantPast, now: start))
    }

    func testOnlyOrbitAndFlowRunAndAllMotionGatesStopThem() {
        for style in FloatingCenterStyle.allCases {
            XCTAssertEqual(FloatingCenterMotionPolicy.shouldAnimate(style: style, activity: .running, motionEnabled: true, isExpanded: false), style == .orbit || style == .flow)
            for activity in [QuotaRingActivity.idle, .completed] {
                XCTAssertFalse(FloatingCenterMotionPolicy.shouldAnimate(style: style, activity: activity, motionEnabled: true, isExpanded: false))
            }
            XCTAssertFalse(FloatingCenterMotionPolicy.shouldAnimate(style: style, activity: .running, motionEnabled: false, isExpanded: false))
            XCTAssertFalse(FloatingCenterMotionPolicy.shouldAnimate(style: style, activity: .running, motionEnabled: true, isExpanded: true))
        }
    }

    @MainActor
    func testLayersRemainContainedAndDetachWithoutBackgroundAnimation() async throws {
        for style in [FloatingCenterStyle.orbit, .flow] {
            let size = style == .orbit ? NSSize(width: 18, height: 18) : NSSize(width: 96, height: 3)
            let view = FloatingCenterLayerView(frame: NSRect(origin: .zero, size: size))
            view.configure(style: style, activity: .running, isAnimating: true)
            view.layout()
            XCTAssertFalse(view.layerAnimationIsRunning)
            let root = try XCTUnwrap(view.layer)
            XCTAssertTrue(root.masksToBounds)
            let layers = try XCTUnwrap(root.sublayers)
            view.startLayerAnimation()
            let animated = try XCTUnwrap(layers.first { !($0.animationKeys()?.isEmpty ?? true) })
            let key = try XCTUnwrap(animated.animationKeys()?.first)
            let motion = try XCTUnwrap(animated.animation(forKey: key) as? CABasicAnimation)
            XCTAssertEqual(motion.preferredFrameRateRange.preferred, 8)
            if style == .flow {
                XCTAssertEqual(motion.toValue as? CGFloat, size.width + 32)
            }
            view.viewWillMove(toWindow: nil)
            XCTAssertTrue(layers.allSatisfy { $0.animationKeys()?.isEmpty ?? true })
            view.configure(style: style, activity: .completed, isAnimating: false)
            XCTAssertFalse(view.animationIsRequested)
            XCTAssertTrue(layers.allSatisfy { $0.animationKeys()?.isEmpty ?? true })
        }
    }

    func testSpringCanvasKeepsTheTopAnchorAndOnlyReservesSpaceForExpandedMotion() {
        let target = CGRect(x: 750, y: 800, width: 420, height: 280)
        let canvas = NotchPresentationMotion.canvasFrame(for: target, isExpanded: true, animationsEnabled: true)
        XCTAssertEqual(canvas.maxY, target.maxY)
        XCTAssertEqual(canvas.midX, target.midX)
        XCTAssertTrue(canvas.contains(target))
        XCTAssertGreaterThan(canvas.width, target.width)
        XCTAssertGreaterThan(canvas.height, target.height)
        XCTAssertEqual(NotchPresentationMotion.canvasFrame(for: target, isExpanded: false, animationsEnabled: true), target)
        XCTAssertEqual(NotchPresentationMotion.canvasFrame(for: target, isExpanded: true, animationsEnabled: false), target)
    }

    @MainActor
    func testAnimatedSwiftUIContentCannotResizeItsOwningPanel() async throws {
        _ = NSApplication.shared
        let model = NotchViewModel()
        let controller = NotchWindowController()
        controller.setRootView(NotchView(model: model))
        let panel = try XCTUnwrap(controller.window)
        defer { controller.hideNotchPanel() }
        let compact = NSRect(x: -10_000, y: 1_000, width: 662, height: 50)
        let expanded = NSRect(x: -10_000, y: 750, width: 662, height: 300)
        let layout = NotchLayout(
            mode: .floatingBar, centerX: compact.midX, hoverSensorFrame: compact,
            compactFrame: compact, quotaExpandedFrame: expanded, expandedFrame: expanded
        )
        let session = SessionActivity(
            threadID: "motion-test", turnID: "turn-1", title: "Motion review",
            cwd: nil, originator: nil, startedAt: .now, lastActivityAt: .now
        )
        let states: [NotchPresentationState] = [
            .quotaCompact(nil),
            .expanded(ExpandedContent(
                sessions: [session],
                conversations: [ConversationSummary(session: session, activity: .running(startedAt: session.startedAt))],
                headerConversation: nil, usage: nil
            )),
            .workingCompact(primary: session, count: 1, usage: nil)
        ]
        for state in states {
            let target = layout.frame(for: state)
            let identifier = controller.prepare(layout: layout, state: state, animationsEnabled: true)
            let preparedFrame = panel.frame
            var completed = false
            let animated = model.update(
                state: state, now: .now, layoutMode: .floatingBar,
                compactWidth: compact.width, compactHeight: compact.height,
                surfaceSize: target.size, animationsEnabled: true,
                onSurfaceAnimationCompleted: {
                    completed = true
                    controller.finishSurfaceAnimation(identifier: identifier, targetFrame: target)
                }
            )
            controller.settleFrame(
                layout: layout, state: state, animationsEnabled: true,
                animationWillComplete: animated
            )
            // Exercise the real SwiftUI surface, not an empty hosting view.
            for _ in 0..<100 {
                panel.contentView?.layoutSubtreeIfNeeded()
                try await Task.sleep(for: .milliseconds(20))
                if completed { break }
                XCTAssertEqual(panel.frame, preparedFrame, "SwiftUI must animate inside the controller-owned canvas")
            }
            XCTAssertTrue(completed, "The actual SwiftUI completion must release the temporary canvas")
            XCTAssertEqual(panel.frame, target)
        }
    }

    @MainActor
    func testPrepareResolvesTheContentScreenCenterBeforeAnimationBegins() throws {
        _ = NSApplication.shared
        let controller = NotchWindowController()
        let marker = NSView()
        controller.setRootView(
            CenterProbe(view: marker)
                .frame(width: 212, height: 30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        )
        let panel = try XCTUnwrap(controller.window)
        defer { controller.hideNotchPanel() }
        let compact = NSRect(x: -10_000, y: 1_000, width: 212, height: 30)
        let expanded = NSRect(x: -10_104, y: 750, width: 420, height: 280)
        let layout = NotchLayout(
            mode: .floatingBar, centerX: compact.midX, hoverSensorFrame: compact,
            compactFrame: compact, quotaExpandedFrame: expanded, expandedFrame: expanded
        )
        controller.prepare(layout: layout, state: .quotaCompact(nil), animationsEnabled: false)
        panel.contentView?.layoutSubtreeIfNeeded()
        let before = panel.convertToScreen(marker.convert(marker.bounds, to: nil)).midX
        XCTAssertEqual(before, compact.midX, accuracy: 0.5)
        controller.prepare(layout: layout, state: .expanded(ExpandedContent(
            sessions: [], conversations: [], headerConversation: nil, usage: nil
        )), animationsEnabled: true)
        // No model update or extra layout pass: prepare itself must establish
        // the stable screen-space center before the animated transaction.
        let after = panel.convertToScreen(marker.convert(marker.bounds, to: nil)).midX
        XCTAssertEqual(after, before, accuracy: 0.5)
    }

    @MainActor
    func testCanvasWaitsForCompletionAndIgnoresAnOlderMatchingTarget() async throws {
        _ = NSApplication.shared
        let controller = NotchWindowController()
        controller.setRootView(Color.clear)
        let panel = try XCTUnwrap(controller.window)
        defer { controller.hideNotchPanel() }
        let compact = NSRect(x: -10_000, y: 1_000, width: 212, height: 30)
        let expanded = NSRect(x: -10_104, y: 750, width: 420, height: 280)
        let layout = NotchLayout(
            mode: .floatingBar, centerX: compact.midX, hoverSensorFrame: compact,
            compactFrame: compact, quotaExpandedFrame: expanded, expandedFrame: expanded
        )
        let largeState = NotchPresentationState.expanded(ExpandedContent(
            sessions: [], conversations: [], headerConversation: nil, usage: nil
        ))
        let smallState = NotchPresentationState.quotaCompact(nil)
        let first = controller.prepare(layout: layout, state: largeState, animationsEnabled: true)
        controller.settleFrame(layout: layout, state: largeState, animationWillComplete: true)
        controller.finishSurfaceAnimation(identifier: first, targetFrame: expanded)
        let closing = controller.prepare(layout: layout, state: smallState, animationsEnabled: true)
        controller.settleFrame(layout: layout, state: smallState, animationWillComplete: true)
        try await Task.sleep(for: .milliseconds(750))
        XCTAssertEqual(panel.frame, expanded, "Elapsed time alone must never cut off the final animation frames")
        XCTAssertEqual(controller.prepare(layout: layout, state: smallState), closing)
        controller.settleFrame(layout: layout, state: smallState)
        XCTAssertEqual(panel.frame, expanded, "A clock refresh must not reclaim the canvas")

        let reopened = controller.prepare(layout: layout, state: largeState, animationsEnabled: true)
        controller.settleFrame(layout: layout, state: largeState, animationWillComplete: true)
        let padded = panel.frame
        controller.finishSurfaceAnimation(identifier: closing, targetFrame: compact)
        controller.finishSurfaceAnimation(identifier: first, targetFrame: expanded)
        XCTAssertEqual(panel.frame, padded, "Stale callbacks must not affect a later transition to the same target")
        controller.finishSurfaceAnimation(identifier: reopened, targetFrame: expanded)
        XCTAssertEqual(panel.frame, expanded)
    }

    @MainActor
    func testRepeatedUpdatesSettleAndRapidReentryCannotApplyAStaleCollapse() async throws {
        _ = NSApplication.shared
        let controller = NotchWindowController()
        controller.setRootView(Color.clear)
        let panel = try XCTUnwrap(controller.window)
        defer { controller.hideNotchPanel() }
        // Exercise a real panel away from the user's visible desktop.
        let compact = NSRect(x: -10_000, y: 1_000, width: 212, height: 30)
        let expandedFrame = NSRect(x: -10_104, y: 750, width: 420, height: 280)
        let layout = NotchLayout(
            mode: .floatingBar, centerX: compact.midX, hoverSensorFrame: compact,
            compactFrame: compact, quotaExpandedFrame: expandedFrame, expandedFrame: expandedFrame
        )
        let compactState = NotchPresentationState.quotaCompact(nil)
        let expandedState = NotchPresentationState.expanded(ExpandedContent(
            sessions: [], conversations: [], headerConversation: nil, usage: nil
        ))
        controller.prepare(layout: layout, state: compactState, animationsEnabled: false)
        controller.prepare(layout: layout, state: expandedState, animationsEnabled: true)
        XCTAssertGreaterThan(panel.frame.width, expandedFrame.width)
        XCTAssertEqual(panel.frame.maxY, expandedFrame.maxY)
        controller.settleFrame(layout: layout, state: expandedState, animationsEnabled: true)
        for _ in 0..<3 {
            try await Task.sleep(for: .milliseconds(150))
            controller.prepare(layout: layout, state: expandedState, animationsEnabled: true)
            controller.settleFrame(layout: layout, state: expandedState, animationsEnabled: true)
        }
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(panel.frame, expandedFrame, "Same-target refreshes must not restart the settlement delay")

        controller.prepare(layout: layout, state: compactState, animationsEnabled: true)
        controller.settleFrame(layout: layout, state: compactState, animationsEnabled: true)
        try await Task.sleep(for: .milliseconds(100))
        controller.prepare(layout: layout, state: expandedState, animationsEnabled: true)
        controller.settleFrame(layout: layout, state: expandedState, animationsEnabled: true)
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertGreaterThanOrEqual(panel.frame.width, expandedFrame.width, "The canceled collapse must not shrink a reopened card")
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(panel.frame, expandedFrame)

        controller.prepare(layout: layout, state: compactState, animationsEnabled: false)
        controller.settleFrame(layout: layout, state: compactState, animationsEnabled: false)
        XCTAssertEqual(panel.frame, compact, "Disabling motion must reclaim the mouse-intercepting canvas immediately")
    }
}
