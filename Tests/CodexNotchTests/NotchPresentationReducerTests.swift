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

    func testRecentCompletionIsHiddenWhenNoTaskIsActive() {
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

        XCTAssertEqual(state, .hidden)
    }

    func testFrontmostChatGPTRemainsHiddenWhenNoTaskIsActive() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let task = makeSession(id: "thread-completed", at: now.addingTimeInterval(-4))
        let completion = CompletedSession(session: task, completedAt: now.addingTimeInterval(-4))
        let usage = UsageSnapshot(windows: [])

        let frontmostState = NotchPresentationReducer.reduce(
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

        XCTAssertEqual(frontmostState, .hidden)
        XCTAssertEqual(hiddenState, .hidden)
    }

    func testHoverWithoutAnActiveTaskRemainsHidden() {
        let state = NotchPresentationReducer.reduce(
            NotchPresentationInput(
                now: Date(timeIntervalSince1970: 2_000_000_000),
                isChatGPTFrontmost: true,
                activeSessions: [],
                recentCompletion: nil,
                usage: nil,
                isHovered: true
            )
        )

        XCTAssertEqual(state, .hidden)
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
