import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case chinese = "zh-Hans"
    case english = "en"

    static let storageKey = "appLanguage"
    static let defaultLanguage: AppLanguage = .english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chinese:
            return "中文"
        case .english:
            return "English"
        }
    }

    func localized(chinese: String, english: String) -> String {
        self == .english ? english : chinese
    }

    static func fromStoredValue(_ rawValue: String?) -> AppLanguage {
        guard let rawValue else { return defaultLanguage }
        return Self(rawValue: rawValue) ?? defaultLanguage
    }
}
