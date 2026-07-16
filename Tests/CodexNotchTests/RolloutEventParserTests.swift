import Foundation
import XCTest
@testable import CodexNotch

final class RolloutEventParserTests: XCTestCase {
    func testStartedThenCompletedLeavesNoActiveTurn() throws {
        let events = RolloutEventParser.parse(data: try fixtureData("rollout-start-complete.jsonl"))
        let result = ActiveSessionReducer.reduce(events)

        XCTAssertTrue(result.active.isEmpty)
        XCTAssertEqual(result.completed.count, 1)
        XCTAssertEqual(result.completed.first?.threadID, "thread-1")
    }

    func testAbortedTurnIsRemovedFromActiveState() throws {
        let events = RolloutEventParser.parse(data: try fixtureData("rollout-aborted.jsonl"))
        let result = ActiveSessionReducer.reduce(events)

        XCTAssertTrue(result.active.isEmpty)
        XCTAssertEqual(result.completed.first?.turnID, "turn-aborted")
    }

    func testMalformedLineDoesNotDiscardFollowingEvent() throws {
        let events = RolloutEventParser.parse(data: try fixtureData("rollout-malformed-line.jsonl"))

        XCTAssertTrue(events.contains { event in
            if case .taskStarted = event.kind { return true }
            return false
        })
    }

    func testISO8601TimestampsArePreservedForActivityDuration() throws {
        let events = RolloutEventParser.parse(data: try fixtureData("rollout-active.jsonl"))
        let timestamps = events.compactMap(\.timestamp)

        XCTAssertEqual(timestamps.count, 2)
        XCTAssertEqual(timestamps.first, Date(timeIntervalSince1970: 1_784_192_400))
    }

    func testFractionalISO8601TimestampsArePreserved() {
        let data = Data(
            #"{"timestamp":"2026-07-16T09:00:00.123Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-fractional"}}"#
                .utf8
        )

        let event = RolloutEventParser.parseLine(data)

        XCTAssertEqual(
            event?.timestamp,
            Date(timeIntervalSince1970: 1_784_192_400.123)
        )
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
        return try Data(contentsOf: url)
    }
}
