import AppKit

enum SettingsWindowPresenter {
    private static let settingsWindowIdentifier = "com_apple_SwiftUI_Settings_window"

    static func isSettingsWindow(_ window: NSWindow) -> Bool {
        window.identifier?.rawValue == settingsWindowIdentifier
            || window.title == "CodexNotch Settings"
    }

    static func show(createWindow: () -> Void) {
        // A visible Settings scene does not appear again when its link is
        // clicked. Make activation part of every request, including reopens.
        if let window = settingsWindow {
            bringToFront(window)
        } else {
            createWindow()
            bringToFront()
        }
    }

    static func bringToFront(_ explicitWindow: NSWindow? = nil) {
        DispatchQueue.main.async {
            guard let window = explicitWindow ?? settingsWindow else { return }
            // Settings may still belong to a different desktop. Bring it to
            // the current Space before activation instead of switching away.
            window.collectionBehavior.subtract([
                .canJoinAllSpaces, .fullScreenPrimary, .fullScreenNone
            ])
            window.collectionBehavior.formUnion([.moveToActiveSpace, .fullScreenAuxiliary])
            NSApp.activate(ignoringOtherApps: true)
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    private static var settingsWindow: NSWindow? {
        NSApp.windows.first(where: isSettingsWindow)
    }
}
