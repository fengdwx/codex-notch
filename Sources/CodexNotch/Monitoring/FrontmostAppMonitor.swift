import AppKit
import Foundation

final class FrontmostAppMonitor {
    private let workspace: NSWorkspace
    private var applicationObserver: NSObjectProtocol?
    private var activeSpaceObserver: NSObjectProtocol?

    var onChange: ((Bool) -> Void)?

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    static func isChatGPTCodex(bundleIdentifier: String?) -> Bool {
        bundleIdentifier == AppIdentity.chatGPTCodexBundleIdentifier
    }

    func start() {
        stop()
        emit(bundleIdentifier: workspace.frontmostApplication?.bundleIdentifier)
        applicationObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
            self?.emit(bundleIdentifier: application?.bundleIdentifier)
        }
        activeSpaceObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: workspace,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.emit(
                bundleIdentifier: self.workspace.frontmostApplication?.bundleIdentifier
            )
        }
    }

    func stop() {
        if let applicationObserver {
            workspace.notificationCenter.removeObserver(applicationObserver)
            self.applicationObserver = nil
        }
        if let activeSpaceObserver {
            workspace.notificationCenter.removeObserver(activeSpaceObserver)
            self.activeSpaceObserver = nil
        }
    }

    deinit {
        stop()
    }

    private func emit(bundleIdentifier: String?) {
        onChange?(Self.isChatGPTCodex(bundleIdentifier: bundleIdentifier))
    }
}
