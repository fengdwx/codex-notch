import Foundation

struct CompletedSession: Equatable, Sendable {
    let session: SessionActivity
    let completedAt: Date
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
