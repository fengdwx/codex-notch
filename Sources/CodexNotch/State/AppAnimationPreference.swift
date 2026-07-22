import Foundation

enum AppAnimationPreference {
    static let storageKey = "animationsEnabled"
    static let defaultEnabled = true

    static func isEnabled(in userDefaults: UserDefaults) -> Bool {
        guard userDefaults.object(forKey: storageKey) != nil else {
            return defaultEnabled
        }
        return userDefaults.bool(forKey: storageKey)
    }

    static func allowsMotion(
        animationsEnabled: Bool,
        reduceMotion: Bool
    ) -> Bool {
        animationsEnabled && !reduceMotion
    }
}
