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
                recentCompletions: [],
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
                recentCompletions: [],
                usage: nil,
                isHovered: false
            )
        )

        if case .workingCompact = state {
            return
        }
        XCTFail("Expected working compact state")
    }

    func testRecentCompletionUsesCompletedCompactState() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let task = makeSession(id: "thread-completed", at: now.addingTimeInterval(-2))
        let completion = CompletedSession(session: task, completedAt: now.addingTimeInterval(-2))
        let state = NotchPresentationReducer.reduce(
            NotchPresentationInput(
                now: now,
                isChatGPTFrontmost: false,
                activeSessions: [],
                recentCompletions: [completion],
                usage: nil,
                isHovered: false
            )
        )

        guard case let .completedCompact(session, _) = state else {
            return XCTFail("Expected completed compact state")
        }
        XCTAssertEqual(session.threadID, "thread-completed")
    }

    func testMostRecentCompletionKeepsCompactCompletionState() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let task = makeSession(id: "thread-completed", at: now.addingTimeInterval(-4))
        let completion = CompletedSession(session: task, completedAt: now.addingTimeInterval(-4))
        let usage = UsageSnapshot(windows: [])

        let frontmostState = NotchPresentationReducer.reduce(
            NotchPresentationInput(
                now: now,
                isChatGPTFrontmost: true,
                activeSessions: [],
                recentCompletions: [completion],
                usage: usage,
                isHovered: false
            )
        )
        let hiddenState = NotchPresentationReducer.reduce(
            NotchPresentationInput(
                now: now,
                isChatGPTFrontmost: false,
                activeSessions: [],
                recentCompletions: [completion],
                usage: usage,
                isHovered: false
            )
        )

        XCTAssertEqual(frontmostState, .completedCompact(task, usage: usage))
        XCTAssertEqual(hiddenState, .completedCompact(task, usage: usage))
    }

    func testIdleQuotaIsAlwaysVisible() {
        let usage = UsageSnapshot(
            windows: [UsageWindow(id: "weekly", kind: .weekly, usedPercent: 25)]
        )

        let state = NotchPresentationReducer.reduce(
            NotchPresentationInput(
                now: Date(timeIntervalSince1970: 2_000_000_000),
                isChatGPTFrontmost: false,
                activeSessions: [],
                recentCompletions: [],
                usage: usage,
                isHovered: false
            )
        )

        XCTAssertEqual(state, .quotaCompact(usage))
    }

    func testHoverWithoutAnActiveTaskExpandsWeeklyQuota() {
        let usage = UsageSnapshot(
            windows: [UsageWindow(id: "weekly", kind: .weekly, usedPercent: 25)]
        )
        let completed = makeSession(
            id: "thread-recent",
            title: "最近的对话",
            at: Date(timeIntervalSince1970: 1_999_999_940)
        )
        let state = NotchPresentationReducer.reduce(
            NotchPresentationInput(
                now: Date(timeIntervalSince1970: 2_000_000_000),
                isChatGPTFrontmost: true,
                activeSessions: [],
                recentCompletions: [
                    CompletedSession(session: completed, completedAt: completed.lastActivityAt)
                ],
                usage: usage,
                isHovered: true
            )
        )

        guard case let .expanded(content) = state else {
            return XCTFail("Expected idle quota expansion")
        }
        XCTAssertTrue(content.sessions.isEmpty)
        XCTAssertEqual(content.conversations.map(\.title), ["最近的对话"])
        XCTAssertEqual(content.usage, usage)
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
                recentCompletions: [],
                usage: nil,
                isHovered: true
            )
        )

        guard case let .expanded(content) = state else {
            return XCTFail("Expected expanded state")
        }
        XCTAssertEqual(content.sessions.map(\.threadID), ["thread-new", "thread-old"])
        XCTAssertEqual(content.conversations.map(\.threadID), ["thread-new", "thread-old"])
        XCTAssertTrue(content.conversations.allSatisfy(\.activity.isRunning))
    }

    func testExpandedStateUsesConfiguredRecentConversationLimit() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let sessions = (0..<5).map { index in
            makeSession(
                id: "thread-\(index)",
                at: now.addingTimeInterval(TimeInterval(-index))
            )
        }
        let state = NotchPresentationReducer.reduce(
            NotchPresentationInput(
                now: now,
                isChatGPTFrontmost: false,
                activeSessions: sessions,
                recentCompletions: [],
                usage: nil,
                isHovered: true
            )
        )

        guard case let .expanded(content) = state else {
            return XCTFail("Expected expanded state")
        }
        XCTAssertEqual(content.conversations.count, 5)

        guard case let .expanded(limitedContent) = state.limitingRecentConversations(
            to: .three
        ) else {
            return XCTFail("Expected expanded state")
        }
        XCTAssertEqual(limitedContent.conversations.map(\.threadID), [
            "thread-0", "thread-1", "thread-2"
        ])
    }

    func testZeroRecentConversationLimitHidesAllConversations() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let task = makeSession(id: "thread-active", at: now)
        let state = NotchPresentationReducer.reduce(
            NotchPresentationInput(
                now: now,
                isChatGPTFrontmost: false,
                activeSessions: [task],
                recentCompletions: [],
                usage: nil,
                isHovered: true
            )
        )

        guard case let .expanded(content) = state.limitingRecentConversations(to: .none) else {
            return XCTFail("Expected expanded state")
        }
        XCTAssertTrue(content.conversations.isEmpty)
        XCTAssertEqual(content.sessions.map(\.threadID), ["thread-active"])
        XCTAssertEqual(content.headerConversation?.threadID, "thread-active")
    }

    func testZeroRecentConversationLimitKeepsCompletedHeaderState() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let session = makeSession(id: "thread-completed", at: now.addingTimeInterval(-30))
        let state = NotchPresentationReducer.reduce(
            NotchPresentationInput(
                now: now,
                isChatGPTFrontmost: false,
                activeSessions: [],
                recentCompletions: [
                    CompletedSession(session: session, completedAt: now.addingTimeInterval(-1))
                ],
                usage: nil,
                isHovered: true
            )
        )

        guard case let .expanded(content) = state.limitingRecentConversations(to: .none) else {
            return XCTFail("Expected expanded state")
        }
        XCTAssertTrue(content.conversations.isEmpty)
        XCTAssertEqual(content.headerConversation?.threadID, "thread-completed")
        if let headerConversation = content.headerConversation,
           case .completed = headerConversation.activity {
            return
        }
        XCTFail("Expected completed header state")
    }

    private func makeSession(
        id: String,
        title: String? = nil,
        at date: Date
    ) -> SessionActivity {
        SessionActivity(
            threadID: id,
            turnID: "turn-\(id)",
            title: title,
            cwd: "/tmp/project",
            originator: "Codex Desktop",
            startedAt: date,
            lastActivityAt: date
        )
    }
}
