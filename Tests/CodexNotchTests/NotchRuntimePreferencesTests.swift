import Foundation
import XCTest
@testable import CodexNotch

final class NotchRuntimePreferencesTests: XCTestCase {
    func testStatusItemAutosaveChangesDoNotAffectRuntimePreferences() {
        let suiteName = "NotchRuntimePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(
            RecentConversationLimit.three.rawValue,
            forKey: RecentConversationLimit.storageKey
        )
        let initial = NotchRuntimePreferences.read(from: defaults)

        defaults.set(false, forKey: "NSStatusItem VisibleCC Item-0")

        XCTAssertEqual(
            NotchRuntimePreferences.read(from: defaults),
            initial
        )
    }

    func testRecentConversationLimitChangesRuntimePreferences() {
        let suiteName = "NotchRuntimePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(
            RecentConversationLimit.two.rawValue,
            forKey: RecentConversationLimit.storageKey
        )
        let initial = NotchRuntimePreferences.read(from: defaults)

        defaults.set(
            RecentConversationLimit.four.rawValue,
            forKey: RecentConversationLimit.storageKey
        )

        XCTAssertNotEqual(
            NotchRuntimePreferences.read(from: defaults),
            initial
        )
    }

    func testLanguageChangesRuntimePreferences() {
        let suiteName = "NotchRuntimePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let initial = NotchRuntimePreferences.read(from: defaults)
        XCTAssertEqual(initial.language, .english)

        defaults.set(
            AppLanguage.english.rawValue,
            forKey: AppLanguage.storageKey
        )

        XCTAssertEqual(
            NotchRuntimePreferences.read(from: defaults).language,
            .english
        )
    }

    func testMissingRecentConversationLimitUsesTheTwoItemDefault() {
        let suiteName = "NotchRuntimePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        XCTAssertEqual(
            NotchRuntimePreferences.read(from: defaults).recentConversationLimit,
            .two
        )
    }
}
