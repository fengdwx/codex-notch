import Foundation

enum NotchPresentationReducer {
    static func reduce(_ input: NotchPresentationInput) -> NotchPresentationState {
        let sessions = input.activeSessions.sorted { $0.lastActivityAt > $1.lastActivityAt }

        guard !sessions.isEmpty else {
            if input.isHovered {
                return .expanded(ExpandedContent(sessions: [], usage: input.usage))
            }
            return .hidden
        }
        if input.isHovered {
            return .expanded(ExpandedContent(sessions: sessions, usage: input.usage))
        }
        return .workingCompact(
            primary: sessions[0],
            count: sessions.count,
            usage: input.usage
        )
    }
}
