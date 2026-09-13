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

    func testSignatureContinuesAtRestWhileOtherMotionKeepsItsRunningGate() {
        for style in FloatingCenterStyle.allCases {
            // FLOATING-CENTER-054 permits only signature shimmer at rest.
            XCTAssertEqual(FloatingCenterMotionPolicy.shouldAnimate(style: style, activity: .running, motionEnabled: true, isExpanded: false), style != .elapsed)
            for activity in [QuotaRingActivity.idle, .completed] {
                XCTAssertEqual(FloatingCenterMotionPolicy.shouldAnimate(style: style, activity: activity, motionEnabled: true, isExpanded: false), style == .signature)
            }
            XCTAssertFalse(FloatingCenterMotionPolicy.shouldAnimate(style: style, activity: .running, motionEnabled: false, isExpanded: false))
            XCTAssertFalse(FloatingCenterMotionPolicy.shouldAnimate(style: style, activity: .running, motionEnabled: true, isExpanded: true))
        }
    }

    @MainActor
    func testHostedSignatureIncludesHighlightAndPreservesStaticStateGeometry() throws {
        _ = NSApplication.shared
        let suite = "FloatingSignatureTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(FloatingCenterStyle.signature.rawValue, forKey: FloatingCenterStyle.storageKey)
        defaults.set("专注当下 Keep", forKey: FloatingCenterText.storageKey)
        func content(_ activity: QuotaRingActivity, motion: Bool = true, expanded: Bool = false) -> some View {
            FloatingCenterView(activity: activity, startedAt: .now, now: .now, isExpanded: expanded)
                .environment(\.notchMotionEnabled, motion)
                .defaultAppStorage(defaults)
                .frame(width: 136, height: 30)
        }
        func findMotion(in view: NSView) -> FloatingCenterLayerView? {
            if let motion = view as? FloatingCenterLayerView { return motion }
            return view.subviews.lazy.compactMap { findMotion(in: $0) }.first
        }
        let hosting = NSHostingView(rootView: content(.running))
        let panel = NSPanel(contentRect: NSRect(x: -10_000, y: 1_000, width: 136, height: 30),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = hosting
        defer { panel.orderOut(nil) }
        hosting.layoutSubtreeIfNeeded()
        let highlight = try XCTUnwrap(findMotion(in: hosting), "Running signature must include the omitted text highlight")
        XCTAssertTrue(highlight.animationIsRequested)
        XCTAssertFalse(highlight.layerAnimationIsRunning, "Detached or invisible surfaces must not consume animation work")
        let bounds = highlight.bounds
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
        XCTAssertLessThanOrEqual(bounds.width, 110)
        XCTAssertLessThanOrEqual(bounds.height, 30)
        for state in [(QuotaRingActivity.completed, true, false), (.idle, true, false),
                      (.running, false, false), (.running, true, true)] {
            hosting.rootView = content(state.0, motion: state.1, expanded: state.2)
            hosting.layoutSubtreeIfNeeded()
            let stopped = try XCTUnwrap(findMotion(in: hosting))
            XCTAssertEqual(stopped.animationIsRequested, state.1 && !state.2)
            XCTAssertFalse(stopped.layerAnimationIsRunning)
            XCTAssertEqual(stopped.bounds, bounds, "Stopping shimmer must not move or resize the signature")
        }
    }

    @MainActor
    func testVisibleSignatureContinuesThroughClockAndTaskStateUpdates() async throws {
        // Like the screen-recording fixture, this check needs an unlocked
        // interactive desktop. A skipped fixture is not visual acceptance.
        guard ProcessInfo.processInfo.environment["NOTCH_SIGNATURE_FRAMES"] != nil else {
            throw XCTSkip("Set NOTCH_SIGNATURE_FRAMES to sample live layers on an unlocked desktop")
        }
        _ = NSApplication.shared
        // swift test is a command-line process, so prepare AppKit and service
        // its window events just as a running application would.
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.accessory)
        NSApp.finishLaunching()
        defer { NSApp.setActivationPolicy(previousPolicy) }
        func serviceWindowEvents() {
            for _ in 0..<100 {
                guard let event = NSApp.nextEvent(matching: .any, until: .distantPast,
                                                 inMode: .default, dequeue: true) else { break }
                NSApp.sendEvent(event)
            }
        }
        let suite = "VisibleSignatureTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(FloatingCenterStyle.signature.rawValue, forKey: FloatingCenterStyle.storageKey)
        defaults.set("Codex", forKey: FloatingCenterText.storageKey)
        func content(_ activity: QuotaRingActivity, motion: Bool = true) -> some View {
            FloatingCenterView(activity: activity, startedAt: .now, now: .now, isExpanded: false)
                .environment(\.notchMotionEnabled, motion)
                .defaultAppStorage(defaults)
                .frame(width: 136, height: 30)
                .background(Color.black)
        }
        func findMotion(in view: NSView) -> FloatingCenterLayerView? {
            if let motion = view as? FloatingCenterLayerView { return motion }
            return view.subviews.lazy.compactMap { findMotion(in: $0) }.first
        }
        let hosting = NSHostingView(rootView: content(.running))
        let screen = try XCTUnwrap(NSScreen.main)
        let panel = NotchPanel(contentRect: NSRect(x: screen.visibleFrame.minX + 40, y: screen.visibleFrame.minY + 40, width: 136, height: 30))
        let canvas = NSView(frame: NSRect(x: 0, y: 0, width: 136, height: 30))
        hosting.sizingOptions = []
        hosting.frame = canvas.bounds
        canvas.addSubview(hosting)
        panel.contentView = canvas
        panel.orderFrontRegardless()
        defer { panel.orderOut(nil) }
        hosting.layoutSubtreeIfNeeded()
        for _ in 0..<20 {
            serviceWindowEvents()
            panel.displayIfNeeded()
            NSApp.updateWindows()
            CATransaction.flush()
            if panel.occlusionState.contains(.visible) { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let highlight = try XCTUnwrap(findMotion(in: hosting))
        XCTAssertTrue(highlight.layerAnimationIsRunning,
                      "requested=\(highlight.animationIsRequested) attached=\(highlight.window != nil) hidden=\(highlight.isHiddenOrHasHiddenAncestor) bounds=\(highlight.bounds) sameWindow=\(highlight.window === panel) viewWindowVisible=\(highlight.window?.isVisible ?? false) viewWindowOcclusion=\(highlight.window?.occlusionState.rawValue ?? 0) panelVisible=\(panel.isVisible) occlusion=\(panel.occlusionState.rawValue) visibleBit=\(NSWindow.OcclusionState.visible.rawValue) screen=\(screen.frame)")
        let glint = try XCTUnwrap(highlight.layer?.sublayers?.first { !($0.animationKeys()?.isEmpty ?? true) })
        let initialBounds = highlight.bounds
        var positions: [Double] = []
        let samples = ProcessInfo.processInfo.environment["NOTCH_SIGNATURE_FRAMES"].map { URL(fileURLWithPath: $0) }
        if let samples { try FileManager.default.createDirectory(at: samples, withIntermediateDirectories: true) }
        for index in 0..<58 {
            serviceWindowEvents()
            if index.isMultiple(of: 8) {
                hosting.rootView = content(index < 16 ? .running : (index < 32 ? .completed : .idle))
                hosting.layoutSubtreeIfNeeded()
            }
            XCTAssertTrue(highlight.layerAnimationIsRunning, "Completion and idle must retain the active shimmer")
            XCTAssertFalse(glint.isHidden)
            let x = try XCTUnwrap(glint.presentation()?.value(forKeyPath: "transform.translation.x") as? NSNumber)
            positions.append(x.doubleValue)
            if positions.count > 4 {
                let travel = abs(x.doubleValue - positions[positions.count - 5])
                XCTAssertGreaterThan(travel, initialBounds.width * 0.01,
                                     "The highlight must keep moving instead of waiting at either endpoint")
            }
            let pixelWidth = Int(ceil(initialBounds.width))
            let pixelHeight = Int(ceil(initialBounds.height))
            let light = try XCTUnwrap(CGContext(data: nil, width: pixelWidth, height: pixelHeight,
                                               bitsPerComponent: 8, bytesPerRow: pixelWidth * 4,
                                               space: CGColorSpaceCreateDeviceRGB(),
                                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            try XCTUnwrap(highlight.layer?.presentation()).render(in: light)
            let bytes = try XCTUnwrap(light.data).assumingMemoryBound(to: UInt8.self)
            let meanLight = stride(from: 3, to: pixelWidth * pixelHeight * 4, by: 4)
                .reduce(0.0) { $0 + Double(bytes[$1]) / 255 } / Double(pixelWidth * pixelHeight)
            XCTAssertGreaterThan(meanLight, 0.2,
                                 "Some soft illumination must remain within the word at every phase")
            XCTAssertEqual(highlight.bounds, initialBounds)
            if let samples, index.isMultiple(of: 2),
               let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 272, pixelsHigh: 60,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
               let context = NSGraphicsContext(bitmapImageRep: image)?.cgContext {
                context.scaleBy(x: 2, y: 2)
                hosting.layer?.presentation()?.render(in: context)
                try image.representation(using: .png, properties: [:])?.write(
                    to: samples.appendingPathComponent(String(format: "frame-%02d.png", index)))
            }
            try await Task.sleep(for: .milliseconds(125))
        }
        // FLOATING-CENTER-055 wraps after one text-width, instead of traveling
        // beyond both ends of the word. Discrete samples cover nearly a period.
        XCTAssertGreaterThan(try XCTUnwrap(positions.max()) - XCTUnwrap(positions.min()), initialBounds.width * 0.9,
                             "The highlight must traverse a full period despite one-second view updates")
        hosting.rootView = content(.completed, motion: false)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertFalse(highlight.animationIsRequested)
        XCTAssertFalse(highlight.layerAnimationIsRunning)
        XCTAssertTrue(glint.animationKeys()?.isEmpty ?? true)
        XCTAssertEqual(highlight.bounds, initialBounds)
    }

    @MainActor
    func testLayersRemainContainedAndDetachWithoutBackgroundAnimation() async throws {
        for style in [FloatingCenterStyle.signature, .orbit, .flow] {
            let size = style == .orbit ? NSSize(width: 18, height: 18)
                : NSSize(width: 96, height: style == .signature ? 14 : 3)
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
            let motion = try XCTUnwrap(animated.animation(forKey: key))
            XCTAssertEqual(motion.preferredFrameRateRange.preferred, 8)
            if style == .flow {
                XCTAssertEqual((motion as? CABasicAnimation)?.toValue as? CGFloat, size.width + 32)
            } else if style == .signature {
                let shimmer = try XCTUnwrap(motion as? CABasicAnimation)
                XCTAssertEqual(shimmer.keyPath, "transform.translation.x")
                let start = try XCTUnwrap(shimmer.fromValue as? NSNumber).doubleValue
                let end = try XCTUnwrap(shimmer.toValue as? NSNumber).doubleValue
                XCTAssertEqual(end - start, size.width, accuracy: 0.001)
                XCTAssertEqual(shimmer.duration, 5, "Use the requested slightly faster cadence")
                XCTAssertTrue(CATransform3DIsIdentity(root.transform), "Only the masked light moves; glyph geometry stays fixed")
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
