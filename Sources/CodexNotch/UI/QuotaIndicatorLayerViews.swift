import AppKit
import QuartzCore
import SwiftUI

private enum QuotaLayerAnimationKey {
    static let ringRotation = "quota.ring.rotation"
    static let waveTranslation = "quota.wave.translation"
    static let waveLevel = "quota.wave.level"
}

class QuotaAnimatedLayerView: NSView {
    private var windowOcclusionObserver: NSObjectProtocol?
    private(set) var animationIsRequested = false
    private(set) var layerAnimationIsRunning = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopObservingWindow()

        if let window {
            windowOcclusionObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.refreshLayerAnimation()
            }
        }

        refreshLayerAnimation()
    }

    override func viewWillMove(toSuperview newSuperview: NSView?) {
        // SwiftUI can detach a representable before it receives a new window
        // or is dismantled. Stop immediately instead of relying on a later
        // occlusion notification that may never arrive for a detached view.
        if newSuperview == nil {
            stopLayerAnimation()
            layerAnimationIsRunning = false
        }
        super.viewWillMove(toSuperview: newSuperview)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        // `orderOut` changes occlusion, but a true window detachment does not
        // need to wait for that asynchronous notification.
        if newWindow == nil {
            stopLayerAnimation()
            layerAnimationIsRunning = false
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidHide() {
        super.viewDidHide()
        refreshLayerAnimation()
    }

    override func viewDidUnhide() {
        super.viewDidUnhide()
        refreshLayerAnimation()
    }

    func setAnimationRequested(_ requested: Bool) {
        guard animationIsRequested != requested else {
            refreshLayerAnimation()
            return
        }
        animationIsRequested = requested
        refreshLayerAnimation()
    }

    func restartLayerAnimationAfterGeometryChange() {
        guard layerAnimationIsRunning else {
            refreshLayerAnimation()
            return
        }
        stopLayerAnimation()
        layerAnimationIsRunning = false
        refreshLayerAnimation()
    }

    func startLayerAnimation() {}

    func stopLayerAnimation() {}

    private var surfaceIsVisible: Bool {
        guard let window else { return false }
        return window.isVisible
            && window.occlusionState.contains(.visible)
            && !isHiddenOrHasHiddenAncestor
            && bounds.width > 0
            && bounds.height > 0
    }

    private func refreshLayerAnimation() {
        let shouldRun = QuotaLayerAnimationPolicy.shouldRun(
            requested: animationIsRequested,
            surfaceIsVisible: surfaceIsVisible
        )
        guard shouldRun != layerAnimationIsRunning else { return }

        if shouldRun {
            startLayerAnimation()
        } else {
            stopLayerAnimation()
        }
        layerAnimationIsRunning = shouldRun
    }

    private func stopObservingWindow() {
        if let windowOcclusionObserver {
            NotificationCenter.default.removeObserver(windowOcclusionObserver)
            self.windowOcclusionObserver = nil
        }
    }

    deinit {
        stopObservingWindow()
    }
}

final class QuotaGradientLayerView: QuotaAnimatedLayerView {
    private let gradientLayer = CAGradientLayer()
    private var currentColor: QuotaColorScale.RGB?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        gradientLayer.type = .conic
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.locations = [0, 0.18, 0.36, 0.52, 0.66, 0.82, 1]
        layer?.addSublayer(gradientLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        CATransaction.performWithoutAnimation {
            gradientLayer.bounds = bounds
            gradientLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }

    func configure(
        color: QuotaColorScale.RGB,
        isAnimating: Bool
    ) {
        if currentColor != color {
            currentColor = color
            CATransaction.performWithoutAnimation {
                gradientLayer.colors = [
                    color.cgColor(alpha: 0.24),
                    color.cgColor(alpha: 0.42),
                    color.cgColor(alpha: 0.78),
                    color.cgColor(alpha: 1),
                    color.cgColor(alpha: 0.82),
                    color.cgColor(alpha: 0.46),
                    color.cgColor(alpha: 0.24)
                ]
            }
        }
        setAnimationRequested(isAnimating)
    }

    override func startLayerAnimation() {
        guard gradientLayer.animation(
            forKey: QuotaLayerAnimationKey.ringRotation
        ) == nil else {
            return
        }

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = Double.pi * 2
        rotation.duration = QuotaRingGradientMotion.duration
        rotation.repeatCount = .infinity
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        rotation.preferredFrameRateRange =
            QuotaLayerAnimationPolicy.frameRateRange
        gradientLayer.add(
            rotation,
            forKey: QuotaLayerAnimationKey.ringRotation
        )
    }

    override func stopLayerAnimation() {
        gradientLayer.removeAnimation(
            forKey: QuotaLayerAnimationKey.ringRotation
        )
        CATransaction.performWithoutAnimation {
            gradientLayer.transform = CATransform3DIdentity
        }
    }
}

struct QuotaGradientLayer: NSViewRepresentable {
    let color: QuotaColorScale.RGB
    let isAnimating: Bool

    func makeNSView(context _: Context) -> QuotaGradientLayerView {
        let view = QuotaGradientLayerView(frame: .zero)
        view.setAccessibilityElement(false)
        view.configure(color: color, isAnimating: isAnimating)
        return view
    }

    func updateNSView(
        _ nsView: QuotaGradientLayerView,
        context _: Context
    ) {
        nsView.configure(color: color, isAnimating: isAnimating)
    }

    static func dismantleNSView(
        _ nsView: QuotaGradientLayerView,
        coordinator _: ()
    ) {
        nsView.setAnimationRequested(false)
    }
}

final class QuotaWaveLayerView: QuotaAnimatedLayerView {
    private let waveLayer = CAShapeLayer()
    private var currentColor: QuotaColorScale.RGB?
    private var currentProgress: CGFloat = 0
    private var progressAnimationEnabled = false
    private var renderedSize = CGSize.zero
    private var wavelength: CGFloat = 0
    private var hasRenderedProgress = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        waveLayer.anchorPoint = .zero
        layer?.addSublayer(waveLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        guard bounds.size != renderedSize else { return }

        renderedSize = bounds.size
        rebuildWavePath(animated: false)
        restartLayerAnimationAfterGeometryChange()
    }

    func configure(
        color: QuotaColorScale.RGB,
        fillProgress: CGFloat,
        isAnimating: Bool,
        progressAnimationEnabled: Bool
    ) {
        if currentColor != color {
            currentColor = color
            CATransaction.performWithoutAnimation {
                waveLayer.fillColor = color.cgColor(alpha: 1)
            }
        }

        self.progressAnimationEnabled = progressAnimationEnabled
        let clampedProgress = min(max(fillProgress, 0), 1)
        if !hasRenderedProgress || currentProgress != clampedProgress {
            currentProgress = clampedProgress
            rebuildWavePath(
                animated: hasRenderedProgress && progressAnimationEnabled
            )
            hasRenderedProgress = true
        } else if !progressAnimationEnabled {
            waveLayer.removeAnimation(forKey: QuotaLayerAnimationKey.waveLevel)
        }

        setAnimationRequested(isAnimating)
    }

    override func startLayerAnimation() {
        guard wavelength > 0,
              waveLayer.animation(
                forKey: QuotaLayerAnimationKey.waveTranslation
              ) == nil else {
            return
        }

        let translation = CABasicAnimation(
            keyPath: "transform.translation.x"
        )
        translation.fromValue = 0
        translation.toValue = -wavelength
        translation.duration = Double.pi
        translation.repeatCount = .infinity
        translation.timingFunction = CAMediaTimingFunction(name: .linear)
        translation.preferredFrameRateRange =
            QuotaLayerAnimationPolicy.frameRateRange
        waveLayer.add(
            translation,
            forKey: QuotaLayerAnimationKey.waveTranslation
        )
    }

    override func stopLayerAnimation() {
        waveLayer.removeAnimation(
            forKey: QuotaLayerAnimationKey.waveTranslation
        )
        CATransaction.performWithoutAnimation {
            waveLayer.transform = CATransform3DIdentity
        }
    }

    private func rebuildWavePath(animated: Bool) {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let newWavelength = bounds.width / 1.35
        let pathWidth = bounds.width + newWavelength
        let newPath = makeWavePath(
            size: CGSize(width: pathWidth, height: bounds.height),
            wavelength: newWavelength,
            fillProgress: currentProgress
        )
        let previousPath = waveLayer.presentation()?.path ?? waveLayer.path

        CATransaction.performWithoutAnimation {
            waveLayer.bounds = CGRect(
                origin: .zero,
                size: CGSize(width: pathWidth, height: bounds.height)
            )
            waveLayer.position = .zero
            waveLayer.path = newPath
        }

        if animated, let previousPath {
            let level = CABasicAnimation(keyPath: "path")
            level.fromValue = previousPath
            level.toValue = newPath
            level.duration = 0.42
            level.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            waveLayer.add(level, forKey: QuotaLayerAnimationKey.waveLevel)
        } else {
            waveLayer.removeAnimation(forKey: QuotaLayerAnimationKey.waveLevel)
        }

        wavelength = newWavelength
    }

    private func makeWavePath(
        size: CGSize,
        wavelength: CGFloat,
        fillProgress: CGFloat
    ) -> CGPath {
        let level = size.height * fillProgress
        let amplitude = max(0.8, size.height * 0.075)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: level))

        let samples = max(
            28,
            Int(ceil(size.width / max(bounds.width, 1) * 28))
        )
        for index in 0...samples {
            let x = size.width * CGFloat(index) / CGFloat(samples)
            let angle = x / wavelength * CGFloat(Double.pi * 2)
            let y = level + sin(angle) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: size.width, y: 0))
        path.closeSubpath()
        return path
    }
}

struct QuotaWaveLayer: NSViewRepresentable {
    let color: QuotaColorScale.RGB
    let fillProgress: CGFloat
    let isAnimating: Bool
    let progressAnimationEnabled: Bool

    func makeNSView(context _: Context) -> QuotaWaveLayerView {
        let view = QuotaWaveLayerView(frame: .zero)
        view.setAccessibilityElement(false)
        view.configure(
            color: color,
            fillProgress: fillProgress,
            isAnimating: isAnimating,
            progressAnimationEnabled: progressAnimationEnabled
        )
        return view
    }

    func updateNSView(
        _ nsView: QuotaWaveLayerView,
        context _: Context
    ) {
        nsView.configure(
            color: color,
            fillProgress: fillProgress,
            isAnimating: isAnimating,
            progressAnimationEnabled: progressAnimationEnabled
        )
    }

    static func dismantleNSView(
        _ nsView: QuotaWaveLayerView,
        coordinator _: ()
    ) {
        nsView.setAnimationRequested(false)
    }
}

private extension QuotaLayerAnimationPolicy {
    static var frameRateRange: CAFrameRateRange {
        CAFrameRateRange(
            minimum: preferredFramesPerSecond,
            maximum: preferredFramesPerSecond,
            preferred: preferredFramesPerSecond
        )
    }
}

private extension QuotaColorScale.RGB {
    func cgColor(alpha: CGFloat) -> CGColor {
        NSColor(
            srgbRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: alpha
        ).cgColor
    }
}

private extension CATransaction {
    static func performWithoutAnimation(_ changes: () -> Void) {
        begin()
        setDisableActions(true)
        changes()
        commit()
    }
}
