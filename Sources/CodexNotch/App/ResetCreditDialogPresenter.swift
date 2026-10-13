import AppKit

/// A native alert window with callbacks, never an application-modal run loop.
/// The notch's hover timers and main-actor tasks must continue while it is open.
final class ResetCreditDialogPresenter: NSObject, NSWindowDelegate {
    private var alert: NSAlert?
    private var completion: ((Bool) -> Void)?

    var window: NSWindow? { alert?.window }
    var isPresenting: Bool { alert != nil }

    func confirm(language: AppLanguage, completion: @escaping (Bool) -> Void) {
        guard !isPresenting else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = language.localized(chinese: "使用这次额度重置？", english: "Use this saved reset?")
        alert.informativeText = language.localized(
            chinese: "成功重置符合条件的额度时会消耗 1 次已存重置机会；如果无需重置，则保留该机会。周重置时间可能改变，成功后无法撤销。",
            english: "A successful reset of eligible usage limits consumes one saved reset. If no reset is needed, the credit is kept. Your weekly reset date may change. A successful reset cannot be undone."
        )
        alert.addButton(withTitle: language.localized(chinese: "取消", english: "Cancel"))
        alert.addButton(withTitle: language.localized(chinese: "使用重置", english: "Use reset"))
        present(alert, completion: completion)
    }

    func showResult(message: String, language: AppLanguage) {
        guard !isPresenting else { return }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = language.localized(chinese: "额度重置", english: "Usage reset")
        alert.informativeText = message
        alert.addButton(withTitle: language.localized(chinese: "好", english: "OK"))
        present(alert, completion: nil)
    }

    func dismiss() {
        finish(confirmed: false)
    }

    func bringToFront() {
        guard let window = alert?.window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func present(_ alert: NSAlert, completion: ((Bool) -> Void)?) {
        self.alert = alert
        self.completion = completion
        alert.layout()
        for (index, button) in alert.buttons.enumerated() {
            button.target = self
            button.action = #selector(buttonPressed(_:))
            button.tag = index
            // Confirmation requires its explicit button, not the default Return.
            button.keyEquivalent = index == 0 ? "\u{1b}" : ""
        }
        let window = alert.window
        window.defaultButtonCell = nil
        window.isReleasedWhenClosed = false
        window.styleMask.insert(.closable)
        window.delegate = self
        // The status surface uses popUpMenu level. Keep this short-lived window
        // above it, including while app-switch callbacks reassert the notch.
        window.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.center()
        bringToFront()
    }

    @objc private func buttonPressed(_ sender: NSButton) {
        finish(confirmed: sender.tag == 1)
    }

    func windowWillClose(_ notification: Notification) {
        finish(confirmed: false)
    }

    private func finish(confirmed: Bool) {
        guard let alert else { return }
        let callback = completion
        self.alert = nil
        completion = nil
        alert.window.delegate = nil
        alert.window.orderOut(nil)
        alert.window.close()
        callback?(confirmed)
    }
}
