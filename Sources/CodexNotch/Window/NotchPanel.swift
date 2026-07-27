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
        displayIsEnabled: Bool
    ) -> Bool {
        guard panelIsRequested,
              layoutMode == .notch else {
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
        // The notch is a persistent status surface. Keep it available when the
        // frontmost app enters its own native full-screen Space.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
