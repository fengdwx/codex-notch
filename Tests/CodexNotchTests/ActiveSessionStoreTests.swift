import Foundation
import XCTest
@testable import CodexNotch

final class ActiveSessionStoreTests: XCTestCase {
    func testMultipleRolloutsAreSortedByLastActivity() async {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let older = makeReduction(threadID: "thread-old", turnID: "turn-old", at: now.addingTimeInterval(-20))
        let newer = makeReduction(threadID: "thread-new", turnID: "turn-new", at: now.addingTimeInterval(-5))
        let store = ActiveSessionStore(staleAfter: 6 * 60 * 60)

        await store.replace(rolloutID: "old", reduction: older, lastModifiedAt: now)
        await store.replace(rolloutID: "new", reduction: newer, lastModifiedAt: now)

        let result = await store.activeSessions(now: now)
        XCTAssertEqual(result.map(\.threadID), ["thread-new", "thread-old"])
    }

    func testCompletingOneTurnLeavesTheOtherActive() async {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let events: [RolloutEvent] = [
            RolloutEvent(timestamp: now, kind: .sessionMeta(threadID: "thread", cwd: nil, originator: nil)),
            RolloutEvent(timestamp: now, kind: .taskStarted(turnID: "turn-1")),
            RolloutEvent(timestamp: now.addingTimeInterval(1), kind: .taskStarted(turnID: "turn-2")),
            RolloutEvent(timestamp: now.addingTimeInterval(2), kind: .taskCompleted(turnID: "turn-1"))
        ]
        let store = ActiveSessionStore()

        await store.replace(
            rolloutID: "rollout",
            reduction: ActiveSessionReducer.reduce(events),
            lastModifiedAt: now
        )

        let result = await store.activeSessions(now: now)
        XCTAssertEqual(result.map(\.turnID), ["turn-2"])
    }

    func testUnmatchedStartOlderThanStaleWindowIsRemoved() async {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let stale = makeReduction(threadID: "stale-thread", turnID: "stale-turn", at: now)
        let store = ActiveSessionStore(staleAfter: 6 * 60 * 60)

        await store.replace(
            rolloutID: "stale",
            reduction: stale,
            lastModifiedAt: now.addingTimeInterval(-(6 * 60 * 60 + 1))
        )

        let result = await store.activeSessions(now: now)
        XCTAssertTrue(result.isEmpty)
    }

    func testSnapshotIncludesMostRecentCompletion() async {
        let startedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let completedAt = startedAt.addingTimeInterval(4)
        let completedSession = SessionActivity(
            threadID: "thread-completed",
            turnID: "turn-completed",
            cwd: "/tmp/project",
            originator: nil,
            startedAt: startedAt,
            lastActivityAt: completedAt
        )
        let store = ActiveSessionStore()

        await store.replace(
            rolloutID: "rollout",
            reduction: ActiveSessionReduction(active: [], completed: [completedSession]),
            lastModifiedAt: completedAt
        )

        let snapshot = await store.snapshot(now: completedAt)

        XCTAssertEqual(snapshot.activeSessions, [])
        XCTAssertEqual(snapshot.latestCompletion?.session.threadID, "thread-completed")
        XCTAssertEqual(snapshot.latestCompletion?.completedAt, completedAt)
    }

    private func makeReduction(threadID: String, turnID: String, at: Date) -> ActiveSessionReduction {
        ActiveSessionReducer.reduce([
            RolloutEvent(timestamp: at, kind: .sessionMeta(threadID: threadID, cwd: nil, originator: nil)),
            RolloutEvent(timestamp: at, kind: .taskStarted(turnID: turnID))
        ])
    }
}
