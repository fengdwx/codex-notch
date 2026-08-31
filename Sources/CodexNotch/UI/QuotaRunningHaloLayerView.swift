import AppKit
import QuartzCore
import SwiftUI

enum QuotaRunningHaloMotion {
    static let duration: CFTimeInterval = 2.8
    static let visualDiameter: CGFloat = 24
    static let lineWidth: CGFloat = 1.4
    static let minimumOpacity: Float = 0.06
    static let maximumOpacity: Float = 0.24
    static let minimumScale: CGFloat = 0.92
    static let maximumScale: CGFloat = 1.02

    static func shouldAnimate(
        layoutMode: NotchLayoutMode,
        activity: QuotaRingActivity,
        hasQuota: Bool,
        motionEnabled: Bool
    ) -> Bool {
        layoutMode == .notch
            && activity == .running
            && hasQuota
            && motionEnabled
    }
}

struct QuotaRunningHaloView: NSViewRepresentable {
    let isAnimating: Bool

    func makeNSView(context _: Context) -> QuotaRunningHaloLayerView {
        let view = QuotaRunningHaloLayerView(frame: .zero)
        view.setAnimationRequested(isAnimating)
        return view
    }

    func updateNSView(
        _ nsView: QuotaRunningHaloLayerView,
        context _: Context
    ) {
        nsView.setAnimationRequested(isAnimating)
    }

    static func dismantleNSView(
        _ nsView: QuotaRunningHaloLayerView,
        coordinator _: ()
    ) {
        nsView.setAnimationRequested(false)
    }
}

final class QuotaRunningHaloLayerView: QuotaAnimatedLayerView {
    private enum AnimationKey {
        static let pulse = "quota.running.halo.pulse"
    }

    private let haloLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }

    override func layout() {
        super.layout()
        updateHaloPath()
    }

    override func startLayerAnimation() {
        guard haloLayer.animation(forKey: AnimationKey.pulse) == nil else {
            return
        }

        haloLayer.opacity = QuotaRunningHaloMotion.maximumOpacity
        haloLayer.add(makePulseAnimation(), forKey: AnimationKey.pulse)
    }

    override func stopLayerAnimation() {
        haloLayer.removeAnimation(forKey: AnimationKey.pulse)
        haloLayer.opacity = 0
        haloLayer.transform = CATransform3DIdentity
    }

    private func configureLayer() {
        wantsLayer = true
        layer?.masksToBounds = false

        haloLayer.fillColor = nil
        haloLayer.strokeColor = NSColor(
            calibratedRed: 0.38,
            green: 0.72,
            blue: 1.0,
            alpha: 1
        ).cgColor
        haloLayer.lineWidth = QuotaRunningHaloMotion.lineWidth
        haloLayer.opacity = 0
        layer?.addSublayer(haloLayer)
    }

    private func updateHaloPath() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let diameter = min(
            QuotaRunningHaloMotion.visualDiameter,
            min(bounds.width, bounds.height)
        )
        let inset = (
            min(bounds.width, bounds.height) - diameter
        ) / 2 + QuotaRunningHaloMotion.lineWidth / 2
        let pathRect = bounds.insetBy(dx: inset, dy: inset)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        haloLayer.frame = bounds
        haloLayer.path = CGPath(ellipseIn: pathRect, transform: nil)
        CATransaction.commit()
    }

    private func makePulseAnimation() -> CAAnimationGroup {
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [
            QuotaRunningHaloMotion.minimumOpacity,
            QuotaRunningHaloMotion.maximumOpacity,
            QuotaRunningHaloMotion.minimumOpacity
        ]
        opacity.keyTimes = [0, 0.5, 1]
        opacity.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [
            QuotaRunningHaloMotion.minimumScale,
            QuotaRunningHaloMotion.maximumScale,
            QuotaRunningHaloMotion.minimumScale
        ]
        scale.keyTimes = [0, 0.5, 1]
        scale.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]

        let animation = CAAnimationGroup()
        animation.animations = [opacity, scale]
        animation.duration = QuotaRunningHaloMotion.duration
        animation.repeatCount = .infinity
        animation.preferredFrameRateRange = CAFrameRateRange(
            minimum: QuotaLayerAnimationPolicy.preferredFramesPerSecond,
            maximum: QuotaLayerAnimationPolicy.preferredFramesPerSecond,
            preferred: QuotaLayerAnimationPolicy.preferredFramesPerSecond
        )
        return animation
    }
}
