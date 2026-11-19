import AppKit
import QuartzCore
import SwiftUI
import XCTest
@testable import CodexNotch

final class AdditiveRunningMotionTests: XCTestCase {
    func testLowQuotaKeepsItsOriginalFlowWhileRequestingIndependentInnerGlow() {
        let trim = QuotaRingMath.clockwiseTrim(progress: 0.05)
        XCTAssertEqual(trim.to - trim.from, 0.05, accuracy: 0.0001)
        XCTAssertEqual(
            QuotaRingAppearance.colorMode(for: .running, motionEnabled: true),
            .gradient
        )
        XCTAssertTrue(QuotaInnerGlowMotion.shouldAnimate(
            activity: .running, hasQuota: true, motionEnabled: true
        ))
        // Inner glow geometry has no remaining-percentage input, so a 5%
        // quota cannot shrink the status signal into the quota's short arc.
        let inset = QuotaInnerGlowMotion.strokeInset(quotaLineWidth: 2.25)
        let outerRadius = 11 - inset + QuotaInnerGlowMotion.lineWidth / 2
        XCTAssertLessThan(outerRadius, 11 - 2.25)
        XCTAssertGreaterThan(outerRadius, 8)
    }

    func testInnerGlowStopsForCompletedIdleMissingQuotaAndReducedMotion() {
        for activity in [QuotaRingActivity.idle, .completed] {
            XCTAssertFalse(QuotaInnerGlowMotion.shouldAnimate(
                activity: activity, hasQuota: true, motionEnabled: true
            ))
        }
        XCTAssertFalse(QuotaInnerGlowMotion.shouldAnimate(
            activity: .running, hasQuota: false, motionEnabled: true
        ))
        XCTAssertFalse(QuotaInnerGlowMotion.shouldAnimate(
            activity: .running, hasQuota: true, motionEnabled: false
        ))
    }

    func testCodexEchoStaysInsideItsExistingIndicatorContainer() {
        XCTAssertLessThanOrEqual(
            NotchCompactLayout.appMarkSize * StatusMarkEchoMotion.maximumScale,
            NotchCompactLayout.indicatorDiameter
        )
        XCTAssertGreaterThan(StatusMarkEchoMotion.maximumScale, 1.1)
        XCTAssertGreaterThan(
            StatusMarkEchoMotion.maximumOpacity,
            StatusMarkEchoMotion.minimumOpacity
        )
    }

    @MainActor
    func testDetachedGlintDoesNotAnimateAndDetachmentRemovesAnExistingAnimation() async throws {
        let view = QuotaGradientLayerView(frame: NSRect(x: 0, y: 0, width: 22, height: 22))
        view.configure(color: QuotaInnerGlowMotion.color, isAnimating: true, style: .innerGlow)
        XCTAssertFalse(view.layerAnimationIsRunning)
        let gradient = try XCTUnwrap(view.layer?.sublayers?.first as? CAGradientLayer)
        XCTAssertTrue(gradient.animationKeys()?.isEmpty ?? true)

        view.startLayerAnimation()
        XCTAssertFalse(gradient.animationKeys()?.isEmpty ?? true)
        view.viewWillMove(toWindow: nil)
        XCTAssertTrue(gradient.animationKeys()?.isEmpty ?? true)
    }

    @MainActor
    func testCodexEchoUsesEmbeddedSilhouetteAndStopsOnDetachment() async throws {
        let view = StatusMarkEchoLayerView(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
        view.layout()
        view.setAnimationRequested(true)
        XCTAssertFalse(view.layerAnimationIsRunning)
        let echo = try XCTUnwrap(view.layer?.sublayers?.first)
        XCTAssertNotNil(echo.mask?.contents)
        XCTAssertTrue(echo.animationKeys()?.isEmpty ?? true)

        view.startLayerAnimation()
        let keys = try XCTUnwrap(echo.animationKeys())
        let pulse = try XCTUnwrap(echo.animation(forKey: keys[0]) as? CAAnimationGroup)
        XCTAssertEqual(pulse.preferredFrameRateRange.preferred, 8)
        XCTAssertTrue(pulse.animations?.contains {
            ($0 as? CAPropertyAnimation)?.keyPath == "transform.scale"
        } ?? false)
        view.viewWillMove(toSuperview: nil)
        XCTAssertTrue(echo.animationKeys()?.isEmpty ?? true)
    }

    @MainActor
    private func makeVisibleTestWindow(contentRect: NSRect) -> NSWindow {
        let window = VisibleMotionTestWindow(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        return window
    }

    @MainActor
    func testZeroFrameAnimatedLayerViewsStartAfterFirstNonzeroLayoutInVisibleWindow() throws {
        _ = NSApplication.shared
        let panel = makeVisibleTestWindow(contentRect: NSRect(x: 40, y: 40, width: 120, height: 60))
        let host = NSView(frame: panel.contentLayoutRect)
        panel.contentView = host
        defer { panel.orderOut(nil); panel.close() }

        let quotaGradient = QuotaGradientLayerView(frame: .zero)
        quotaGradient.configure(color: QuotaColorScale.components(for: 100), isAnimating: true, style: .quota)
        let innerGlow = QuotaGradientLayerView(frame: .zero)
        innerGlow.configure(
            color: QuotaInnerGlowMotion.color,
            isAnimating: true,
            style: .innerGlow,
            circularMask: QuotaGradientCircularMask(inset: 3, lineWidth: 1)
        )
        let halo = QuotaRunningHaloLayerView(frame: .zero)
        halo.setAnimationRequested(true)
        let echo = StatusMarkEchoLayerView(frame: .zero)
        echo.configure(iconStyle: .codex, isAnimating: true)

        let views: [QuotaAnimatedLayerView] = [quotaGradient, innerGlow, halo, echo]
        for view in views {
            host.addSubview(view)
            XCTAssertFalse(
                view.layerAnimationIsRunning,
                "Zero-sized views must stay idle before receiving layout geometry"
            )
        }

        quotaGradient.frame = NSRect(x: 4, y: 4, width: 22, height: 22)
        innerGlow.frame = NSRect(x: 30, y: 4, width: 22, height: 22)
        halo.frame = NSRect(x: 56, y: 4, width: 24, height: 24)
        echo.frame = NSRect(x: 84, y: 4, width: 18, height: 18)
        host.layoutSubtreeIfNeeded()

        for view in views {
            XCTAssertTrue(
                view.layerAnimationIsRunning,
                "\(type(of: view)) must start its Core Animation once layout assigns nonzero bounds"
            )
            let drawingLayer = try XCTUnwrap(view.layer?.sublayers?.first)
            XCTAssertFalse(
                drawingLayer.animationKeys()?.isEmpty ?? true,
                "\(type(of: view)) must attach its layer animation on first nonzero layout"
            )
        }

        for view in views {
            view.frame = .zero
        }
        host.layoutSubtreeIfNeeded()
        for view in views {
            XCTAssertFalse(view.layerAnimationIsRunning)
        }
    }

    @MainActor
    func testPlusRunningCompactViewAnimatesBothFiveHourLeftAndWeeklyRightRings() async throws {
        _ = NSApplication.shared
        let suiteName = "AdditiveRunningMotionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(QuotaDisplayStyle.clockwiseRing.rawValue, forKey: QuotaDisplayStyle.storageKey)
        defaults.set(StatusIconStyle.codex.rawValue, forKey: StatusIconStyle.storageKey)

        let now = Date(timeIntervalSince1970: 1_795_054_500)
        let session = SessionActivity(
            threadID: "thread-plus-running",
            turnID: "turn-1",
            title: "Plus task",
            cwd: "/tmp/project",
            originator: nil,
            startedAt: now.addingTimeInterval(-30),
            lastActivityAt: now
        )
        let snapshots: [(label: String, fiveHourUsed: Double, weeklyUsed: Double)] = [
            ("5h=100% 7d=31%", 0, 69),
            ("5h=98% 7d=31%", 2, 69),
            ("5h=0% 7d=100%", 100, 0),
        ]

        func findViews<T: NSView>(of type: T.Type, in view: NSView) -> [T] {
            var matches: [T] = []
            if let typed = view as? T {
                matches.append(typed)
            }
            for subview in view.subviews {
                matches.append(contentsOf: findViews(of: type, in: subview))
            }
            return matches
        }

        for layoutMode in [NotchLayoutMode.notch, .floatingBar] {
            let width: CGFloat = layoutMode == .notch ? 268 : NotchFloatingBarLayout.compactWidth
            let height: CGFloat = layoutMode == .notch ? 33 : NotchFloatingBarLayout.preferredHeight

            for sample in snapshots {
                let usage = UsageSnapshot(
                    windows: [
                        UsageWindow(id: "five-hour", kind: .rolling(hours: 5), usedPercent: sample.fiveHourUsed),
                        UsageWindow(id: "weekly", kind: .weekly, usedPercent: sample.weeklyUsed),
                    ],
                    fetchedAt: now
                )
                let model = NotchViewModel(
                    state: .quotaCompact(usage),
                    now: now,
                    layoutMode: layoutMode,
                    compactWidth: width,
                    compactHeight: height,
                    surfaceSize: CGSize(width: width, height: height),
                    animationsEnabled: true
                )
                let hosting = NSHostingView(
                    rootView: NotchView(model: model)
                        .defaultAppStorage(defaults)
                        .frame(width: width, height: height)
                )
                hosting.sizingOptions = []
                hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
                let panel = makeVisibleTestWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height))
                panel.contentView = hosting
                defer { panel.orderOut(nil); panel.close() }

                hosting.layoutSubtreeIfNeeded()

                model.update(
                    state: .workingCompact(primary: session, count: 1, usage: usage),
                    now: now.addingTimeInterval(1),
                    layoutMode: layoutMode,
                    compactWidth: width,
                    compactHeight: height,
                    surfaceSize: CGSize(width: width, height: height),
                    animationsEnabled: true
                )
                hosting.layoutSubtreeIfNeeded()
                try await Task.sleep(for: .milliseconds(30))
                hosting.layoutSubtreeIfNeeded()

                let gradients = findViews(of: QuotaGradientLayerView.self, in: hosting)
                XCTAssertEqual(
                    gradients.count, 4,
                    "Expected 2 gradient layers on left 5h and 2 on right 7d (\(layoutMode), \(sample.label))"
                )
                let leftGradients = gradients.filter {
                    $0.convert(CGPoint(x: $0.bounds.midX, y: $0.bounds.midY), to: hosting).x < hosting.bounds.midX
                }
                let rightGradients = gradients.filter {
                    $0.convert(CGPoint(x: $0.bounds.midX, y: $0.bounds.midY), to: hosting).x > hosting.bounds.midX
                }
                XCTAssertEqual(leftGradients.count, 2, "Left 5h must have both quota and inner-glow layers")
                XCTAssertEqual(rightGradients.count, 2, "Right 7d must have both quota and inner-glow layers")

                for view in leftGradients + rightGradients {
                    XCTAssertTrue(
                        view.layerAnimationIsRunning,
                        "Every running quota gradient layer must animate (\(layoutMode), \(sample.label))"
                    )
                    let layer = try XCTUnwrap(view.layer?.sublayers?.first)
                    XCTAssertFalse(
                        layer.animationKeys()?.isEmpty ?? true,
                        "Every running quota gradient layer must hold its rotation animation (\(layoutMode), \(sample.label))"
                    )
                }

                let halos = findViews(of: QuotaRunningHaloLayerView.self, in: hosting)
                if layoutMode == .notch {
                    XCTAssertEqual(halos.count, 2, "Notch mode must show running halo on both 5h left and 7d right")
                    let leftHalos = halos.filter {
                        $0.convert(CGPoint(x: $0.bounds.midX, y: $0.bounds.midY), to: hosting).x < hosting.bounds.midX
                    }
                    let rightHalos = halos.filter {
                        $0.convert(CGPoint(x: $0.bounds.midX, y: $0.bounds.midY), to: hosting).x > hosting.bounds.midX
                    }
                    XCTAssertEqual(leftHalos.count, 1)
                    XCTAssertEqual(rightHalos.count, 1)
                    for halo in halos {
                        XCTAssertTrue(halo.layerAnimationIsRunning)
                        let layer = try XCTUnwrap(halo.layer?.sublayers?.first)
                        XCTAssertFalse(layer.animationKeys()?.isEmpty ?? true)
                    }
                } else {
                    XCTAssertEqual(halos.count, 0)
                }
            }
        }
    }

    @MainActor
    func testExpandedHeaderTransitionFromIdleToRunningAnimatesFullFiveHourLeftRing() async throws {
        _ = NSApplication.shared
        let suiteName = "AdditiveRunningMotionTests.Expanded.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(QuotaDisplayStyle.clockwiseRing.rawValue, forKey: QuotaDisplayStyle.storageKey)
        defaults.set(StatusIconStyle.codex.rawValue, forKey: StatusIconStyle.storageKey)

        let now = Date(timeIntervalSince1970: 1_795_054_500)
        let usage = UsageSnapshot(
            windows: [
                UsageWindow(id: "five-hour", kind: .rolling(hours: 5), usedPercent: 0),
                UsageWindow(id: "weekly", kind: .weekly, usedPercent: 69),
            ],
            fetchedAt: now
        )
        let session = SessionActivity(
            threadID: "thread-expanded-running",
            turnID: "turn-1",
            title: "Expanded Plus task",
            cwd: "/tmp/project",
            originator: nil,
            startedAt: now.addingTimeInterval(-10),
            lastActivityAt: now
        )

        func findViews<T: NSView>(of type: T.Type, in view: NSView) -> [T] {
            var matches: [T] = []
            if let typed = view as? T {
                matches.append(typed)
            }
            for subview in view.subviews {
                matches.append(contentsOf: findViews(of: type, in: subview))
            }
            return matches
        }

        let width: CGFloat = 340
        let height: CGFloat = 280
        let compactWidth: CGFloat = 268
        let compactHeight: CGFloat = 33
        let idleContent = ExpandedContent(
            sessions: [],
            conversations: [],
            headerConversation: nil,
            usage: usage
        )
        let runningContent = ExpandedContent(
            sessions: [session],
            conversations: [],
            headerConversation: nil,
            usage: usage
        )

        let model = NotchViewModel(
            state: .expanded(idleContent),
            now: now,
            layoutMode: .notch,
            compactWidth: compactWidth,
            compactHeight: compactHeight,
            surfaceSize: CGSize(width: width, height: height),
            animationsEnabled: true
        )
        let hosting = NSHostingView(
            rootView: NotchView(model: model)
                .defaultAppStorage(defaults)
                .frame(width: width, height: height)
        )
        hosting.sizingOptions = []
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        let panel = makeVisibleTestWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height))
        panel.contentView = hosting
        defer { panel.orderOut(nil); panel.close() }

        hosting.layoutSubtreeIfNeeded()

        model.update(
            state: .expanded(runningContent),
            now: now.addingTimeInterval(1),
            layoutMode: .notch,
            compactWidth: compactWidth,
            compactHeight: compactHeight,
            surfaceSize: CGSize(width: width, height: height),
            animationsEnabled: true
        )
        hosting.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(30))
        hosting.layoutSubtreeIfNeeded()

        let gradients = findViews(of: QuotaGradientLayerView.self, in: hosting)
        XCTAssertEqual(gradients.count, 4)
        for view in gradients {
            XCTAssertTrue(
                view.layerAnimationIsRunning,
                "Both left 5h (100%) and right 7d (31%) gradient layers must animate when expanded header enters running"
            )
            let layer = try XCTUnwrap(view.layer?.sublayers?.first)
            XCTAssertFalse(layer.animationKeys()?.isEmpty ?? true)
        }

        let halos = findViews(of: QuotaRunningHaloLayerView.self, in: hosting)
        XCTAssertEqual(halos.count, 2)
        for halo in halos {
            XCTAssertTrue(halo.layerAnimationIsRunning)
            let layer = try XCTUnwrap(halo.layer?.sublayers?.first)
            XCTAssertFalse(layer.animationKeys()?.isEmpty ?? true)
        }
    }

    @MainActor
    func testPlusRunningWaveBallAnimatesBothFullFiveHourLeftAndWeeklyRightAndStopsWhenMotionTurnsOff() async throws {
        _ = NSApplication.shared
        let suiteName = "AdditiveRunningMotionTests.WaveBall.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(QuotaDisplayStyle.waveBall.rawValue, forKey: QuotaDisplayStyle.storageKey)
        defaults.set(StatusIconStyle.codex.rawValue, forKey: StatusIconStyle.storageKey)

        let now = Date(timeIntervalSince1970: 1_795_054_500)
        let session = SessionActivity(
            threadID: "thread-plus-waveball",
            turnID: "turn-1",
            title: "Wave ball task",
            cwd: "/tmp/project",
            originator: nil,
            startedAt: now.addingTimeInterval(-20),
            lastActivityAt: now
        )
        let usage = UsageSnapshot(
            windows: [
                UsageWindow(id: "five-hour", kind: .rolling(hours: 5), usedPercent: 0),
                UsageWindow(id: "weekly", kind: .weekly, usedPercent: 69),
            ],
            fetchedAt: now
        )

        func findViews<T: NSView>(of type: T.Type, in view: NSView) -> [T] {
            var matches: [T] = []
            if let typed = view as? T { matches.append(typed) }
            for subview in view.subviews { matches.append(contentsOf: findViews(of: type, in: subview)) }
            return matches
        }

        for layoutMode in [NotchLayoutMode.notch, .floatingBar] {
            let width: CGFloat = layoutMode == .notch ? 268 : NotchFloatingBarLayout.compactWidth
            let height: CGFloat = layoutMode == .notch ? 33 : NotchFloatingBarLayout.preferredHeight
            let model = NotchViewModel(
                state: .workingCompact(primary: session, count: 1, usage: usage),
                now: now,
                layoutMode: layoutMode,
                compactWidth: width,
                compactHeight: height,
                surfaceSize: CGSize(width: width, height: height),
                animationsEnabled: true
            )
            let hosting = NSHostingView(
                rootView: NotchView(model: model)
                    .defaultAppStorage(defaults)
                    .frame(width: width, height: height)
            )
            hosting.sizingOptions = []
            hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
            let panel = makeVisibleTestWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height))
            panel.contentView = hosting
            defer { panel.orderOut(nil); panel.close() }

            hosting.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(30))
            hosting.layoutSubtreeIfNeeded()

            let waves = findViews(of: QuotaWaveLayerView.self, in: hosting)
            let glints = findViews(of: QuotaGradientLayerView.self, in: hosting)
            XCTAssertEqual(waves.count, 2, "Both 5h left and 7d right must render wave balls (\(layoutMode))")
            XCTAssertEqual(
                glints.count,
                2,
                "Wave ball must render independent inner running glint on both 5h (even at 100%) and 7d (\(layoutMode))"
            )
            for view in (waves as [QuotaAnimatedLayerView]) + (glints as [QuotaAnimatedLayerView]) {
                XCTAssertTrue(view.layerAnimationIsRunning)
            }

            // Flip animations OFF and confirm every running layer stops immediately.
            model.update(
                state: .workingCompact(primary: session, count: 1, usage: usage),
                now: now.addingTimeInterval(1),
                layoutMode: layoutMode,
                compactWidth: width,
                compactHeight: height,
                surfaceSize: CGSize(width: width, height: height),
                animationsEnabled: false
            )
            hosting.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(30))
            hosting.layoutSubtreeIfNeeded()

            let allAnimatedOff = findViews(of: QuotaAnimatedLayerView.self, in: hosting)
            XCTAssertTrue(
                allAnimatedOff.allSatisfy { !$0.animationIsRequested && !$0.layerAnimationIsRunning },
                "Disabling animations must immediately stop all live wave, glint, halo, and center layers (\(layoutMode))"
            )
        }
    }
}

@MainActor
private final class VisibleMotionTestWindow: NSWindow {
    override var isVisible: Bool { true }
    override var occlusionState: NSWindow.OcclusionState { .visible }
}
