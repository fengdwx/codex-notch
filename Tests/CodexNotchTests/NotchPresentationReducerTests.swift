import Foundation
import XCTest
@testable import CodexNotch

final class NotchPresentationReducerTests: XCTestCase {
    func testActiveTaskWinsEvenWhenOtherAppIsFrontmost() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let task = makeSession(id: "thread-active", at: now)
        let state = NotchPresentationReducer.reduce(
            NotchPresentationInput(
                now: now,
                isChatGPTFrontmost: false,
                activeSessions: [task],
                recentCompletion: nil,
                usage: nil,
                isHovered: false
            )
        )

        guard case let .workingCompact(primary, count, _) = state else {
            return XCTFail("Expected working compact state")
        }
        XCTAssertEqual(primary.threadID, "thread-active")
        XCTAssertEqual(count, 1)
    }

    func testActiveTaskAlsoWinsWhenChatGPTIsFrontmost() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let task = makeSession(id: "thread-active", at: now)
        let state = NotchPresentationReducer.reduce(
            NotchPresentationInput(
                now: now,
                isChatGPTFrontmost: true,
                activeSessions: [task],
                recentCompletion: nil,
                usage: nil,
                isHovered: false
            )
        )

        if case .workingCompact = state {
            return
        }
        XCTFail("Expected working compact state")
    }

    func testRecentCompletionShowsCompletedState() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let task = makeSession(id: "thread-completed", at: now.addingTimeInterval(-2))
        let state = NotchPresentationReducer.reduce(
            NotchPresentationInput(
                now: now,
                isChatGPTFrontmost: false,
                activeSessions: [],
                recentCompletion: CompletedSession(session: task, completedAt: now.addingTimeInterval(-2)),
                usage: nil,
                isHovered: false
            )
        )

        guard case let .completedCompact(completed) = state else {
            return XCTFail("Expected completed compact state")
        }
        XCTAssertEqual(completed.threadID, "thread-completed")
    }

    func testExpiredCompletionReturnsToQuotaOrHidden() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let task = makeSession(id: "thread-completed", at: now.addingTimeInterval(-4))
        let completion = CompletedSession(session: task, completedAt: now.addingTimeInterval(-4))
        let usage = UsageSnapshot(windows: [])

        let quotaState = NotchPresentationReducer.reduce(
            NotchPresentationInput(
                now: now,
                isChatGPTFrontmost: true,
                activeSessions: [],
                recentCompletion: completion,
                usage: usage,
                isHovered: false
            )
        )
        let hiddenState = NotchPresentationReducer.reduce(
            NotchPresentationInput(
                now: now,
                isChatGPTFrontmost: false,
                activeSessions: [],
                recentCompletion: completion,
                usage: usage,
                isHovered: false
            )
        )

        if case .quotaCompact = quotaState {} else { XCTFail("Expected quota state") }
        if case .hidden = hiddenState {} else { XCTFail("Expected hidden state") }
    }

    func testHoverExpandsAllActiveSessionsInRecentOrder() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let older = makeSession(id: "thread-old", at: now.addingTimeInterval(-10))
        let newer = makeSession(id: "thread-new", at: now.addingTimeInterval(-1))
        let state = NotchPresentationReducer.reduce(
            NotchPresentationInput(
                now: now,
                isChatGPTFrontmost: false,
                activeSessions: [older, newer],
                recentCompletion: nil,
                usage: nil,
                isHovered: true
            )
        )

        guard case let .expanded(content) = state else {
            return XCTFail("Expected expanded state")
        }
        XCTAssertEqual(content.sessions.map(\.threadID), ["thread-new", "thread-old"])
    }

    private func makeSession(id: String, at date: Date) -> SessionActivity {
        SessionActivity(
            threadID: id,
            turnID: "turn-\(id)",
            cwd: "/tmp/project",
            originator: "Codex Desktop",
            startedAt: date,
            lastActivityAt: date
        )
    }
}
