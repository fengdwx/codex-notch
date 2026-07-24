import AppKit

enum NotchPanelVisibilityPolicy {
    static func shouldRestoreAfterApplicationSwitch(
        panelIsRequested: Bool,
        layoutMode: NotchLayoutMode
    ) -> Bool {
        panelIsRequested && layoutMode == .notch
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
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
