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
    let hoverSensorFrame: NSRect
    let compactFrame: NSRect
    let quotaExpandedFrame: NSRect
    let expandedFrame: NSRect
}

enum NotchCompactLayout {
    static let sideWingWidth: CGFloat = 52
    static let minimumWidth: CGFloat = 289
    static let height: CGFloat = 32
}

enum NotchGeometry {
    static func layout(
        metrics: NotchScreenMetrics,
        compactSize: NSSize = NSSize(
            width: NotchCompactLayout.minimumWidth,
            height: NotchCompactLayout.height
        ),
        quotaExpandedSize: NSSize = NSSize(width: 420, height: 94),
        expandedSize: NSSize = NSSize(width: 420, height: 176)
    ) -> NotchLayout {
        guard let left = metrics.auxiliaryTopLeftArea,
              let right = metrics.auxiliaryTopRightArea,
              left.width > 0,
              right.width > 0,
              right.minX > left.maxX else {
            return NotchLayout(
                mode: .menuBarFallback,
                centerX: metrics.visibleFrame.midX,
                hoverSensorFrame: .zero,
                compactFrame: .zero,
                quotaExpandedFrame: .zero,
                expandedFrame: .zero
            )
        }

        let centerX = (left.maxX + right.minX) / 2
        // The auxiliary areas describe the safe regions beside the camera
        // cutout. Keep a full 52pt wing on each side: it gives a circular
        // indicator and its optional number independent breathing room.
        let notchWidth = right.minX - left.maxX
        let compactWidth = max(
            compactSize.width,
            notchWidth + NotchCompactLayout.sideWingWidth * 2
        )
        let compactHeight = min(
            compactSize.height,
            max(28, metrics.safeAreaInsets.top)
        )
        // Expanded panels attach to the top edge like a single Dynamic Island.
        // Their drawable content is still kept below this camera attachment.
        let cameraAttachmentHeight = max(0, metrics.safeAreaInsets.top)
        let quotaExpandedPanelSize = NSSize(
            width: quotaExpandedSize.width,
            height: quotaExpandedSize.height + cameraAttachmentHeight
        )
        let expandedPanelSize = NSSize(
            width: expandedSize.width,
            height: expandedSize.height + cameraAttachmentHeight
        )
        return NotchLayout(
            mode: .notch,
            centerX: centerX,
            hoverSensorFrame: frame(
                centeredAt: centerX,
                size: NSSize(width: notchWidth, height: compactHeight),
                screenFrame: metrics.frame,
                visibleFrame: metrics.visibleFrame,
                topInset: 0
            ),
            compactFrame: frame(
                centeredAt: centerX,
                size: NSSize(width: compactWidth, height: compactHeight),
                screenFrame: metrics.frame,
                visibleFrame: metrics.visibleFrame,
                topInset: 0
            ),
            quotaExpandedFrame: frame(
                centeredAt: centerX,
                size: quotaExpandedPanelSize,
                screenFrame: metrics.frame,
                visibleFrame: metrics.visibleFrame,
                topInset: 0
            ),
            expandedFrame: frame(
                centeredAt: centerX,
                size: expandedPanelSize,
                screenFrame: metrics.frame,
                visibleFrame: metrics.visibleFrame,
                topInset: 0
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
        // Expanded panels use topInset 0 so their shell is visually attached
        // to the camera. Their content receives the safe-area padding in
        // ExpandedNotchView, keeping text off the physical cutout.
        let y = screenFrame.maxY - min(max(0, topInset), screenFrame.height) - height
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
