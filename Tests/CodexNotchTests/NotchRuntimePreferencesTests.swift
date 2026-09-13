import AppKit
import SwiftUI
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

    func testAnimationSettingChangesRuntimePreferences() {
        let suiteName = "NotchRuntimePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        XCTAssertTrue(NotchRuntimePreferences.read(from: defaults).animationsEnabled)

        defaults.set(false, forKey: AppAnimationPreference.storageKey)

        XCTAssertFalse(NotchRuntimePreferences.read(from: defaults).animationsEnabled)
    }

    func testNotchDisplaySettingChangesRuntimePreferences() {
        let suiteName = "NotchRuntimePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        XCTAssertTrue(NotchRuntimePreferences.read(from: defaults).notchDisplayEnabled)

        defaults.set(false, forKey: NotchDisplayPreference.storageKey)

        XCTAssertFalse(NotchRuntimePreferences.read(from: defaults).notchDisplayEnabled)
    }

    func testNotchVisibilityToggleFlipsTheStoredDisplayState() {
        XCTAssertFalse(NotchDisplayPreference.toggledValue(for: true))
        XCTAssertTrue(NotchDisplayPreference.toggledValue(for: false))
    }

    func testMotionFollowsTheAppSetting() {
        XCTAssertTrue(
            AppAnimationPreference.allowsMotion(
                animationsEnabled: true
            )
        )
        XCTAssertFalse(
            AppAnimationPreference.allowsMotion(
                animationsEnabled: false
            )
        )
    }

    @MainActor
    func testAppSwitchStopsLiveAndPreviewMotionWithoutFreezingState() throws {
        _ = NSApplication.shared
        let suite = "IndependentMotionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(FloatingCenterStyle.signature.rawValue, forKey: FloatingCenterStyle.storageKey)
        func findMotion(in view: NSView) -> FloatingCenterLayerView? {
            if let motion = view as? FloatingCenterLayerView { return motion }
            return view.subviews.lazy.compactMap { findMotion(in: $0) }.first
        }
        for appAnimations in [true, false] {
            let now = Date(timeIntervalSince1970: 1_700_000_000)
            let model = NotchViewModel(
                state: .quotaCompact(nil), now: now, layoutMode: .floatingBar,
                compactWidth: 212, compactHeight: 30,
                surfaceSize: CGSize(width: 212, height: 30), animationsEnabled: appAnimations
            )
            let live = NSHostingView(rootView: NotchView(model: model)
                .defaultAppStorage(defaults)
                .frame(width: 212, height: 30))
            let preview = NSHostingView(rootView: FloatingBarSettingsPreview(
                style: .signature, customText: "Example", state: .idle,
                language: .english, animationsEnabled: appAnimations
            )
                .frame(width: 500, height: 140))
            for hosting in [live as NSView, preview as NSView] {
                hosting.layoutSubtreeIfNeeded()
                let motion = try XCTUnwrap(findMotion(in: hosting))
                XCTAssertEqual(motion.animationIsRequested, appAnimations,
                               "The live surface and preview must both follow the app switch")
                XCTAssertFalse(motion.layerAnimationIsRunning,
                               "Detached surfaces must still avoid animation work")
            }
            model.updateClock(now: now.addingTimeInterval(1))
            XCTAssertEqual(model.now, now.addingTimeInterval(1), "Turning off motion must not freeze clocks")
            XCTAssertEqual(model.state, .quotaCompact(nil))
        }
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
        XCTAssertTrue(NotchRuntimePreferences.read(from: defaults).animationsEnabled)
        XCTAssertTrue(NotchRuntimePreferences.read(from: defaults).notchDisplayEnabled)
    }
}
