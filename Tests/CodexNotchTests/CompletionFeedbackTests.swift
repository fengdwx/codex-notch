import Foundation
import XCTest
@testable import CodexNotch

final class CompletionFeedbackTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 2_000_000_000)

    func testInitialPartialDiscoveryAndHistoricalBackfillNeverFlashCompletion() {
        var tracker = CompletionFeedbackTracker()
        let history = ended("old", at: start.addingTimeInterval(-60))
        tracker.observe(snapshot(), initialScanComplete: false, now: start)
        tracker.observe(snapshot(completions: [history]), initialScanComplete: false, now: start)
        XCTAssertNil(tracker.feedback)
        tracker.observe(snapshot(completions: [history]), initialScanComplete: true, now: start)
        let backfilled = ended("older", at: start.addingTimeInterval(-120))
        tracker.observe(snapshot(completions: [history, backfilled]), initialScanComplete: true, now: start.addingTimeInterval(1))
        XCTAssertNil(tracker.feedback)
    }

    func testObservedNormalEndShowsForFiveSecondsThenIdleWithoutDeletingHistory() {
        var tracker = CompletionFeedbackTracker()
        let active = running("one")
        tracker.observe(snapshot(active: [active]), initialScanComplete: true, now: start)
        let completion = ended("one", at: start.addingTimeInterval(1))
        let finished = snapshot(completions: [completion])
        XCTAssertTrue(tracker.observe(finished, initialScanComplete: true, now: start.addingTimeInterval(1)))
        XCTAssertEqual(compact(finished, tracker: tracker), .completedCompact(completion.session, usage: nil))
        XCTAssertFalse(tracker.expire(now: start.addingTimeInterval(5.99)))
        XCTAssertTrue(tracker.expire(now: start.addingTimeInterval(6)))
        XCTAssertEqual(compact(finished, tracker: tracker), .quotaCompact(nil))
        XCTAssertEqual(finished.recentCompletions, [completion])
        XCTAssertFalse(tracker.observe(finished, initialScanComplete: true, now: start.addingTimeInterval(20)))
        XCTAssertNil(tracker.feedback)
    }

    func testDuplicateScansAndTitleRefreshDoNotExtendOrReplayFeedback() {
        var tracker = CompletionFeedbackTracker()
        tracker.observe(snapshot(), initialScanComplete: true, now: start)
        let completion = ended("one", at: start.addingTimeInterval(1))
        tracker.observe(snapshot(completions: [completion]), initialScanComplete: true, now: start.addingTimeInterval(1))
        let renamed = CompletedSession(session: completion.session.withTitle("Updated title"), completedAt: completion.completedAt)
        tracker.observe(snapshot(completions: [renamed]), initialScanComplete: true, now: start.addingTimeInterval(5))
        XCTAssertTrue(tracker.expire(now: start.addingTimeInterval(6)))
        tracker.observe(snapshot(completions: [renamed]), initialScanComplete: true, now: start.addingTimeInterval(10))
        XCTAssertNil(tracker.feedback)
        tracker.observe(snapshot(), initialScanComplete: true, now: start.addingTimeInterval(11))
        tracker.observe(snapshot(completions: [completion]), initialScanComplete: true, now: start.addingTimeInterval(12))
        XCTAssertNil(tracker.feedback, "Rediscovery of an already seen terminal event must not replay it")
    }

    func testNormalEndBrieflyAcknowledgesOneTaskThenReturnsToOtherRunningTask() {
        var tracker = CompletionFeedbackTracker()
        let remaining = running("two")
        tracker.observe(snapshot(active: [running("one"), remaining]), initialScanComplete: true, now: start)
        let completion = ended("one", at: start.addingTimeInterval(1))
        let mixed = snapshot(active: [remaining], completions: [completion])
        tracker.observe(mixed, initialScanComplete: true, now: start.addingTimeInterval(1))
        XCTAssertEqual(compact(mixed, tracker: tracker), .completedCompact(completion.session, usage: nil))
        tracker.expire(now: start.addingTimeInterval(6))
        XCTAssertEqual(compact(mixed, tracker: tracker), .workingCompact(primary: remaining, count: 1, usage: nil))
    }

    func testNewTaskImmediatelyOverridesFeedbackAndDoesNotReplayPreviousEnd() {
        var tracker = CompletionFeedbackTracker()
        tracker.observe(snapshot(), initialScanComplete: true, now: start)
        let completion = ended("one", at: start.addingTimeInterval(1))
        tracker.observe(snapshot(completions: [completion]), initialScanComplete: true, now: start.addingTimeInterval(1))
        let next = running("one", turn: "next", at: start.addingTimeInterval(2))
        let mixed = snapshot(active: [next], completions: [completion])
        tracker.observe(mixed, initialScanComplete: true, now: start.addingTimeInterval(2))
        XCTAssertNil(tracker.feedback)
        XCTAssertEqual(compact(mixed, tracker: tracker), .workingCompact(primary: next, count: 1, usage: nil))
        tracker.observe(snapshot(completions: [completion]), initialScanComplete: true, now: start.addingTimeInterval(3))
        XCTAssertNil(tracker.feedback)
    }

    func testStartAndAnotherCompletionInOneSnapshotPreferNewRunningTask() {
        var tracker = CompletionFeedbackTracker()
        tracker.observe(snapshot(active: [running("one")]), initialScanComplete: true, now: start)
        let next = running("two", at: start.addingTimeInterval(1))
        let mixed = snapshot(active: [next], completions: [ended("one", at: start.addingTimeInterval(1))])
        tracker.observe(mixed, initialScanComplete: true, now: start.addingTimeInterval(1))
        XCTAssertEqual(compact(mixed, tracker: tracker), .workingCompact(primary: next, count: 1, usage: nil))
    }

    func testAbortKeepsStoppedHistoryWithoutSuccessFeedback() {
        var tracker = CompletionFeedbackTracker()
        tracker.observe(snapshot(active: [running("one")]), initialScanComplete: true, now: start)
        let aborted = ended("one", at: start.addingTimeInterval(1), reason: .aborted)
        let stopped = snapshot(completions: [aborted])
        tracker.observe(stopped, initialScanComplete: true, now: start.addingTimeInterval(1))
        XCTAssertEqual(compact(stopped, tracker: tracker), .quotaCompact(nil))
        var input = input(stopped, tracker: tracker)
        input = NotchPresentationInput(now: input.now, isChatGPTFrontmost: false, activeSessions: [],
                                       recentCompletions: input.recentCompletions, usage: nil, isHovered: true)
        guard case let .expanded(content) = NotchPresentationReducer.reduce(input) else { return XCTFail("Expected history") }
        XCTAssertEqual(content.conversations.first?.activity, .stopped(completedAt: aborted.completedAt))
        // A malformed caller cannot make an explicit aborted record green.
        input = NotchPresentationInput(now: start, isChatGPTFrontmost: false, activeSessions: [],
                                       recentCompletions: [aborted], usage: nil, isHovered: false, completionFeedback: aborted)
        XCTAssertEqual(NotchPresentationReducer.reduce(input), .quotaCompact(nil))
    }

    func testHistoryLimitAndHoverNeverClearOrExtendFeedback() {
        var tracker = CompletionFeedbackTracker()
        tracker.observe(snapshot(), initialScanComplete: true, now: start)
        let completion = ended("one", at: start.addingTimeInterval(1))
        let finished = snapshot(completions: [completion])
        tracker.observe(finished, initialScanComplete: true, now: start.addingTimeInterval(1))
        for limit in RecentConversationLimit.allCases {
            let hovered = NotchPresentationInput(now: start.addingTimeInterval(2), isChatGPTFrontmost: false,
                activeSessions: [], recentCompletions: [completion], usage: nil, isHovered: true,
                completionFeedback: tracker.feedback)
            guard case let .expanded(content) = NotchPresentationReducer.reduce(hovered).limitingRecentConversations(to: limit) else {
                return XCTFail("Expected expanded state")
            }
            XCTAssertEqual(content.completionFeedback, completion)
            XCTAssertEqual(content.conversations.count, min(1, limit.rawValue))
        }
        tracker.expire(now: start.addingTimeInterval(6))
        XCTAssertEqual(compact(finished, tracker: tracker), .quotaCompact(nil))
    }

    func testRestartBaselinesPreviouslyCompletedRecordsWithoutFeedback() {
        let completion = ended("one", at: start.addingTimeInterval(1))
        var restarted = CompletionFeedbackTracker()
        restarted.observe(snapshot(completions: [completion]), initialScanComplete: true, now: start.addingTimeInterval(2))
        XCTAssertNil(restarted.feedback)
        let next = ended("one", turn: "next", at: start.addingTimeInterval(3))
        restarted.observe(snapshot(completions: [next]), initialScanComplete: true, now: start.addingTimeInterval(3))
        XCTAssertEqual(restarted.feedback, next)
    }

    func testOlderDelayedTerminalEventCannotReplayAfterNewerFeedbackExpires() {
        var tracker = CompletionFeedbackTracker()
        tracker.observe(snapshot(), initialScanComplete: true, now: start)
        let newer = ended("newer", at: start.addingTimeInterval(10))
        tracker.observe(snapshot(completions: [newer]), initialScanComplete: true, now: start.addingTimeInterval(10))
        tracker.expire(now: start.addingTimeInterval(15))
        let delayed = ended("delayed", at: start.addingTimeInterval(5))
        tracker.observe(snapshot(completions: [newer, delayed]), initialScanComplete: true, now: start.addingTimeInterval(20))
        XCTAssertNil(tracker.feedback, "A newly discovered older terminal record is history, not a fresh completion")
    }

    func testCompletionBetweenInitialSnapshotAndDelayedReadyCallbackIsNotSwallowed() {
        var tracker = CompletionFeedbackTracker()
        tracker.observe(snapshot(), initialScanComplete: false, now: start)
        let initialSnapshot = snapshot(active: [running("one")])
        // The scan has committed this snapshot, but its main-queue callback
        // arrives after a new terminal event has already been written.
        tracker.observe(initialSnapshot, initialScanComplete: true, now: start.addingTimeInterval(10))
        let liveEnd = ended("one", at: start.addingTimeInterval(5))
        tracker.observe(snapshot(completions: [liveEnd]), initialScanComplete: true, now: start.addingTimeInterval(10))
        XCTAssertEqual(tracker.feedback, liveEnd)
    }

    func testDistinctTurnsAtTheSameTerminalTimestampAreEachObservedOnce() {
        var tracker = CompletionFeedbackTracker()
        tracker.observe(snapshot(), initialScanComplete: true, now: start)
        let first = ended("one", at: start.addingTimeInterval(1))
        tracker.observe(snapshot(completions: [first]), initialScanComplete: true, now: start.addingTimeInterval(1))
        tracker.expire(now: start.addingTimeInterval(6))
        let second = ended("two", at: first.completedAt)
        tracker.observe(snapshot(completions: [first, second]), initialScanComplete: true, now: start.addingTimeInterval(7))
        XCTAssertEqual(tracker.feedback, second)
        tracker.expire(now: start.addingTimeInterval(12))
        tracker.observe(snapshot(completions: [first, second]), initialScanComplete: true, now: start.addingTimeInterval(13))
        XCTAssertNil(tracker.feedback)
    }

    private func running(_ thread: String, turn: String = "turn", at date: Date? = nil) -> SessionActivity {
        SessionActivity(threadID: thread, turnID: turn, cwd: nil, originator: nil,
                        startedAt: date ?? start, lastActivityAt: date ?? start)
    }

    private func ended(_ thread: String, turn: String = "turn", at date: Date,
                       reason: SessionTermination = .completed) -> CompletedSession {
        CompletedSession(session: running(thread, turn: turn).updating(lastActivityAt: date, termination: reason), completedAt: date)
    }

    private func snapshot(active: [SessionActivity] = [], completions: [CompletedSession] = []) -> ActiveSessionStoreSnapshot {
        ActiveSessionStoreSnapshot(activeSessions: active, recentCompletions: completions)
    }

    private func input(_ snapshot: ActiveSessionStoreSnapshot, tracker: CompletionFeedbackTracker) -> NotchPresentationInput {
        NotchPresentationInput(now: start, isChatGPTFrontmost: false, activeSessions: snapshot.activeSessions,
                               recentCompletions: snapshot.recentCompletions, usage: nil, isHovered: false,
                               completionFeedback: tracker.feedback)
    }

    private func compact(_ snapshot: ActiveSessionStoreSnapshot, tracker: CompletionFeedbackTracker) -> NotchPresentationState {
        NotchPresentationReducer.reduce(input(snapshot, tracker: tracker))
    }
}
