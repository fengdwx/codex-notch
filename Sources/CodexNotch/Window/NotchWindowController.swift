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
    private var deferredFrameWorkItem: DispatchWorkItem?
    private var deferredFrameIdentifier: UUID?

    private var appLanguage: AppLanguage {
        AppLanguage.fromStoredValue(
            UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        )
    }

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
        // The panel owns this view directly. Keeping it out of Auto Layout's
        // intrinsic-size negotiation prevents a window resize from re-entering
        // SwiftUI's text measurement while the notch is expanding.
        hostingView.sizingOptions = []
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        self.hostingView = hostingView
    }

    /// Atoll's motion model is intentional here: make room for the final panel
    /// first, then let SwiftUI animate the visible island inside that stable
    /// canvas. Repeatedly resizing an NSPanel during a SwiftUI layout pass is
    /// both visually rough and prone to re-entrant layout crashes.
    func prepare(
        layout: NotchLayout,
        state: NotchPresentationState,
        animationsEnabled: Bool = AppAnimationPreference.defaultEnabled
    ) {
        guard let panel = window as? NotchPanel else { return }

        if layout.mode == .menuBarFallback {
            cancelDeferredFrameSettlement()
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
            showFallbackMenu(for: state)
            return
        }

        hideFallbackMenu()
        let frame = layout.frame(for: state)
        let wasVisible = panel.isVisible
        cancelDeferredFrameSettlement()

        if shouldSetFrameImmediately(from: panel.frame, to: frame, wasVisible: wasVisible) {
            panel.setFrame(frame, display: true)
        }
        panel.ignoresMouseEvents = false
        if wasVisible {
            panel.orderFrontRegardless()
        } else if !animationsEnabled {
            panel.alphaValue = 1
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
    }

    /// Once the SwiftUI surface has visibly collapsed, remove the unused clear
    /// canvas so it cannot intercept clicks outside the compact notch.
    func settleFrame(
        layout: NotchLayout,
        state: NotchPresentationState,
        animationsEnabled: Bool = AppAnimationPreference.defaultEnabled
    ) {
        guard layout.mode == .notch,
              let panel = window as? NotchPanel else {
            return
        }

        let targetFrame = layout.frame(for: state)
        guard shouldDeferFrameSettlement(from: panel.frame, to: targetFrame) else {
            return
        }

        guard NotchPresentationMotion.shouldAnimateSurface(
            changesSurface: true,
            animationsEnabled: animationsEnabled
        ) else {
            panel.setFrame(targetFrame, display: true)
            return
        }

        let identifier = UUID()
        deferredFrameIdentifier = identifier
        let workItem = DispatchWorkItem { [weak self, weak panel] in
            guard let self,
                  let panel,
                  self.deferredFrameIdentifier == identifier else {
                return
            }
            panel.setFrame(targetFrame, display: true)
            self.deferredFrameIdentifier = nil
            self.deferredFrameWorkItem = nil
        }
        deferredFrameWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + NotchPresentationMotion.collapseDuration,
            execute: workItem
        )
    }

    private func shouldSetFrameImmediately(
        from current: NSRect,
        to target: NSRect,
        wasVisible: Bool
    ) -> Bool {
        guard wasVisible else { return true }
        guard !current.equalTo(target) else { return false }

        let growsWidth = target.width > current.width + 0.5
        let growsHeight = target.height > current.height + 0.5
        let changesTopAttachment = abs(target.maxY - current.maxY) > 0.5
        return growsWidth || growsHeight || changesTopAttachment
    }

    private func shouldDeferFrameSettlement(from current: NSRect, to target: NSRect) -> Bool {
        let growsWidth = target.width > current.width + 0.5
        let growsHeight = target.height > current.height + 0.5
        let shrinksWidth = target.width < current.width - 0.5
        let shrinksHeight = target.height < current.height - 0.5
        return (shrinksWidth || shrinksHeight) && !(growsWidth || growsHeight)
    }

    private func cancelDeferredFrameSettlement() {
        deferredFrameWorkItem?.cancel()
        deferredFrameWorkItem = nil
        deferredFrameIdentifier = nil
    }

    deinit {
        cancelDeferredFrameSettlement()
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
            menu.addItem(disabledItem(title: "Codex · \(NotchText.quotaSubtitle(usage: usage, language: appLanguage))"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(actionItem(
                title: appLanguage.localized(chinese: "打开 ChatGPT", english: "Open ChatGPT"),
                representedObject: "__activate__"
            ))

        case let .workingCompact(primary, count, usage):
            let title = count > 1
                ? appLanguage.localized(
                    chinese: "Codex 正在运行 · \(count) 个任务",
                    english: "Codex running · \(count) tasks"
                )
                : appLanguage.localized(chinese: "Codex 正在运行", english: "Codex running")
            menu.addItem(disabledItem(title: title))
            menu.addItem(disabledItem(
                title: NotchText.sessionSubtitle(primary, now: .now, language: appLanguage)
            ))
            if let usage, !usage.windows.isEmpty {
                menu.addItem(disabledItem(
                    title: NotchText.quotaSubtitle(usage: usage, language: appLanguage)
                ))
            }
            menu.addItem(NSMenuItem.separator())
            menu.addItem(actionItem(
                title: appLanguage.localized(chinese: "打开当前任务", english: "Open current task"),
                representedObject: primary.threadID
            ))

        case let .completedCompact(session, usage):
            menu.addItem(disabledItem(
                title: appLanguage.localized(chinese: "Codex 已完成", english: "Codex completed")
            ))
            if let usage, !usage.windows.isEmpty {
                menu.addItem(disabledItem(
                    title: NotchText.quotaSubtitle(usage: usage, language: appLanguage)
                ))
            }
            menu.addItem(actionItem(
                title: appLanguage.localized(
                    chinese: "打开 \(NotchText.projectName(cwd: session.cwd, language: appLanguage))",
                    english: "Open \(NotchText.projectName(cwd: session.cwd, language: appLanguage))"
                ),
                representedObject: session.threadID
            ))

        case let .expanded(content):
            let headerTitle: String
            if !content.conversations.isEmpty {
                headerTitle = appLanguage.localized(
                    chinese: "Codex 最近对话",
                    english: "Codex recent conversations"
                )
            } else if !content.sessions.isEmpty || content.headerConversation != nil {
                headerTitle = appLanguage.localized(
                    chinese: "Codex 活动",
                    english: "Codex activity"
                )
            } else {
                headerTitle = appLanguage.localized(chinese: "Codex 额度", english: "Codex quota")
            }
            menu.addItem(disabledItem(title: headerTitle))
            if let usage = content.usage,
               !usage.resetCredits.isEmpty {
                menu.addItem(NSMenuItem.separator())
                menu.addItem(disabledItem(title: appLanguage.localized(
                    chinese: "使用限额重置",
                    english: "Usage reset"
                )))
                for credit in usage.resetCredits {
                    menu.addItem(disabledItem(
                        title: "\(NotchText.resetCreditTitle(credit, language: appLanguage)) · \(NotchText.resetCreditExpiry(credit, language: appLanguage))"
                    ))
                }
            }
            if !content.conversations.isEmpty {
                menu.addItem(NSMenuItem.separator())
                for conversation in content.conversations {
                    menu.addItem(actionItem(
                        title: conversation.title
                            ?? NotchText.projectName(cwd: conversation.cwd, language: appLanguage),
                        representedObject: conversation.threadID
                    ))
                }
            } else if !content.sessions.isEmpty {
                menu.addItem(disabledItem(title: appLanguage.localized(
                    chinese: "Codex 正在运行",
                    english: "Codex running"
                )))
                menu.addItem(NSMenuItem.separator())
                for session in content.sessions {
                    menu.addItem(actionItem(
                        title: appLanguage.localized(
                            chinese: "打开 \(NotchText.projectName(cwd: session.cwd, language: appLanguage))",
                            english: "Open \(NotchText.projectName(cwd: session.cwd, language: appLanguage))"
                        ),
                        representedObject: session.threadID
                    ))
                }
            } else if let conversation = content.headerConversation {
                menu.addItem(disabledItem(title: appLanguage.localized(
                    chinese: "Codex 已完成",
                    english: "Codex completed"
                )))
                menu.addItem(NSMenuItem.separator())
                menu.addItem(actionItem(
                    title: appLanguage.localized(
                        chinese: "打开 \(NotchText.projectName(cwd: conversation.cwd, language: appLanguage))",
                        english: "Open \(NotchText.projectName(cwd: conversation.cwd, language: appLanguage))"
                    ),
                    representedObject: conversation.threadID
                ))
            } else {
                if let usage = content.usage, !usage.windows.isEmpty {
                    for window in usage.windows {
                        menu.addItem(disabledItem(
                            title: NotchText.compactWindow(window, language: appLanguage)
                        ))
                    }
                } else {
                    menu.addItem(disabledItem(title: appLanguage.localized(
                        chinese: "额度暂不可用",
                        english: "Quota unavailable"
                    )))
                }
                menu.addItem(NSMenuItem.separator())
                menu.addItem(actionItem(
                    title: appLanguage.localized(chinese: "打开 ChatGPT", english: "Open ChatGPT"),
                    representedObject: "__activate__"
                ))
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
