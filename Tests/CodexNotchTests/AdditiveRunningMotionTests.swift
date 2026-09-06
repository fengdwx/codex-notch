import AppKit
import QuartzCore
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
}
