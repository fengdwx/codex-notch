import XCTest
@testable import CodexNotch

final class SettingsDisplayContextTests: XCTestCase {
    func testOnlyAnEnabledFloatingRouteClaimsThatSettingsApplyNow() {
        XCTAssertEqual(FloatingSettingsContext(layoutMode: .floatingBar, displayEnabled: true), .active)
        XCTAssertEqual(FloatingSettingsContext(layoutMode: .notch, displayEnabled: true), .notched)
        XCTAssertEqual(FloatingSettingsContext(layoutMode: .menuBarFallback, displayEnabled: true), .unavailable)
        XCTAssertEqual(FloatingSettingsContext(layoutMode: nil, displayEnabled: true), .unavailable)
        for mode in [NotchLayoutMode.notch, .floatingBar, .menuBarFallback] {
            XCTAssertEqual(FloatingSettingsContext(layoutMode: mode, displayEnabled: false), .hidden)
        }
    }

    func testPreviewStatesExerciseTheRealElapsedTimeFallbackWithoutRealTasks() {
        let now = Date(timeIntervalSince1970: 1_000)
        let start = now.addingTimeInterval(-138)
        XCTAssertEqual(FloatingCenterText.elapsedText(
            activity: FloatingPreviewState.running.activity, startedAt: start, now: now
        ), "02:18")
        for state in [FloatingPreviewState.idle, .completed] {
            XCTAssertNil(FloatingCenterText.elapsedText(activity: state.activity, startedAt: start, now: now))
        }
        XCTAssertTrue(FloatingCenterStyle.elapsed.usesCustomText, "The fallback text stays editable")
        XCTAssertFalse(FloatingCenterStyle.flow.usesCustomText, "Flow must not offer an ineffective text control")
    }
}
