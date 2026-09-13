import AppKit
import SwiftUI
import XCTest
@testable import CodexNotch

final class QuotaRingAlignmentTests: XCTestCase {
    @MainActor
    func testDecorativeLayersFollowTheWindowsPixelDensity() throws {
        _ = NSApplication.shared
        let window = AlignmentTestWindow(
            contentRect: NSRect(x: 0, y: 0, width: 80, height: 33),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        let host = NSView(frame: window.contentLayoutRect)
        window.contentView = host
        let views: [QuotaAnimatedLayerView] = [
            QuotaGradientLayerView(frame: NSRect(x: 4, y: 5.5, width: 22, height: 22)),
            QuotaRunningHaloLayerView(frame: NSRect(x: 3, y: 4.5, width: 24, height: 24))
        ]
        for view in views { host.addSubview(view) }
        for scale: CGFloat in [2, 1, 2] {
            window.testScale = scale
            for view in views {
                view.viewDidChangeBackingProperties()
                view.layoutSubtreeIfNeeded()
                let drawing = try XCTUnwrap(view.layer?.sublayers?.first)
                XCTAssertEqual(drawing.contentsScale, scale,
                               "The decorative ring must render at the same density as its hosting window")
                let center = view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: host)
                XCTAssertEqual(center.x, 15, accuracy: 0.01)
                XCTAssertEqual(center.y, 16.5, accuracy: 0.01)
            }
        }
    }

    @MainActor
    func testHaloRemainsConcentricWhenHostingBoundsHaveAnOrigin() throws {
        let view = QuotaRunningHaloLayerView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        for origin in [CGPoint.zero, CGPoint(x: 2, y: 2), CGPoint(x: -3, y: 1)] {
            view.bounds.origin = origin
            view.layout()
            let root = try XCTUnwrap(view.layer)
            let halo = try XCTUnwrap(root.sublayers?.first as? CAShapeLayer)
            let path = try XCTUnwrap(halo.path).boundingBoxOfPath
            let center = halo.convert(CGPoint(x: path.midX, y: path.midY), to: root)
            XCTAssertEqual(center.x, view.bounds.midX, accuracy: 0.01,
                           "The halo path must use layer-local coordinates, not offset view bounds")
            XCTAssertEqual(center.y, view.bounds.midY, accuracy: 0.01)
            XCTAssertEqual(path.width, path.height, accuracy: 0.01)
        }
        view.setFrameSize(NSSize(width: 30, height: 24))
        view.layout()
        let root = try XCTUnwrap(view.layer)
        let halo = try XCTUnwrap(root.sublayers?.first as? CAShapeLayer)
        let path = try XCTUnwrap(halo.path).boundingBoxOfPath
        XCTAssertEqual(path.width, path.height, accuracy: 0.01,
                       "A rectangular host must not stretch the halo into an ellipse")
        let center = halo.convert(CGPoint(x: path.midX, y: path.midY), to: root)
        XCTAssertEqual(center.x, view.bounds.midX, accuracy: 0.01)
        XCTAssertEqual(center.y, view.bounds.midY, accuracy: 0.01)
    }

    @MainActor
    func testHostedGlintSharesTheQuotaRingsBoundsAndCenter() throws {
        _ = NSApplication.shared
        let usage = UsageWindow(id: "weekly", kind: .weekly, usedPercent: 41,
                                resetAt: Date(timeIntervalSince1970: 1_790_000_000))
        let hosting = NSHostingView(rootView: QuotaRing(
            style: .clockwiseRing, window: usage, activity: .running,
            diameter: 22, lineWidth: 2.25, fontSize: 9.5
        ).environment(\.notchMotionEnabled, true).padding(17))
        hosting.frame = NSRect(x: 0, y: 0, width: 56, height: 56)
        hosting.layoutSubtreeIfNeeded()
        func gradients(in view: NSView) -> [QuotaGradientLayerView] {
            (view as? QuotaGradientLayerView).map { [$0] }
                ?? view.subviews.flatMap { gradients(in: $0) }
        }
        let layers = gradients(in: hosting)
        XCTAssertEqual(layers.count, 2, "The quota arc and independent glint must both render")
        for view in layers {
            let rect = view.convert(view.bounds, to: hosting)
            XCTAssertEqual(rect.width, 22, accuracy: 0.01)
            XCTAssertEqual(rect.height, 22, accuracy: 0.01)
            XCTAssertEqual(rect.midX, hosting.bounds.midX, accuracy: 0.01)
            XCTAssertEqual(rect.midY, hosting.bounds.midY, accuracy: 0.01)
            view.bounds.origin = CGPoint(x: 2, y: -3)
            view.layout()
            let gradient = try XCTUnwrap(view.layer?.sublayers?.first)
            XCTAssertEqual(gradient.bounds.origin, .zero)
            XCTAssertEqual(gradient.position.x, view.bounds.midX, accuracy: 0.01)
            XCTAssertEqual(gradient.position.y, view.bounds.midY, accuracy: 0.01)
        }
    }
}

@MainActor
private final class AlignmentTestWindow: NSWindow {
    var testScale: CGFloat = 2
    override var backingScaleFactor: CGFloat { testScale }
}
