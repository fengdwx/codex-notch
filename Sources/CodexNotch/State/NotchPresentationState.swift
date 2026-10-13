import Foundation

struct CompletedSession: Equatable, Sendable {
    let session: SessionActivity
    let completedAt: Date
}

enum ConversationActivity: Equatable, Sendable {
    case running(startedAt: Date)
    case completed(completedAt: Date)
    case stopped(completedAt: Date)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

struct ConversationSummary: Equatable, Identifiable, Sendable {
    let threadID: String
    let title: String?
    let cwd: String?
    let lastActivityAt: Date
    let activity: ConversationActivity

    var id: String { threadID }

    init(session: SessionActivity, activity: ConversationActivity) {
        self.threadID = session.threadID
        self.title = session.title
        self.cwd = session.cwd
        self.lastActivityAt = session.lastActivityAt
        self.activity = activity
    }
}

struct ExpandedContent: Equatable, Sendable {
    let sessions: [SessionActivity]
    let conversations: [ConversationSummary]
    let headerConversation: ConversationSummary?
    let usage: UsageSnapshot?
    var completionFeedback: CompletedSession? = nil

    func limitingRecentConversations(
        to limit: RecentConversationLimit
    ) -> ExpandedContent {
        ExpandedContent(
            sessions: sessions,
            conversations: Array(conversations.prefix(limit.rawValue)),
            headerConversation: headerConversation,
            usage: usage,
            completionFeedback: completionFeedback
        )
    }
}

enum NotchPresentationState: Equatable {
    case hidden
    case quotaCompact(UsageSnapshot?)
    case workingCompact(primary: SessionActivity, count: Int, usage: UsageSnapshot?)
    case completedCompact(SessionActivity, usage: UsageSnapshot?)
    case expanded(ExpandedContent)
}

extension NotchPresentationState {
    func limitingRecentConversations(
        to limit: RecentConversationLimit
    ) -> NotchPresentationState {
        guard case let .expanded(content) = self else { return self }
        return .expanded(content.limitingRecentConversations(to: limit))
    }
}

struct NotchPresentationInput: Equatable {
    let now: Date
    let isChatGPTFrontmost: Bool
    let activeSessions: [SessionActivity]
    let recentCompletions: [CompletedSession]
    let usage: UsageSnapshot?
    let isHovered: Bool
    var completionFeedback: CompletedSession? = nil
}
