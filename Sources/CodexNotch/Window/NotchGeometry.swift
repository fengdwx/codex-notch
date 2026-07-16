import AppKit
import Foundation

enum NotchLayoutMode: Equatable {
    case notch
    case menuBarFallback
}

struct NotchScreenMetrics {
    let frame: NSRect
    let visibleFrame: NSRect
    let safeAreaInsets: NSEdgeInsets
    let auxiliaryTopLeftArea: NSRect?
    let auxiliaryTopRightArea: NSRect?

    init(
        frame: NSRect,
        visibleFrame: NSRect,
        safeAreaInsets: NSEdgeInsets,
        auxiliaryTopLeftArea: NSRect?,
        auxiliaryTopRightArea: NSRect?
    ) {
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.safeAreaInsets = safeAreaInsets
        self.auxiliaryTopLeftArea = auxiliaryTopLeftArea
        self.auxiliaryTopRightArea = auxiliaryTopRightArea
    }

    init(screen: NSScreen) {
        self.init(
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            safeAreaInsets: screen.safeAreaInsets,
            auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
            auxiliaryTopRightArea: screen.auxiliaryTopRightArea
        )
    }
}

struct NotchLayout: Equatable {
    let mode: NotchLayoutMode
    let centerX: CGFloat
    let compactFrame: NSRect
    let expandedFrame: NSRect
}

enum NotchGeometry {
    static func layout(
        metrics: NotchScreenMetrics,
        compactSize: NSSize = NSSize(width: 272, height: 32),
        expandedSize: NSSize = NSSize(width: 720, height: 180)
    ) -> NotchLayout {
        guard let left = metrics.auxiliaryTopLeftArea,
              let right = metrics.auxiliaryTopRightArea,
              left.width > 0,
              right.width > 0,
              right.minX > left.maxX else {
            return NotchLayout(
                mode: .menuBarFallback,
                centerX: metrics.visibleFrame.midX,
                compactFrame: .zero,
                expandedFrame: .zero
            )
        }

        let centerX = (left.maxX + right.minX) / 2
        // The auxiliary areas describe the safe regions beside the camera
        // cutout. Keep the compact badge close to that gap instead of using a
        // wide fixed pill that covers the user's window.
        let notchWidth = right.minX - left.maxX
        let compactWidth = min(compactSize.width, max(260, notchWidth + 86))
        let compactHeight = min(
            compactSize.height,
            max(28, metrics.safeAreaInsets.top)
        )
        return NotchLayout(
            mode: .notch,
            centerX: centerX,
            compactFrame: frame(
                centeredAt: centerX,
                size: NSSize(width: compactWidth, height: compactHeight),
                screenFrame: metrics.frame,
                visibleFrame: metrics.visibleFrame,
                topInset: 0
            ),
            expandedFrame: frame(
                centeredAt: centerX,
                size: expandedSize,
                screenFrame: metrics.frame,
                visibleFrame: metrics.visibleFrame,
                topInset: metrics.safeAreaInsets.top
            )
        )
    }

    private static func frame(
        centeredAt centerX: CGFloat,
        size: NSSize,
        screenFrame: NSRect,
        visibleFrame: NSRect,
        topInset: CGFloat = 0
    ) -> NSRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, screenFrame.height)
        let minX = visibleFrame.minX
        let maxX = max(minX, visibleFrame.maxX - width)
        let proposedX = centerX - width / 2
        let x = min(max(proposedX, minX), maxX)
        // A MacBook's central top area is a physical cutout, not drawable
        // pixels. Place the panel below the safe-area inset so its text is
        // rendered on the display rather than behind the camera.
        let y = screenFrame.maxY - min(max(0, topInset), screenFrame.height) - height
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
