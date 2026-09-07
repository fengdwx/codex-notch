import Foundation

enum AppResources {
    static func bundle(for mainBundle: Bundle = .main) -> Bundle? {
        // SwiftPM's generated accessor looks at the .app root, then the
        // developer's absolute build path. Installed apps must use Resources.
        if mainBundle.bundleURL.pathExtension == "app" {
            guard let resources = mainBundle.resourceURL else { return nil }
            return Bundle(url: resources.appendingPathComponent("CodexNotch_CodexNotch.bundle"))
        }
        return Bundle.module
    }
}
