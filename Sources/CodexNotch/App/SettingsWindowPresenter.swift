import AppKit
import SwiftUI

enum SettingsWindowPresenter {
    private static let swiftUISettingsWindowIdentifier = "com_apple_SwiftUI_Settings_window"
    private static let nativeSettingsWindowIdentifier = "com.david.codexnotch.settings.window"
    @MainActor private static var ownedSettingsWindow: NSWindow?

    static func isSettingsWindow(_ window: NSWindow) -> Bool {
        let identifier = window.identifier?.rawValue
        return identifier == nativeSettingsWindowIdentifier
            || identifier == swiftUISettingsWindowIdentifier
            || window.title == "CodexNotch Settings"
    }

    @MainActor
    static func show(createWindow: () -> Void) {
        // A visible Settings window does not appear again when its link is
        // clicked. Make activation part of every request, including reopens.
        if let window = settingsWindow {
            bringToFront(window)
        } else {
            createWindow()
            bringToFront()
        }
    }

    @MainActor
    static func showNativeSettings() {
        let window = createNativeSettingsWindow()
        // Activate synchronously inside the user's click event so macOS 14+
        // cooperative activation makes this LSUIElement (.accessory) app active
        // and key immediately (colored traffic lights & accent-blue toggles).
        activateAndFocus(window)
        // Clicking inside a .nonactivatingPanel can finish tracking after the
        // button action returns; re-assert focus once tracking settles.
        for delay in [0.05, 0.16] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard window.isVisible, !window.isKeyWindow || !NSApp.isActive else { return }
                activateAndFocus(window)
            }
        }
    }

    @MainActor
    @discardableResult
    static func createNativeSettingsWindow() -> NSWindow {
        if let existing = ownedSettingsWindow {
            return existing
        }

        let size = NSSize(
            width: NotchSettingsLayout.windowWidth,
            height: NotchSettingsLayout.windowHeight
        )
        let hostingController = NSHostingController(rootView: NotchSettingsView())
        hostingController.sizingOptions = []
        hostingController.safeAreaRegions = []

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier(nativeSettingsWindowIdentifier)
        window.title = "CodexNotch Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        let toolbar = NSToolbar(identifier: "com.david.codexnotch.settings.toolbar")
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        window.toolbar = toolbar
        window.toolbarStyle = .unifiedCompact
        window.isMovable = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentMinSize = size
        window.contentMaxSize = size
        window.contentViewController = hostingController
        window.setContentSize(size)
        window.center()

        ownedSettingsWindow = window
        return window
    }

    static func bringToFront(_ explicitWindow: NSWindow? = nil) {
        DispatchQueue.main.async {
            guard let window = explicitWindow ?? settingsWindow else { return }
            // Initial appearance and an explicit request can both arrive for
            // the same scene. Once it is active, leave popup-menu focus alone.
            guard !window.isVisible || !window.isKeyWindow
                || !window.isOnActiveSpace || !NSApp.isActive else { return }
            activateAndFocus(window)
        }
    }

    @MainActor
    private static func activateAndFocus(_ window: NSWindow) {
        // Settings may still belong to a different desktop. Bring it to
        // the current Space before activation instead of switching away.
        window.collectionBehavior.subtract([
            .canJoinAllSpaces, .fullScreenPrimary, .fullScreenNone
        ])
        window.collectionBehavior.formUnion([.moveToActiveSpace, .fullScreenAuxiliary])
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApp.activate()
        NSRunningApplication.current.activate(options: .activateAllWindows)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    @MainActor
    static func disposeOwnedSettingsWindowForTesting() {
        if let owned = ownedSettingsWindow {
            owned.identifier = nil
            owned.title = ""
            owned.orderOut(nil)
            owned.close()
        }
        ownedSettingsWindow = nil
    }

    @MainActor
    private static var settingsWindow: NSWindow? {
        if let owned = ownedSettingsWindow, isSettingsWindow(owned) {
            return owned
        }
        return NSApp.windows.first { window in
            isSettingsWindow(window)
                && window.alphaValue > 0
                && window.frame.width >= 100
                && window.frame.height >= 100
        }
    }
}
