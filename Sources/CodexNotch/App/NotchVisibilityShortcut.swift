import Carbon.HIToolbox
import Foundation

enum NotchVisibilityShortcutConfiguration {
    static let keyCode = UInt32(kVK_ANSI_N)
    static let modifiers = UInt32(optionKey | cmdKey)
    static let displayText = "⌥⌘N"
    static let hotKeySignature = OSType(0x434E_4F54) // "CNOT"
    static let hotKeyIdentifier: UInt32 = 1
}

final class NotchVisibilityShortcut {
    private let onPress: () -> Void
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
        register()
    }

    deinit {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    private func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handler: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let shortcut = Unmanaged<NotchVisibilityShortcut>
                .fromOpaque(userData)
                .takeUnretainedValue()
            shortcut.handlePress()
            return noErr
        }
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard handlerStatus == noErr else {
            NSLog("CodexNotch could not install the visibility shortcut handler: \(handlerStatus)")
            return
        }

        let identifier = EventHotKeyID(
            signature: NotchVisibilityShortcutConfiguration.hotKeySignature,
            id: NotchVisibilityShortcutConfiguration.hotKeyIdentifier
        )
        let hotKeyStatus = RegisterEventHotKey(
            NotchVisibilityShortcutConfiguration.keyCode,
            NotchVisibilityShortcutConfiguration.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        guard hotKeyStatus == noErr else {
            NSLog("CodexNotch could not register \(NotchVisibilityShortcutConfiguration.displayText): \(hotKeyStatus)")
            if let eventHandler {
                RemoveEventHandler(eventHandler)
                self.eventHandler = nil
            }
            return
        }
    }

    private func handlePress() {
        DispatchQueue.main.async { [weak self] in
            self?.onPress()
        }
    }
}
