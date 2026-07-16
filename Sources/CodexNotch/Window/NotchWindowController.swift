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
    private var lastFrameKind: PresentationFrameKind?
    private var activeFrameAnimation: ActiveFrameAnimation?
    private var frameAnimationTimer: Timer?

    private enum FrameAnimation {
        static let expandDuration: TimeInterval = 0.38
        static let collapseDuration: TimeInterval = 0.28
        static let frameInterval: TimeInterval = 1.0 / 120.0
    }

    private struct ActiveFrameAnimation {
        let startFrame: NSRect
        let targetFrame: NSRect
        let startedAt: TimeInterval
        let duration: TimeInterval
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
        let frameKind = PresentationFrameKind(state: state)
        let frame: NSRect
        switch frameKind {
        case .hoverSensor:
            frame = layout.hoverSensorFrame
        case .compact:
            frame = layout.compactFrame
        case .quotaExpanded:
            frame = layout.quotaExpandedFrame
        case .taskExpanded:
            frame = layout.expandedFrame
        }
        let wasVisible = panel.isVisible
        let shouldAnimateFrame = wasVisible
            && lastFrameKind != nil
            && !panel.frame.equalTo(frame)
        if shouldAnimateFrame {
            animateFrameChange(of: panel, to: frame)
        } else {
            stopFrameAnimation()
            panel.setFrame(frame, display: true)
        }
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
        lastFrameKind = frameKind
    }

    private func animateFrameChange(of panel: NSPanel, to frame: NSRect) {
        stopFrameAnimation()
        let isExpanding = frame.height > panel.frame.height
        activeFrameAnimation = ActiveFrameAnimation(
            startFrame: panel.frame,
            targetFrame: frame,
            startedAt: ProcessInfo.processInfo.systemUptime,
            duration: isExpanding
                ? FrameAnimation.expandDuration
                : FrameAnimation.collapseDuration
        )

        // Drive the full frame ourselves rather than using NSWindow's animator.
        // That guarantees the current compact island is the first animation
        // frame, then only its bottom edge moves downward.
        advanceFrameAnimation()
        let timer = Timer(
            timeInterval: FrameAnimation.frameInterval,
            repeats: true
        ) { [weak self] _ in
            self?.advanceFrameAnimation()
        }
        frameAnimationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func advanceFrameAnimation() {
        guard let animation = activeFrameAnimation,
              let panel = window as? NSPanel else {
            stopFrameAnimation()
            return
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - animation.startedAt
        let progress = min(max(elapsed / animation.duration, 0), 1)
        panel.setFrame(
            NotchTopAnchoredFrameInterpolator.frame(
                from: animation.startFrame,
                to: animation.targetFrame,
                progress: smoothStep(progress)
            ),
            display: true
        )

        if progress >= 1 {
            panel.setFrame(animation.targetFrame, display: true)
            stopFrameAnimation()
        }
    }

    private func smoothStep(_ progress: CGFloat) -> CGFloat {
        progress * progress * (3 - 2 * progress)
    }

    private func stopFrameAnimation() {
        frameAnimationTimer?.invalidate()
        frameAnimationTimer = nil
        activeFrameAnimation = nil
    }

    deinit {
        stopFrameAnimation()
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

        case let .completedCompact(session, usage):
            menu.addItem(disabledItem(title: "Codex 已完成"))
            if let usage, !usage.windows.isEmpty {
                menu.addItem(disabledItem(title: NotchText.quotaSubtitle(usage: usage)))
            }
            menu.addItem(actionItem(
                title: "打开 \(NotchText.projectName(cwd: session.cwd))",
                representedObject: session.threadID
            ))

        case let .expanded(content):
            menu.addItem(disabledItem(title: content.conversations.isEmpty ? "Codex 额度" : "Codex 最近对话"))
            if content.conversations.isEmpty {
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
                for conversation in content.conversations {
                    menu.addItem(actionItem(
                        title: conversation.title ?? NotchText.projectName(cwd: conversation.cwd),
                        representedObject: conversation.threadID
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

private enum PresentationFrameKind: Equatable {
    case hoverSensor
    case compact
    case quotaExpanded
    case taskExpanded

    init(state: NotchPresentationState) {
        switch state {
        case .hidden:
            self = .hoverSensor
        case .quotaCompact, .workingCompact, .completedCompact:
            self = .compact
        case let .expanded(content):
            self = content.conversations.isEmpty ? .quotaExpanded : .taskExpanded
        }
    }
}
