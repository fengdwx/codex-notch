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

extension NotchLayout {
    func frame(for state: NotchPresentationState) -> NSRect {
        switch state {
        case .hidden:
            hoverSensorFrame
        case .quotaCompact, .workingCompact, .completedCompact:
            compactFrame
        case let .expanded(content):
            content.conversations.isEmpty ? quotaExpandedFrame : expandedFrame
        }
    }
}

enum NotchCompactLayout {
    static let sideExtensionWidth: CGFloat = 36
    static let indicatorLaneWidth: CGFloat = 46
    static let minimumWidth: CGFloat = 257
    static let height: CGFloat = 32
    static let indicatorDiameter: CGFloat = 22
    static let quotaIndicatorOutwardOffset: CGFloat = 0
    static let appMarkSize: CGFloat = 18
    static let quotaRingLineWidth: CGFloat = 2.25
    static let quotaWaveBallBorderLineWidth: CGFloat = 1.75

    static var quotaIndicatorCameraClearance: CGFloat {
        sideExtensionWidth
            - (indicatorLaneWidth + indicatorDiameter) / 2
            + quotaIndicatorOutwardOffset
    }

    static var quotaIndicatorScreenEdgeClearance: CGFloat {
        (indicatorLaneWidth - indicatorDiameter) / 2
            - quotaIndicatorOutwardOffset
    }

    static func quotaIndicatorLineWidth(for style: QuotaDisplayStyle) -> CGFloat {
        switch style {
        case .clockwiseRing:
            quotaRingLineWidth
        case .waveBall:
            quotaWaveBallBorderLineWidth
        }
    }
}

enum NotchExpandedLayout {
    static let width: CGFloat = 420
    static let resetScheduleControlHeight: CGFloat = 39
    static let settingsFooterHeight: CGFloat = 30
    static let quotaContentHeight: CGFloat = 101 + resetScheduleControlHeight + settingsFooterHeight
    static let twoConversationContentHeight: CGFloat = 221 + resetScheduleControlHeight + settingsFooterHeight
    static let conversationRowHeight: CGFloat = 40
    static let conversationSeparatorHeight: CGFloat = 0.5
    static let resetScheduleRowHeight: CGFloat = 34
    static let resetScheduleDetailSpacing: CGFloat = 6
    static let resetScheduleDetailVerticalPadding: CGFloat = 6

    static func quotaContentSize(
        isResetScheduleExpanded: Bool = false,
        resetCreditCount: Int = 0
    ) -> NSSize {
        NSSize(
            width: width,
            height: quotaContentHeight + resetScheduleExpansionHeight(
                isExpanded: isResetScheduleExpanded,
                resetCreditCount: resetCreditCount
            )
        )
    }

    static func taskContentHeight(
        conversationCount: Int,
        isResetScheduleExpanded: Bool = false,
        resetCreditCount: Int = 0
    ) -> CGFloat {
        let count = max(1, conversationCount)
        return twoConversationContentHeight
            + CGFloat(count - 2)
            * (conversationRowHeight + conversationSeparatorHeight)
            + resetScheduleExpansionHeight(
                isExpanded: isResetScheduleExpanded,
                resetCreditCount: resetCreditCount
            )
    }

    static func taskContentSize(
        conversationCount: Int,
        isResetScheduleExpanded: Bool = false,
        resetCreditCount: Int = 0
    ) -> NSSize {
        NSSize(
            width: width,
            height: taskContentHeight(
                conversationCount: conversationCount,
                isResetScheduleExpanded: isResetScheduleExpanded,
                resetCreditCount: resetCreditCount
            )
        )
    }

    private static func resetScheduleExpansionHeight(
        isExpanded: Bool,
        resetCreditCount: Int
    ) -> CGFloat {
        guard isExpanded, resetCreditCount > 0 else { return 0 }
        let count = resetCreditCount
        return resetScheduleDetailSpacing
            + resetScheduleDetailVerticalPadding * 2
            + CGFloat(count) * resetScheduleRowHeight
            + CGFloat(count - 1) * conversationSeparatorHeight
    }
}

enum NotchGeometry {
    static func layout(
        metrics: NotchScreenMetrics,
        compactSize: NSSize = NSSize(
            width: NotchCompactLayout.minimumWidth,
            height: NotchCompactLayout.height
        ),
        quotaExpandedSize: NSSize = NSSize(
            width: NotchExpandedLayout.width,
            height: NotchExpandedLayout.quotaContentHeight
        ),
        expandedSize: NSSize = NSSize(
            width: NotchExpandedLayout.width,
            height: NotchExpandedLayout.twoConversationContentHeight
        )
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
        // cutout. Keep the visible island extension at 36pt per side; the
        // indicator lanes may be wider to balance their inner and outer gaps.
        let notchWidth = right.minX - left.maxX
        let compactWidth = max(
            compactSize.width,
            notchWidth + NotchCompactLayout.sideExtensionWidth * 2
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

/// Interpolates a panel from its current compact frame to its target frame
/// while holding the physical-notch edge fixed. AppKit's built-in window
/// animator resizes around a visual center on some releases, so the notch
/// panel uses these explicit frames instead.
enum NotchTopAnchoredFrameInterpolator {
    static func frame(
        from start: NSRect,
        to target: NSRect,
        progress: CGFloat
    ) -> NSRect {
        let clampedProgress = min(max(progress, 0), 1)
        let normalizedStart = NSRect(
            x: start.minX,
            y: target.maxY - start.height,
            width: start.width,
            height: start.height
        )
        let width = interpolated(
            from: normalizedStart.width,
            to: target.width,
            progress: clampedProgress
        )
        let height = interpolated(
            from: normalizedStart.height,
            to: target.height,
            progress: clampedProgress
        )
        let x = interpolated(
            from: normalizedStart.minX,
            to: target.minX,
            progress: clampedProgress
        )
        return NSRect(
            x: x,
            y: target.maxY - height,
            width: width,
            height: height
        )
    }

    private static func interpolated(
        from start: CGFloat,
        to target: CGFloat,
        progress: CGFloat
    ) -> CGFloat {
        start + (target - start) * progress
    }
}
