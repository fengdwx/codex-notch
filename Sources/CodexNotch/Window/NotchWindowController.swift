import AppKit
import Foundation
import SwiftUI

final class NotchWindowController: NSWindowController {
    var onScreenParametersChanged: (() -> Void)?
    var onOpenThread: ((String) -> Void)?
    var onActivateChatGPT: (() -> Void)?

    private var screenObserver: NSObjectProtocol?
    private var hostingView: NSHostingView<AnyView>?
    private var statusItem: NSStatusItem?
    private var lastPresentedExpanded: Bool?

    init() {
        let panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1))
        super.init(window: panel)
        observeScreenChanges()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        observeScreenChanges()
    }

    func setRootView<Content: View>(_ rootView: Content) {
        guard let panel = window as? NotchPanel else { return }
        let hostingView = NSHostingView(rootView: AnyView(rootView))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = hostingView
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: panel.contentView!.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor)
        ])
        self.hostingView = hostingView
    }

    func apply(layout: NotchLayout, state: NotchPresentationState) {
        guard let panel = window as? NotchPanel else { return }

        if layout.mode == .menuBarFallback {
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
            showFallbackMenu(for: state)
            return
        }

        hideFallbackMenu()
        let isHidden = state == .hidden
        if isHidden {
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
            panel.alphaValue = 1
            lastPresentedExpanded = nil
            return
        }

        let frame = state.isExpanded ? layout.expandedFrame : layout.compactFrame
        let wasVisible = panel.isVisible
        let shouldAnimateFrame = wasVisible
            && lastPresentedExpanded != nil
            && lastPresentedExpanded != state.isExpanded
        panel.setFrame(frame, display: true, animate: shouldAnimateFrame)
        panel.ignoresMouseEvents = false
        if wasVisible {
            panel.orderFrontRegardless()
        } else {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }
        lastPresentedExpanded = state.isExpanded
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
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

    private func showFallbackMenu(for state: NotchPresentationState) {
        let statusItem = statusItem ?? makeStatusItem()
        statusItem.isVisible = true
        statusItem.button?.title = "Codex"
        statusItem.button?.toolTip = "CodexNotch"

        let menu = NSMenu()
        menu.autoenablesItems = false
        switch state {
        case .hidden:
            menu.addItem(disabledItem(title: "CodexNotch"))

        case let .quotaCompact(usage):
            menu.addItem(disabledItem(title: "Codex · \(NotchText.quotaSubtitle(usage: usage))"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(actionItem(title: "打开 ChatGPT", representedObject: "__activate__"))

        case let .workingCompact(primary, count, usage):
            let title = count > 1 ? "Codex 正在运行 · \(count) 个任务" : "Codex 正在运行"
            menu.addItem(disabledItem(title: title))
            menu.addItem(disabledItem(title: NotchText.sessionSubtitle(primary, now: .now)))
            if let usage, !usage.windows.isEmpty {
                menu.addItem(disabledItem(title: NotchText.quotaSubtitle(usage: usage)))
            }
            menu.addItem(NSMenuItem.separator())
            menu.addItem(actionItem(title: "打开当前任务", representedObject: primary.threadID))

        case let .completedCompact(session):
            menu.addItem(disabledItem(title: "Codex 已完成"))
            menu.addItem(actionItem(
                title: "打开 \(NotchText.projectName(cwd: session.cwd))",
                representedObject: session.threadID
            ))

        case let .expanded(content):
            menu.addItem(disabledItem(title: content.sessions.isEmpty ? "Codex 额度" : "Codex 任务"))
            if content.sessions.isEmpty {
                if let usage = content.usage, !usage.windows.isEmpty {
                    for window in usage.windows {
                        menu.addItem(disabledItem(title: NotchText.compactWindow(window)))
                    }
                } else {
                    menu.addItem(disabledItem(title: "额度暂不可用"))
                }
                menu.addItem(NSMenuItem.separator())
                menu.addItem(actionItem(title: "打开 ChatGPT", representedObject: "__activate__"))
            } else {
                menu.addItem(NSMenuItem.separator())
                for session in content.sessions {
                    menu.addItem(actionItem(
                        title: "\(NotchText.projectName(cwd: session.cwd)) · \(session.turnID)",
                        representedObject: session.threadID
                    ))
                }
            }
        }
        statusItem.menu = menu
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        return item
    }

    private func hideFallbackMenu() {
        statusItem?.isVisible = false
    }

    private func disabledItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(title: String, representedObject: String) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: #selector(handleStatusItemAction(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = representedObject
        return item
    }

    @objc private func handleStatusItemAction(_ sender: NSMenuItem) {
        guard let representedObject = sender.representedObject as? String else { return }
        if representedObject == "__activate__" {
            onActivateChatGPT?()
        } else {
            onOpenThread?(representedObject)
        }
    }
}

private extension NotchPresentationState {
    var isExpanded: Bool {
        if case .expanded = self { return true }
        return false
    }
}
