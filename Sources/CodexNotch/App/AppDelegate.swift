import AppKit

enum AppIdentity {
    static let bundleIdentifier = "com.david.codexnotch"
    static let chatGPTCodexBundleIdentifier = "com.openai.codex"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var runtimeCoordinator: NotchRuntimeCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--verify-bundled-resources") {
            // Exit before reading credentials or starting session monitoring.
            let valid = SwordWandererAsset.pixelSize == CGSize(width: 1_536, height: 2_288)
                && SwordWandererAsset.swordImage != nil
                && SwordWandererAsset.slimeImage != nil
                && SwordWandererAsset.hitSparkImage != nil
            print(valid ? "Bundled resources verified" : "Bundled resources missing or invalid")
            exit(valid ? 0 : 1)
        }
        NSApp.setActivationPolicy(.accessory)
        runtimeCoordinator = NotchRuntimeCoordinator()
        runtimeCoordinator?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtimeCoordinator?.stop()
    }
}
