import AppKit
import Foundation

final class NotchWindowController: NSWindowController {
    var onScreenParametersChanged: (() -> Void)?

    private var screenObserver: NSObjectProtocol?

    init() {
        let panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1))
        super.init(window: panel)
        observeScreenChanges()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        observeScreenChanges()
    }

    func apply(layout: NotchLayout, state: NotchPresentationState) {
        guard let panel = window as? NotchPanel else { return }
        let isHidden: Bool
        if case .hidden = state {
            isHidden = true
        } else {
            isHidden = false
        }

        if isHidden || layout.mode == .menuBarFallback {
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
            return
        }

        let frame = state.isExpanded ? layout.expandedFrame : layout.compactFrame
        panel.setFrame(frame, display: true)
        panel.ignoresMouseEvents = false
        panel.orderFrontRegardless()
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onScreenParametersChanged?()
        }
    }
}

private extension NotchPresentationState {
    var isExpanded: Bool {
        if case .expanded = self { return true }
        return false
    }
}
