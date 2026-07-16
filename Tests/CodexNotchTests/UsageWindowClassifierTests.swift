import XCTest
@testable import CodexNotch

final class UsageWindowClassifierTests: XCTestCase {
    func test604800SecondWindowIsWeekly() {
        XCTAssertEqual(UsageWindowClassifier.kind(seconds: 604_800), .weekly)
    }

    func testFiveHourWindowUsesDynamicRollingLabel() {
        XCTAssertEqual(UsageWindowClassifier.kind(seconds: 18_000), .rolling(hours: 5))
    }

    func testOneDayWindowIsDaily() {
        XCTAssertEqual(UsageWindowClassifier.kind(seconds: 86_400), .daily)
    }

    func testUnknownDurationIsPreserved() {
        XCTAssertEqual(UsageWindowClassifier.kind(seconds: 123_456), .custom(seconds: 123_456))
    }

    func testUsedPercentIsClampedToDisplayRange() {
        XCTAssertEqual(UsageWindowClassifier.clampPercent(-1), 0)
        XCTAssertEqual(UsageWindowClassifier.clampPercent(45), 45)
        XCTAssertEqual(UsageWindowClassifier.clampPercent(101), 100)
    }

    func testMissingWindowsAreNotInvented() {
        let snapshot = UsageSnapshot(windows: [])
        XCTAssertTrue(snapshot.windows.isEmpty)
    }
}
