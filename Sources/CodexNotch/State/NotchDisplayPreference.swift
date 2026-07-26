import Foundation

enum NotchDisplayPreference {
    static let storageKey = "notchDisplayEnabled"
    static let defaultEnabled = true

    static func isEnabled(in userDefaults: UserDefaults) -> Bool {
        guard userDefaults.object(forKey: storageKey) != nil else {
            return defaultEnabled
        }
        return userDefaults.bool(forKey: storageKey)
    }

    static func toggledValue(for isEnabled: Bool) -> Bool {
        !isEnabled
    }
}
