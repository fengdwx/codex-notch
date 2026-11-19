import AppKit
import SwiftUI
import XCTest
@testable import CodexNotch

final class SettingsReadabilityTests: XCTestCase {
    @MainActor
    func testModernSidebarSettingsUsesStableFixedWindowGeometry() {
        _ = NSApplication.shared
        let suite = "SettingsReadabilityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(AppLanguage.english.rawValue, forKey: AppLanguage.storageKey)
        let hosting = NSHostingView(rootView: NotchSettingsView().defaultAppStorage(defaults))
        let size = hosting.fittingSize
        XCTAssertEqual(size.width, NotchSettingsLayout.windowWidth, accuracy: 1)
        XCTAssertEqual(size.height, NotchSettingsLayout.windowHeight, accuracy: 1)
    }

    @MainActor
    func testGlintIsSubordinateToQuotaAndDoesNotDimAReusedQuotaGradient() throws {
        let view = QuotaGradientLayerView(frame: NSRect(x: 0, y: 0, width: 22, height: 22))
        view.configure(color: QuotaInnerGlowMotion.color, isAnimating: false, style: .innerGlow)
        let gradient = try XCTUnwrap(view.layer?.sublayers?.first as? CAGradientLayer)
        let colors = try XCTUnwrap(gradient.colors as? [CGColor])
        let peak = try XCTUnwrap(colors.map(\.alpha).max()) * CGFloat(gradient.opacity)
        XCTAssertLessThan(peak, 0.6, "The pale glint must remain behind the readable quota arc and value")
        XCTAssertGreaterThan(peak, 0.25, "The independent running cue must remain visible at low quota")
        view.configure(color: QuotaInnerGlowMotion.color, isAnimating: false, style: .quota)
        XCTAssertEqual(gradient.opacity, 1, "Decorative attenuation must never carry over to the actual quota")
    }

    @MainActor
    func testNativeSettingsWindowHasExactFullSizeContentGeometryAndPreservesDraggedOrigin() throws {
        _ = NSApplication.shared
        SettingsWindowPresenter.disposeOwnedSettingsWindowForTesting()
        defer { SettingsWindowPresenter.disposeOwnedSettingsWindowForTesting() }

        let window = SettingsWindowPresenter.createNativeSettingsWindow()
        XCTAssertTrue(SettingsWindowPresenter.isSettingsWindow(window))
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertFalse(window.styleMask.contains(.resizable))
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertNotNil(window.toolbar)
        XCTAssertEqual(window.toolbarStyle, .unifiedCompact)
        XCTAssertTrue(window.isMovable)
        XCTAssertTrue(window.isMovableByWindowBackground)
        XCTAssertFalse(window.isRestorable, "Settings window must not resurrect stale SwiftUI Settings state")
        XCTAssertEqual(window.frame.width, NotchSettingsLayout.windowWidth, accuracy: 1)
        XCTAssertEqual(
            window.frame.height,
            NotchSettingsLayout.windowHeight,
            accuracy: 1,
            "Full-size native Settings window must not add a 28pt extra titlebar strip"
        )
        let contentView = try XCTUnwrap(window.contentView)
        contentView.layoutSubtreeIfNeeded()
        XCTAssertEqual(contentView.frame.width, NotchSettingsLayout.windowWidth, accuracy: 1)
        XCTAssertEqual(contentView.frame.height, NotchSettingsLayout.windowHeight, accuracy: 1)

        // Force Light appearance on the test window so pixel assertions are deterministic
        // regardless of host Dark/Light mode.
        window.appearance = NSAppearance(named: .aqua)
        contentView.layoutSubtreeIfNeeded()

        // Left sidebar, top header bar, right outer inset margin, and bottom outer inset margin
        // must all render the exact same unified neutral shell surface (no 3-color-block seam or
        // desktop-tinted sidebar bleed), while the inset detail sheet renders pure elevated white.
        let rep = try XCTUnwrap(contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds))
        contentView.cacheDisplay(in: contentView.bounds, to: rep)
        let scaleX = Double(rep.pixelsWide) / Double(NotchSettingsLayout.windowWidth)
        let scaleY = Double(rep.pixelsHigh) / Double(NotchSettingsLayout.windowHeight)
        func sampleRGB(ptX: Double, ptY: Double) throws -> NSColor {
            let px = min(max(Int((ptX * scaleX).rounded()), 0), rep.pixelsWide - 1)
            let py = min(max(Int((ptY * scaleY).rounded()), 0), rep.pixelsHigh - 1)
            return try XCTUnwrap(rep.colorAt(x: px, y: py)?.usingColorSpace(.sRGB))
        }

        let sidebarShell = try sampleRGB(ptX: 24, ptY: 360)
        let topBarShell = try sampleRGB(ptX: 680, ptY: 16)
        let rightOuterShell = try sampleRGB(ptX: 716, ptY: 260)
        let bottomOuterShell = try sampleRGB(ptX: 440, ptY: 536)
        for sample in [topBarShell, rightOuterShell, bottomOuterShell] {
            XCTAssertEqual(sample.redComponent, sidebarShell.redComponent, accuracy: 0.02)
            XCTAssertEqual(sample.greenComponent, sidebarShell.greenComponent, accuracy: 0.02)
            XCTAssertEqual(sample.blueComponent, sidebarShell.blueComponent, accuracy: 0.02)
        }
        // Unified Light shell stays cool-neutral (no warm brown/taupe wallpaper tint).
        XCTAssertLessThan(abs(sidebarShell.redComponent - sidebarShell.blueComponent), 0.02)

        // Inset rounded detail sheet interior (below General cards, inside bottom-right of sheet)
        // must render pure crisp white brighter than the surrounding shell.
        let sheetInterior = try sampleRGB(ptX: 660, ptY: 480)
        XCTAssertGreaterThan(sheetInterior.redComponent, 0.99)
        XCTAssertGreaterThan(sheetInterior.greenComponent, 0.99)
        XCTAssertGreaterThan(sheetInterior.blueComponent, 0.99)
        XCTAssertGreaterThan(sheetInterior.redComponent - sidebarShell.redComponent, 0.015)

        let movedOrigin = NSPoint(x: 240, y: 260)
        window.setFrameOrigin(movedOrigin)
        contentView.layoutSubtreeIfNeeded()
        XCTAssertEqual(window.frame.origin.x, movedOrigin.x, accuracy: 0.5)
        XCTAssertEqual(window.frame.origin.y, movedOrigin.y, accuracy: 0.5)
        XCTAssertEqual(window.frame.width, NotchSettingsLayout.windowWidth, accuracy: 1)
        XCTAssertEqual(window.frame.height, NotchSettingsLayout.windowHeight, accuracy: 1)
    }

    @MainActor
    func testAppearancePreviewRespondsToAnimationToggleForBothRingAndWaveBall() async throws {
        _ = NSApplication.shared
        let suite = "SettingsReadabilityTests.AppearancePreview.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(StatusIconStyle.codex.rawValue, forKey: StatusIconStyle.storageKey)

        func findViews<T: NSView>(of type: T.Type, in view: NSView) -> [T] {
            var matches: [T] = []
            if let typed = view as? T { matches.append(typed) }
            for subview in view.subviews { matches.append(contentsOf: findViews(of: type, in: subview)) }
            return matches
        }

        for style in QuotaDisplayStyle.allCases {
            defaults.set(style.rawValue, forKey: QuotaDisplayStyle.storageKey)
            defaults.set(true, forKey: AppAnimationPreference.storageKey)

            let size = NSSize(width: NotchSettingsLayout.windowWidth, height: NotchSettingsLayout.windowHeight)
            let hosting = NSHostingController(
                rootView: NotchSettingsView(initialTab: .appearance).defaultAppStorage(defaults)
            )
            hosting.sizingOptions = []
            hosting.safeAreaRegions = []
            let window = SettingsVisibleTestWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.contentViewController = hosting
            window.setContentSize(size)
            defer { window.orderOut(nil); window.close() }

            hosting.view.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
            hosting.view.layoutSubtreeIfNeeded()

            let animatedOn = findViews(of: QuotaAnimatedLayerView.self, in: hosting.view)
            XCTAssertFalse(
                animatedOn.isEmpty,
                "Appearance preview must mount animated layers when animations are enabled (\(style))"
            )
            XCTAssertTrue(
                animatedOn.allSatisfy { $0.animationIsRequested && $0.layerAnimationIsRunning },
                "Every Appearance preview layer must animate when animations are enabled (\(style))"
            )

            defaults.set(false, forKey: AppAnimationPreference.storageKey)
            try await Task.sleep(for: .milliseconds(50))
            hosting.view.layoutSubtreeIfNeeded()

            let animatedOff = findViews(of: QuotaAnimatedLayerView.self, in: hosting.view)
            XCTAssertTrue(
                animatedOff.allSatisfy { !$0.animationIsRequested && !$0.layerAnimationIsRunning },
                "Turning off animations must immediately freeze every Appearance preview layer (\(style))"
            )
        }
    }
}

@MainActor
private final class SettingsVisibleTestWindow: NSWindow {
    override var isVisible: Bool { true }
    override var occlusionState: NSWindow.OcclusionState { .visible }
}
