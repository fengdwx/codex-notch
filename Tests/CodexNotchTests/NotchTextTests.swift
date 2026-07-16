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
        XCTAssertEqual(NotchText.quotaNumber(window.remainingPercent), "75")
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

    func testWeeklyWindowIsSelectedWithoutFallingBackToRollingQuota() {
        let rolling = UsageWindow(id: "primary", kind: .rolling(hours: 5), usedPercent: 10)
        let weekly = UsageWindow(id: "secondary", kind: .weekly, usedPercent: 25)
        let usage = UsageSnapshot(windows: [rolling, weekly])

        XCTAssertEqual(usage.weeklyWindow?.id, "secondary")
        XCTAssertNil(UsageSnapshot(windows: [rolling]).weeklyWindow)
    }

    func testWeeklyQuotaRingTreatsTwentyPercentAsHealthy() {
        let healthy = UsageWindow(id: "weekly", kind: .weekly, usedPercent: 80)
        let critical = UsageWindow(id: "weekly", kind: .weekly, usedPercent: 80.01)

        XCTAssertEqual(WeeklyQuotaLevel(weeklyWindow: healthy), .healthy)
        XCTAssertEqual(WeeklyQuotaLevel(weeklyWindow: critical), .critical)
        XCTAssertEqual(WeeklyQuotaLevel(weeklyWindow: nil), .unavailable)
    }

    func testQuotaColorScaleMovesFromRedToGreen() {
        XCTAssertEqual(QuotaColorScale.hue(for: 0), 0, accuracy: 0.001)
        XCTAssertEqual(QuotaColorScale.hue(for: 50), 0.17, accuracy: 0.001)
        XCTAssertEqual(QuotaColorScale.hue(for: 100), 0.34, accuracy: 0.001)
        XCTAssertEqual(QuotaColorScale.hue(for: -10), 0, accuracy: 0.001)
        XCTAssertEqual(QuotaColorScale.hue(for: 120), 0.34, accuracy: 0.001)
    }

    func testResetTimestampIncludesSeconds() {
        let timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!
        let date = Date(timeIntervalSince1970: 1_768_377_845)

        XCTAssertEqual(
            NotchText.resetTimestamp(date, timeZone: timeZone),
            "2026-01-14 16:04:05"
        )
    }

    func testResetCountdownIncludesDaysAndSeconds() {
        let now = Date(timeIntervalSince1970: 1_000)
        let twoDays: TimeInterval = 2 * 86_400
        let threeHours: TimeInterval = 3 * 3_600
        let fourMinutes: TimeInterval = 4 * 60
        let fiveSeconds: TimeInterval = 5
        let resetAt = now.addingTimeInterval(
            twoDays + threeHours + fourMinutes + fiveSeconds
        )

        XCTAssertEqual(NotchText.resetCountdown(resetAt: resetAt, now: now), "2天 03:04:05")
        XCTAssertEqual(NotchText.resetCountdown(resetAt: now, now: now), "00:00:00")
    }
}
