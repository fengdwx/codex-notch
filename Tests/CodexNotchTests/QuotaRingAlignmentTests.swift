import AppKit
import SwiftUI
import XCTest
@testable import CodexNotch

final class QuotaRingAlignmentTests: XCTestCase {
    @MainActor
    func testRotatingGlintMaskKeepsItsCenterAndClearanceInLayerCoordinates() throws {
        _ = NSApplication.shared
        let hosting = NSHostingView(rootView: QuotaRing(
            style: .clockwiseRing,
            window: UsageWindow(id: "weekly", kind: .weekly, usedPercent: 99),
            activity: .running, diameter: 22, lineWidth: 2.25, fontSize: 9.5
        ).environment(\.notchMotionEnabled, true).padding(17))
        hosting.frame = NSRect(x: 0, y: 0, width: 56, height: 56)
        hosting.layoutSubtreeIfNeeded()
        func gradients(in view: NSView) -> [QuotaGradientLayerView] {
            (view as? QuotaGradientLayerView).map { [$0] }
                ?? view.subviews.flatMap { gradients(in: $0) }
        }
        let glintView = try XCTUnwrap(gradients(in: hosting).last)
        for size in [CGSize(width: 22, height: 22), CGSize(width: 30, height: 22)] {
            for origin in [CGPoint.zero, CGPoint(x: 2, y: -3)] {
                glintView.bounds = CGRect(origin: origin, size: size)
                glintView.layout()
                let root = try XCTUnwrap(glintView.layer)
                let glint = try XCTUnwrap(root.sublayers?.first)
                let mask = try XCTUnwrap(glint.mask as? CAShapeLayer,
                    "The animated glint must carry its circular clipping geometry in the same layer coordinates")
                let path = try XCTUnwrap(mask.path).boundingBoxOfPath
                for step in 0..<12 {
                    glint.transform = CATransform3DMakeRotation(CGFloat(step) * .pi / 6, 0, 0, 1)
                    let center = mask.convert(CGPoint(x: path.midX, y: path.midY), to: root)
                    XCTAssertEqual(center.x, glintView.bounds.midX, accuracy: 0.01)
                    XCTAssertEqual(center.y, glintView.bounds.midY, accuracy: 0.01)
                    XCTAssertEqual(path.width, path.height, accuracy: 0.01)
                    // The visible stroke ends at radius 8.5pt, leaving the
                    // existing quarter-point gap before the quota track.
                    XCTAssertEqual(path.width / 2 + mask.lineWidth / 2, 8.5, accuracy: 0.01)
                }
                glint.transform = CATransform3DIdentity
            }
        }
    }

    @MainActor
    func testHostedGlintStaysInsideOneConcentricTrackDuringRotation() async throws {
        _ = NSApplication.shared
        let hosting = NSHostingView(rootView: QuotaRing(
            style: .clockwiseRing,
            window: UsageWindow(id: "weekly", kind: .weekly, usedPercent: 99),
            activity: .running, diameter: 22, lineWidth: 2.25, fontSize: 9.5
        ).environment(\.notchMotionEnabled, true).padding(17).background(Color.black))
        hosting.sizingOptions = []
        hosting.frame = NSRect(x: 0, y: 0, width: 56, height: 56)
        let panel = NotchPanel(contentRect: hosting.frame)
        panel.contentView = hosting
        panel.orderFrontRegardless()
        defer { panel.orderOut(nil) }
        hosting.layoutSubtreeIfNeeded()
        func gradients(in view: NSView) -> [QuotaGradientLayerView] {
            (view as? QuotaGradientLayerView).map { [$0] }
                ?? view.subviews.flatMap { gradients(in: $0) }
        }
        let views = gradients(in: hosting)
        XCTAssertEqual(views.count, 2)
        for view in views { view.setAnimationRequested(false) }
        let glint = try XCTUnwrap(views.last?.layer?.sublayers?.first)
        let output = ProcessInfo.processInfo.environment["NOTCH_QUOTA_FRAMES"]
            .map { URL(fileURLWithPath: $0) }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        for step in 0..<12 {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            glint.transform = CATransform3DMakeRotation(CGFloat(step) * .pi / 6, 0, 0, 1)
            CATransaction.commit()
            panel.displayIfNeeded()
            NSApp.updateWindows()
            CATransaction.flush()
            try await Task.sleep(for: .milliseconds(40))
            let context = try XCTUnwrap(CGContext(
                data: nil, width: 112, height: 112, bitsPerComponent: 8, bytesPerRow: 112 * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.scaleBy(x: 2, y: 2)
            try XCTUnwrap(hosting.layer?.presentation()).render(in: context)
            let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
            var radii: [CGFloat] = []
            for y in 0..<112 {
                for x in 0..<112 {
                    let offset = (y * 112 + x) * 4
                    // Only the silver-blue glint is blue; the 1% quota is red,
                    // while the track and readable number are neutral.
                    if Int(bytes[offset + 2]) - Int(bytes[offset]) > 12 {
                        radii.append(hypot((CGFloat(x) + 0.5) / 2 - 28,
                                           (CGFloat(y) + 0.5) / 2 - 28))
                    }
                }
            }
            XCTAssertGreaterThan(radii.count, 10, "The glint must remain visible at phase \(step)")
            if let minimum = radii.min(), let maximum = radii.max() {
                XCTAssertGreaterThanOrEqual(minimum, 7, "The glint must not move towards the number at phase \(step)")
                XCTAssertLessThanOrEqual(maximum, 9, "The glint must stay inside the quota stroke at phase \(step)")
            }
            if let output {
                let image = NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))
                try XCTUnwrap(image.representation(using: .png, properties: [:])).write(
                    to: output.appendingPathComponent("phase-\(step).png"))
            }
        }
    }

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
        let glintView = try XCTUnwrap(views.first as? QuotaGradientLayerView)
        glintView.configure(color: QuotaInnerGlowMotion.color, isAnimating: false,
                            style: .innerGlow, circularMask: QuotaGradientCircularMask(inset: 3, lineWidth: 1))
        for view in views { host.addSubview(view) }
        for scale: CGFloat in [2, 1, 2] {
            window.testScale = scale
            for view in views {
                view.viewDidChangeBackingProperties()
                view.layoutSubtreeIfNeeded()
                let drawing = try XCTUnwrap(view.layer?.sublayers?.first)
                XCTAssertEqual(drawing.contentsScale, scale,
                               "The decorative ring must render at the same density as its hosting window")
                if let mask = drawing.mask {
                    XCTAssertEqual(mask.contentsScale, scale,
                                   "The circular clipping edge must use the gradient's pixel density")
                }
                let center = view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: host)
                XCTAssertEqual(center.x, 15, accuracy: 0.01)
                XCTAssertEqual(center.y, 16.5, accuracy: 0.01)
            }
        }
        glintView.configure(color: QuotaInnerGlowMotion.color, isAnimating: false)
        XCTAssertNil(glintView.layer?.sublayers?.first?.mask,
                     "The quota gradient must retain its independently trimmed SwiftUI mask")
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
