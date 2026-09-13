import AppKit
import QuartzCore
import SwiftUI

struct FloatingCenterMotionLayer: NSViewRepresentable {
    let style: FloatingCenterStyle
    let activity: QuotaRingActivity
    let isAnimating: Bool

    func makeNSView(context _: Context) -> FloatingCenterLayerView {
        let view = FloatingCenterLayerView(frame: .zero)
        view.setAccessibilityElement(false)
        view.configure(style: style, activity: activity, isAnimating: isAnimating)
        return view
    }

    func updateNSView(_ view: FloatingCenterLayerView, context _: Context) {
        view.configure(style: style, activity: activity, isAnimating: isAnimating)
    }

    static func dismantleNSView(_ view: FloatingCenterLayerView, coordinator _: ()) {
        view.setAnimationRequested(false)
    }
}

final class FloatingCenterLayerView: QuotaAnimatedLayerView {
    private let track = CAShapeLayer()
    private let rotor = CALayer()
    private let bead = CALayer()
    private let glint = CAGradientLayer()
    private var style: FloatingCenterStyle = .orbit
    private var activity: QuotaRingActivity = .idle
    private var lastLayoutSize = CGSize.zero
    private static let animationKey = "floating.center.motion"

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.addSublayer(track)
        layer?.addSublayer(rotor)
        rotor.addSublayer(bead)
        layer?.addSublayer(glint)
        glint.startPoint = CGPoint(x: 0, y: 0.5)
        glint.endPoint = CGPoint(x: 1, y: 0.5)
        configure(style: .orbit, activity: .idle, isAnimating: false)
    }

    required init?(coder: NSCoder) { nil }

    func configure(style: FloatingCenterStyle, activity: QuotaRingActivity, isAnimating: Bool) {
        if self.style != style {
            setAnimationRequested(false)
            self.style = style
        }
        self.activity = activity
        let shouldAnimate = isAnimating && FloatingCenterMotionPolicy.shouldAnimate(
            style: style, activity: activity, motionEnabled: true, isExpanded: false
        )
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let color: NSColor
        switch activity {
        case .running: color = NSColor(srgbRed: 0.57, green: 0.78, blue: 0.94, alpha: 1)
        case .completed: color = NSColor(srgbRed: 0.48, green: 0.86, blue: 0.65, alpha: 1)
        case .idle: color = NSColor(white: 0.52, alpha: 1)
        }
        track.fillColor = style == .flow ? color.withAlphaComponent(0.22).cgColor : nil
        track.strokeColor = style == .orbit ? color.withAlphaComponent(0.28).cgColor : nil
        track.lineWidth = 1
        track.isHidden = style != .orbit && style != .flow
        bead.backgroundColor = color.cgColor
        if style == .signature {
            // Two matching periods keep a highlight inside the word and make
            // the repeat boundary visually identical to the starting phase.
            let alpha: [CGFloat] = [0.14, 0.32, 0.85, 0.32, 0.14, 0.32, 0.85, 0.32, 0.14]
            glint.colors = alpha.map { NSColor.white.withAlphaComponent($0).cgColor }
            glint.locations = alpha.indices.map { NSNumber(value: Double($0) / Double(alpha.count - 1)) }
        } else {
            glint.colors = [0, 0.6, 1, 0].map { color.withAlphaComponent($0).cgColor }
            glint.locations = [0, 0.35, 0.7, 1]
        }
        rotor.isHidden = style != .orbit
        glint.isHidden = (style != .flow && style != .signature) || !shouldAnimate
        CATransaction.commit()
        needsLayout = true
        setAnimationRequested(shouldAnimate)
    }

    override func layout() {
        super.layout()
        let geometryChanged = lastLayoutSize != bounds.size
        lastLayoutSize = bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        track.frame = bounds
        if style == .orbit {
            track.path = CGPath(ellipseIn: bounds.insetBy(dx: 2, dy: 2), transform: nil)
        } else {
            track.path = CGPath(roundedRect: bounds, cornerWidth: bounds.height / 2,
                                cornerHeight: bounds.height / 2, transform: nil)
        }
        rotor.bounds = CGRect(origin: .zero, size: bounds.size)
        rotor.position = CGPoint(x: bounds.midX, y: bounds.midY)
        bead.frame = CGRect(x: bounds.width / 2 - 1.75, y: bounds.height - 3.75, width: 3.5, height: 3.5)
        bead.cornerRadius = 1.75
        let highlightWidth = style == .signature ? bounds.width * 2 : 32
        glint.bounds = CGRect(x: 0, y: 0, width: highlightWidth, height: bounds.height)
        glint.position = CGPoint(x: style == .signature ? 0 : -highlightWidth / 2, y: bounds.midY)
        glint.cornerRadius = style == .signature ? 0 : bounds.height / 2
        CATransaction.commit()
        // SwiftUI may attach the view before assigning its nonzero frame.
        if geometryChanged {
            restartLayerAnimationAfterGeometryChange()
        } else {
            setAnimationRequested(animationIsRequested)
        }
    }

    override func startLayerAnimation() {
        let target: CALayer = style == .orbit ? rotor : glint
        guard target.animation(forKey: Self.animationKey) == nil else { return }
        if style == .signature {
            let animation = CABasicAnimation(keyPath: "transform.translation.x")
            animation.fromValue = 0
            animation.toValue = bounds.width
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.duration = 5
            animation.repeatCount = .infinity
            animation.preferredFrameRateRange = QuotaLayerAnimationPolicy.frameRateRange
            target.add(animation, forKey: Self.animationKey)
            return
        }
        let animation: CABasicAnimation
        if style == .orbit {
            animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = 0
            animation.toValue = Double.pi * 2
            animation.duration = 4.8
        } else {
            animation = CABasicAnimation(keyPath: "transform.translation.x")
            animation.fromValue = 0
            animation.toValue = bounds.width + 32
            animation.duration = 2.8
        }
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.repeatCount = .infinity
        animation.preferredFrameRateRange = QuotaLayerAnimationPolicy.frameRateRange
        target.add(animation, forKey: Self.animationKey)
    }

    override func stopLayerAnimation() {
        rotor.removeAnimation(forKey: Self.animationKey)
        glint.removeAnimation(forKey: Self.animationKey)
    }
}
