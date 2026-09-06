import AppKit
import QuartzCore
import SwiftUI

enum StatusMarkEchoMotion {
    static let duration: CFTimeInterval = 2.6
    static let minimumScale: CGFloat = 1.02
    static let maximumScale: CGFloat = 1.17
    static let minimumOpacity: Float = 0.22
    static let maximumOpacity: Float = 0.62
}

struct StatusMarkEchoLayer: NSViewRepresentable {
    let isAnimating: Bool
    let iconStyle: StatusIconStyle
    let color: QuotaColorScale.RGB

    func makeNSView(context _: Context) -> StatusMarkEchoLayerView {
        let view = StatusMarkEchoLayerView(frame: .zero)
        view.setAccessibilityElement(false)
        view.configure(iconStyle: iconStyle, color: color, isAnimating: isAnimating)
        return view
    }

    func updateNSView(_ view: StatusMarkEchoLayerView, context _: Context) {
        view.configure(iconStyle: iconStyle, color: color, isAnimating: isAnimating)
    }

    static func dismantleNSView(_ view: StatusMarkEchoLayerView, coordinator _: ()) {
        view.setAnimationRequested(false)
    }
}

final class StatusMarkEchoLayerView: QuotaAnimatedLayerView {
    private static let animationKey = "codex.running.echo.pulse"
    private let echoLayer = CALayer()
    private let silhouetteMask = CALayer()
    private var iconStyle: StatusIconStyle?
    private var currentColor: QuotaColorScale.RGB?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        silhouetteMask.contentsGravity = .resizeAspect
        echoLayer.mask = silhouetteMask
        layer?.addSublayer(echoLayer)
        configure(iconStyle: .defaultStyle, isAnimating: false)
        stopLayerAnimation()
    }

    required init?(coder: NSCoder) { nil }

    func configure(
        iconStyle: StatusIconStyle,
        color: QuotaColorScale.RGB = StatusIconTheme(usage: nil).accent,
        isAnimating: Bool
    ) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if self.iconStyle != iconStyle {
            self.iconStyle = iconStyle
            silhouetteMask.contents = iconStyle.templateImage?.cgImage(
                forProposedRect: nil, context: nil, hints: nil
            )
        }
        if currentColor != color {
            currentColor = color
            echoLayer.backgroundColor = NSColor(
                srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1
            ).cgColor
        }
        CATransaction.commit()
        setAnimationRequested(isAnimating)
    }

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
            StatusMarkEchoMotion.minimumScale,
            StatusMarkEchoMotion.maximumScale,
            StatusMarkEchoMotion.minimumScale
        ]
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [
            StatusMarkEchoMotion.minimumOpacity,
            StatusMarkEchoMotion.maximumOpacity,
            StatusMarkEchoMotion.minimumOpacity
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
        pulse.duration = StatusMarkEchoMotion.duration
        pulse.repeatCount = .infinity
        pulse.preferredFrameRateRange = QuotaLayerAnimationPolicy.frameRateRange
        echoLayer.add(pulse, forKey: Self.animationKey)
    }

    override func stopLayerAnimation() {
        echoLayer.removeAnimation(forKey: Self.animationKey)
        // Preserve the themed static echo while the surface is inactive.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        echoLayer.opacity = 0.38
        echoLayer.transform = CATransform3DMakeScale(1.05, 1.05, 1)
        CATransaction.commit()
    }
}
