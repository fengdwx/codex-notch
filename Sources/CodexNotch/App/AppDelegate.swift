import AppKit

enum AppIdentity {
    static let bundleIdentifier = "com.david.codexnotch"
    static let chatGPTCodexBundleIdentifier = "com.openai.codex"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var runtimeCoordinator: NotchRuntimeCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        runtimeCoordinator = NotchRuntimeCoordinator()
        runtimeCoordinator?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtimeCoordinator?.stop()
    }
}
