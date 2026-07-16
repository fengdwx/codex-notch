import Foundation

struct CompletedSession: Equatable, Sendable {
    let session: SessionActivity
    let completedAt: Date
}

enum ConversationActivity: Equatable, Sendable {
    case running(startedAt: Date)
    case completed(completedAt: Date)

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
    let usage: UsageSnapshot?
}

enum NotchPresentationState: Equatable {
    case hidden
    case quotaCompact(UsageSnapshot?)
    case workingCompact(primary: SessionActivity, count: Int, usage: UsageSnapshot?)
    case completedCompact(SessionActivity)
    case expanded(ExpandedContent)
}

struct NotchPresentationInput: Equatable {
    let now: Date
    let isChatGPTFrontmost: Bool
    let activeSessions: [SessionActivity]
    let recentCompletion: CompletedSession?
    let usage: UsageSnapshot?
    let isHovered: Bool
}
