import Foundation
import XCTest
@testable import CodexNotch

final class NotchTextTests: XCTestCase {
    func testWindowLabelsKeepDynamicRollingDuration() {
        XCTAssertEqual(NotchText.windowLabel(.rolling(hours: 12)), "滚动 12h")
        XCTAssertEqual(NotchText.windowLabel(.daily), "每日")
        XCTAssertEqual(NotchText.windowLabel(.weekly), "每周")
        XCTAssertEqual(NotchText.windowLabel(.custom(seconds: 90)), "01:30")
    }

    func testPercentAndCompactWindowUseRemainingQuota() {
        let window = UsageWindow(id: "weekly", kind: .weekly, usedPercent: 25)

        XCTAssertEqual(NotchText.percent(window.remainingPercent), "75%")
        XCTAssertEqual(NotchText.compactWindow(window), "每周余75%")
    }

    func testProjectNameUsesLastPathComponent() {
        XCTAssertEqual(NotchText.projectName(cwd: "/Users/david/projects/codex-notch"), "codex-notch")
        XCTAssertEqual(NotchText.projectName(cwd: nil), "未命名任务")
    }

    func testDurationFormatsHoursWhenNeeded() {
        XCTAssertEqual(NotchText.formatDuration(seconds: 65), "01:05")
        XCTAssertEqual(NotchText.formatDuration(seconds: 3661), "01:01:01")
    }

    func testQuotaSubtitleIncludesRemainingAndUsedPercent() {
        let usage = UsageSnapshot(
            windows: [UsageWindow(id: "primary", kind: .weekly, usedPercent: 20)]
        )

        XCTAssertEqual(NotchText.quotaSubtitle(usage: usage), "每周剩余 80% · 已用 20%")
    }
}
