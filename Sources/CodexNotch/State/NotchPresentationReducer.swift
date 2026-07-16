import Foundation

enum NotchPresentationReducer {
    static let completionDisplayDuration: TimeInterval = 3

    static func reduce(_ input: NotchPresentationInput) -> NotchPresentationState {
        let sessions = input.activeSessions.sorted { $0.lastActivityAt > $1.lastActivityAt }

        if !sessions.isEmpty {
            if input.isHovered {
                return .expanded(ExpandedContent(sessions: sessions, usage: input.usage))
            }
            return .workingCompact(
                primary: sessions[0],
                count: sessions.count,
                usage: input.usage
            )
        }

        if let completion = input.recentCompletion,
           input.now.timeIntervalSince(completion.completedAt) >= 0,
           input.now.timeIntervalSince(completion.completedAt) < completionDisplayDuration {
            return .completedCompact(completion.session)
        }

        guard input.isChatGPTFrontmost else {
            return .hidden
        }

        if input.isHovered {
            return .expanded(ExpandedContent(sessions: [], usage: input.usage))
        }
        return .quotaCompact(input.usage)
    }
}
