import Foundation

enum RecentConversationLimit: Int, CaseIterable, Identifiable, Sendable {
    case none = 0
    case one = 1
    case two = 2
    case three = 3
    case four = 4
    case five = 5

    static let storageKey = "recentConversationLimit"
    static let defaultLimit: RecentConversationLimit = .two

    var id: Int { rawValue }

    var title: String {
        title(for: .chinese)
    }

    func title(for language: AppLanguage) -> String {
        language.localized(
            chinese: "\(rawValue) 条",
            english: rawValue == 1 ? "1 conversation" : "\(rawValue) conversations"
        )
    }

    static func fromStoredValue(_ rawValue: Int) -> RecentConversationLimit {
        Self(rawValue: rawValue) ?? Self.defaultLimit
    }
}

struct NotchRuntimePreferences: Equatable, Sendable {
    let recentConversationLimit: RecentConversationLimit
    let language: AppLanguage
    let animationsEnabled: Bool

    static func read(from userDefaults: UserDefaults) -> NotchRuntimePreferences {
        let recentConversationLimit = (userDefaults.object(
            forKey: RecentConversationLimit.storageKey
        ) as? NSNumber).map { $0.intValue } ?? RecentConversationLimit.defaultLimit.rawValue

        return NotchRuntimePreferences(
            recentConversationLimit: RecentConversationLimit.fromStoredValue(recentConversationLimit),
            language: AppLanguage.fromStoredValue(
                userDefaults.string(forKey: AppLanguage.storageKey)
            ),
            animationsEnabled: AppAnimationPreference.isEnabled(in: userDefaults)
        )
    }
}
