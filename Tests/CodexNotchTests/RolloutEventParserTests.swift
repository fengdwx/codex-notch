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

    private func fixtureData(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
        return try Data(contentsOf: url)
    }
}
