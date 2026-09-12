import AppKit
import QuartzCore
import SwiftUI
import XCTest
@testable import CodexNotch

final class FloatingCenterTests: XCTestCase {
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
        let states: [NotchPresentationState] = [
            .quotaCompact(nil),
            .expanded(ExpandedContent(sessions: [], conversations: [], headerConversation: nil, usage: nil)),
            .quotaCompact(nil)
        ]
        for state in states {
            let target = layout.frame(for: state)
            controller.prepare(layout: layout, state: state, animationsEnabled: true)
            let preparedFrame = panel.frame
            model.update(
                state: state, now: .now, layoutMode: .floatingBar,
                compactWidth: compact.width, compactHeight: compact.height,
                surfaceSize: target.size, animationsEnabled: true
            )
            // Exercise the real SwiftUI surface, not an empty hosting view.
            for _ in 0..<5 {
                panel.contentView?.layoutSubtreeIfNeeded()
                try await Task.sleep(for: .milliseconds(20))
                XCTAssertEqual(panel.frame, preparedFrame, "SwiftUI must animate inside the controller-owned canvas")
            }
            controller.settleFrame(layout: layout, state: state, animationsEnabled: true)
            try await Task.sleep(for: .milliseconds(700))
            XCTAssertEqual(panel.frame, target)
        }
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
