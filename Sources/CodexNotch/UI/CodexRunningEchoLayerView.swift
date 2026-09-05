import AppKit
import QuartzCore
import SwiftUI

enum CodexRunningEchoMotion {
    static let duration: CFTimeInterval = 2.6
    static let minimumScale: CGFloat = 1.02
    static let maximumScale: CGFloat = 1.17
    static let minimumOpacity: Float = 0.22
    static let maximumOpacity: Float = 0.62
}

struct CodexRunningEchoLayer: NSViewRepresentable {
    let isAnimating: Bool

    func makeNSView(context _: Context) -> CodexRunningEchoLayerView {
        let view = CodexRunningEchoLayerView(frame: .zero)
        view.setAccessibilityElement(false)
        view.setAnimationRequested(isAnimating)
        return view
    }

    func updateNSView(_ view: CodexRunningEchoLayerView, context _: Context) {
        view.setAnimationRequested(isAnimating)
    }

    static func dismantleNSView(_ view: CodexRunningEchoLayerView, coordinator _: ()) {
        view.setAnimationRequested(false)
    }
}

final class CodexRunningEchoLayerView: QuotaAnimatedLayerView {
    private static let animationKey = "codex.running.echo.pulse"
    private let echoLayer = CALayer()
    private let silhouetteMask = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        echoLayer.backgroundColor = NSColor(srgbRed: 0.38, green: 0.66, blue: 1, alpha: 1).cgColor
        silhouetteMask.contents = CodexMarkAsset.templateImage?.cgImage(
            forProposedRect: nil, context: nil, hints: nil
        )
        silhouetteMask.contentsGravity = .resizeAspect
        echoLayer.mask = silhouetteMask
        layer?.addSublayer(echoLayer)
        stopLayerAnimation()
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        echoLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        echoLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        silhouetteMask.frame = echoLayer.bounds
        silhouetteMask.contentsScale = window?.backingScaleFactor ?? 2
        CATransaction.commit()
    }

    override func startLayerAnimation() {
        guard echoLayer.animation(forKey: Self.animationKey) == nil else { return }

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [
            CodexRunningEchoMotion.minimumScale,
            CodexRunningEchoMotion.maximumScale,
            CodexRunningEchoMotion.minimumScale
        ]
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [
            CodexRunningEchoMotion.minimumOpacity,
            CodexRunningEchoMotion.maximumOpacity,
            CodexRunningEchoMotion.minimumOpacity
        ]
        for animation in [scale, opacity] {
            animation.keyTimes = [0, 0.5, 1]
            animation.timingFunctions = [
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut)
            ]
        }
        let pulse = CAAnimationGroup()
        pulse.animations = [scale, opacity]
        pulse.duration = CodexRunningEchoMotion.duration
        pulse.repeatCount = .infinity
        pulse.preferredFrameRateRange = QuotaLayerAnimationPolicy.frameRateRange
        echoLayer.add(pulse, forKey: Self.animationKey)
    }

    override func stopLayerAnimation() {
        echoLayer.removeAnimation(forKey: Self.animationKey)
        // Match the existing static blue echo while the surface is inactive.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        echoLayer.opacity = 0.38
        echoLayer.transform = CATransform3DMakeScale(1.05, 1.05, 1)
        CATransaction.commit()
    }
}
