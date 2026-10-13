import AppKit
import QuartzCore
import SwiftUI
import XCTest
@testable import CodexNotch

final class FloatingFlowTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    @MainActor
    func testRunningAndIdleFlowAreSingleCenteredLinesWithoutText() throws {
        _ = NSApplication.shared
        for language in [AppLanguage.english, .chinese] {
            for (activity, expectedWidth) in [(QuotaRingActivity.running, CGFloat(96)), (.idle, 64)] {
                let bitmap = try renderFlow(activity: activity, language: language)
                let bounds = try visibleBounds(bitmap)
                XCTAssertLessThanOrEqual(bounds.height, 6,
                    "Flow must be one thin line, not a label stacked above a line")
                XCTAssertEqual(bounds.width, expectedWidth, accuracy: 1,
                    "Running and idle retain different line geometry even without color")
                XCTAssertEqual(bounds.midX, 68, accuracy: 0.75)
                XCTAssertEqual(bounds.midY, 15, accuracy: 0.75,
                    "The line belongs at the vertical center of the 30pt compact bar")
            }
        }
    }

    @MainActor
    func testCompletionFlowShowsOnlyOneCenteredCheck() throws {
        _ = NSApplication.shared
        let bitmap = try renderFlow(activity: .completed, language: .english)
        let bounds = try visibleBounds(bitmap)
        XCTAssertGreaterThan(bounds.height, 6, "Completion must not look like another thin line")
        XCTAssertLessThanOrEqual(bounds.width, 18, "No completion label or second line beside the check")
        XCTAssertLessThanOrEqual(bounds.height, 18)
        XCTAssertEqual(bounds.midX, 68, accuracy: 1)
        XCTAssertEqual(bounds.midY, 15, accuracy: 1)
    }

    @MainActor
    func testMotionDisabledRunningFlowRetainsABrightSegment() throws {
        _ = NSApplication.shared
        let bitmap = try renderFlow(activity: .running, language: .english)
        // Exclude rounded ends. Sample the centered capsule itself, not text
        // or a second row, and composite its colors over the real black surface.
        let brightness = try (56..<216).map { x -> CGFloat in
            let color = try XCTUnwrap(bitmap.colorAt(x: x, y: 30)?.usingColorSpace(.sRGB))
            return max(color.redComponent, color.greenComponent, color.blueComponent) * color.alphaComponent
        }
        let minimum = try XCTUnwrap(brightness.min())
        let maximum = try XCTUnwrap(brightness.max())
        XCTAssertGreaterThan(minimum, 0.02, "The running capsule must remain visible along its length")
        XCTAssertGreaterThan(maximum - minimum, 0.12,
                             "Turning off motion retains a bright segment instead of removing activity feedback")
    }

    @MainActor
    func testRepeatedFlowConfigurationKeepsTheExistingSweepPhase() throws {
        let view = FloatingCenterLayerView(frame: NSRect(x: 0, y: 0, width: 96, height: 4))
        view.configure(style: .flow, activity: .running, isAnimating: true)
        view.layout()
        // Install the native animation directly; this deterministic guard does
        // not claim that an offscreen test has verified real displayed motion.
        view.startLayerAnimation()
        let layer = try XCTUnwrap(view.layer?.sublayers?.first {
            !($0.animationKeys()?.isEmpty ?? true)
        })
        let key = try XCTUnwrap(layer.animationKeys()?.first)
        let animation = try XCTUnwrap(layer.animation(forKey: key)?.copy() as? CABasicAnimation)
        XCTAssertEqual(animation.keyPath, "transform.translation.x")
        XCTAssertGreaterThan(try XCTUnwrap(animation.toValue as? NSNumber).doubleValue, 96)
        XCTAssertGreaterThan(animation.duration, 0)
        animation.timeOffset = animation.duration * 0.4
        animation.setValue("flow-phase-guard", forKey: "testContinuity")
        layer.add(animation, forKey: key)

        for _ in 0..<4 {
            view.configure(style: .flow, activity: .running, isAnimating: true)
            view.layout()
            let retained = try XCTUnwrap(layer.animation(forKey: key))
            XCTAssertEqual(retained.timeOffset, animation.timeOffset)
            XCTAssertEqual(retained.value(forKey: "testContinuity") as? String, "flow-phase-guard",
                           "A routine clock/configuration update must not replace the running sweep")
        }
        view.viewWillMove(toWindow: nil)
        XCTAssertTrue(layer.animationKeys()?.isEmpty ?? true)
    }

    @MainActor
    private func renderFlow(activity: QuotaRingActivity, language: AppLanguage) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content:
            FloatingCenterContent(
                style: .flow, customText: "Must not show", activity: activity,
                startedAt: now.addingTimeInterval(-138), now: now, isExpanded: false
            )
            .environment(\.notchMotionEnabled, false)
            .environment(\.notchAppLanguage, language)
            .frame(width: 136, height: 30)
        )
        renderer.scale = 2
        return NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
    }

    private func visibleBounds(_ bitmap: NSBitmapImageRep) throws -> CGRect {
        var bounds = CGRect.null
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.05 else { continue }
                bounds = bounds.union(CGRect(x: CGFloat(x) / 2, y: CGFloat(y) / 2, width: 0.5, height: 0.5))
            }
        }
        XCTAssertFalse(bounds.isNull, "A visible line or check must remain with animations disabled")
        return bounds
    }
}
