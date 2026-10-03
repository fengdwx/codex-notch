import AppKit
import SwiftUI
import XCTest
@testable import CodexNotch

final class SettingsReadabilityTests: XCTestCase {
    @MainActor
    func testGeneralSettingsDoesNotReserveFloatingPreviewHeight() {
        _ = NSApplication.shared
        let suite = "SettingsReadabilityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(AppLanguage.english.rawValue, forKey: AppLanguage.storageKey)
        let hosting = NSHostingView(rootView: NotchSettingsView().defaultAppStorage(defaults))
        let size = hosting.fittingSize
        XCTAssertEqual(size.width, 560, accuracy: 1)
        XCTAssertLessThan(size.height, 480, "General Settings should fit its controls without the preview page's large empty region")
        XCTAssertGreaterThan(size.height, 300, "Retain space for the native controls and their explanations")
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
}
