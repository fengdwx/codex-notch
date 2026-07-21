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

    func testEnglishQuotaTextUsesEnglishLabels() {
        let usage = UsageSnapshot(
            windows: [UsageWindow(id: "primary", kind: .weekly, usedPercent: 20)],
            resetCreditsAvailable: 2
        )

        XCTAssertEqual(
            NotchText.quotaSubtitle(usage: usage, language: .english),
            "Weekly 80% remaining · 20% used"
        )
        XCTAssertEqual(
            NotchText.resetCredits(usage: usage, language: .english),
            "2 resets available"
        )
    }

    func testResetCreditsTextKeepsTheAvailableCountVisible() {
        let usage = UsageSnapshot(
            windows: [UsageWindow(id: "primary", kind: .weekly, usedPercent: 20)],
            resetCreditsAvailable: 2
        )

        XCTAssertEqual(NotchText.resetCredits(usage: usage), "可重置 2 次")
        XCTAssertEqual(NotchText.resetCredits(usage: nil), "重置 —")
    }

    func testResetCreditsKeepEveryAvailableCreditAndSortByExpiry() {
        let first = Date(timeIntervalSince1970: 2_000)
        let second = Date(timeIntervalSince1970: 3_000)
        let usage = UsageSnapshot(
            windows: [UsageWindow(id: "weekly", kind: .weekly, usedPercent: 20)],
            resetCredits: [
                ResetCredit(id: "second", title: "Full reset", expiresAt: second),
                ResetCredit(id: "unknown", title: nil),
                ResetCredit(id: "first", title: "Full reset", expiresAt: first)
            ]
        )

        XCTAssertEqual(usage.resetCredits.map(\.id), ["first", "second", "unknown"])
        XCTAssertEqual(usage.resetCredits.count, 3)
        XCTAssertEqual(NotchText.resetCreditTitle(usage.resetCredits[2]), "使用限额重置")
    }

    func testResetCreditExpiryIncludesTheActualExpiryTime() {
        let timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!
        let credit = ResetCredit(
            id: "credit",
            title: "Full reset",
            expiresAt: Date(timeIntervalSince1970: 1_768_377_845)
        )

        XCTAssertEqual(
            NotchText.resetCreditExpiry(credit, timeZone: timeZone),
            "到期 2026-01-14 16:04:05"
        )
    }

    func testWeeklyWindowIsSelectedWithoutFallingBackToRollingQuota() {
        let rolling = UsageWindow(id: "primary", kind: .rolling(hours: 5), usedPercent: 10)
        let weekly = UsageWindow(id: "secondary", kind: .weekly, usedPercent: 25)
        let usage = UsageSnapshot(windows: [rolling, weekly])

        XCTAssertEqual(usage.weeklyWindow?.id, "secondary")
        XCTAssertNil(UsageSnapshot(windows: [rolling]).weeklyWindow)
    }

    func testWeeklyQuotaLevelUsesWarningAndCriticalBoundaries() {
        let healthy = UsageWindow(id: "weekly", kind: .weekly, usedPercent: 79.99)
        let warning = UsageWindow(id: "weekly", kind: .weekly, usedPercent: 80)
        let critical = UsageWindow(id: "weekly", kind: .weekly, usedPercent: 90)

        XCTAssertEqual(WeeklyQuotaLevel(weeklyWindow: healthy), .healthy)
        XCTAssertEqual(WeeklyQuotaLevel(weeklyWindow: warning), .warning)
        XCTAssertEqual(WeeklyQuotaLevel(weeklyWindow: critical), .critical)
        XCTAssertEqual(WeeklyQuotaLevel(weeklyWindow: nil), .unavailable)
    }

    func testQuotaColorScaleUsesStableAlertBands() {
        XCTAssertEqual(QuotaColorScale.band(for: 100), .healthy)
        XCTAssertEqual(QuotaColorScale.band(for: 20.01), .healthy)
        XCTAssertEqual(QuotaColorScale.band(for: 20), .warning)
        XCTAssertEqual(QuotaColorScale.band(for: 10.01), .warning)
        XCTAssertEqual(QuotaColorScale.band(for: 10), .critical)
        XCTAssertEqual(QuotaColorScale.band(for: 0), .critical)
        XCTAssertEqual(QuotaColorScale.band(for: -.infinity), .critical)

        XCTAssertEqual(
            QuotaColorScale.components(for: 50),
            .init(red: 0.29, green: 0.84, blue: 0.43)
        )
        XCTAssertEqual(
            QuotaColorScale.components(for: 20),
            .init(red: 1.0, green: 0.76, blue: 0.18)
        )
        XCTAssertEqual(
            QuotaColorScale.components(for: 10),
            .init(red: 0.86, green: 0.12, blue: 0.18)
        )
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
