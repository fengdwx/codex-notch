import AppKit

enum NotchPanelVisibilityPolicy {
    static func shouldKeepHiddenHoverSensor(
        layoutMode: NotchLayoutMode,
        displayIsEnabled: Bool
    ) -> Bool {
        layoutMode == .notch && !displayIsEnabled
    }

    static func shouldRestoreAfterApplicationSwitch(
        panelIsRequested: Bool,
        layoutMode: NotchLayoutMode,
        displayIsEnabled: Bool,
        isSuppressedByFullScreen: Bool = false
    ) -> Bool {
        guard panelIsRequested,
              layoutMode == .notch,
              !isSuppressedByFullScreen else {
            return false
        }
        // A hidden notch keeps a transparent sensor at the physical notch so
        // the user can hover back in and re-open the card.
        return displayIsEnabled
            || shouldKeepHiddenHoverSensor(
                layoutMode: layoutMode,
                displayIsEnabled: displayIsEnabled
            )
    }
}

final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        // Keep the panel across ordinary desktop spaces, but do not make it an
        // auxiliary surface in another app's native full-screen space. Video
        // and browser full-screen content should remain unobstructed.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenNone]
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
