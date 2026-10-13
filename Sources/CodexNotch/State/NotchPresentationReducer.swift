import Foundation

enum NotchPresentationReducer {
    static func reduce(_ input: NotchPresentationInput) -> NotchPresentationState {
        let sessions = input.activeSessions.sorted { $0.lastActivityAt > $1.lastActivityAt }

        if input.isHovered {
            return .expanded(expandedContent(input: input, sessions: sessions))
        }
        if let completion = input.completionFeedback, completion.session.termination == .completed {
            return .completedCompact(completion.session, usage: input.usage)
        }
        if let primary = sessions.first {
            return .workingCompact(
                primary: primary,
                count: sessions.count,
                usage: input.usage
            )
        }
        return .quotaCompact(input.usage)
    }

    private static func expandedContent(
        input: NotchPresentationInput,
        sessions: [SessionActivity]
    ) -> ExpandedContent {
        var seenThreadIDs = Set<String>()
        var conversations: [ConversationSummary] = []

        for session in sessions where seenThreadIDs.insert(session.threadID).inserted {
            conversations.append(
                ConversationSummary(
                    session: session,
                    activity: .running(startedAt: session.startedAt)
                )
            )
        }
        for completion in input.recentCompletions
            where seenThreadIDs.insert(completion.session.threadID).inserted {
            conversations.append(
                ConversationSummary(
                    session: completion.session,
                    activity: completion.session.termination == .aborted
                        ? .stopped(completedAt: completion.completedAt)
                        : .completed(completedAt: completion.completedAt)
                )
            )
        }

        return ExpandedContent(
            sessions: sessions,
            // Preserve enough data for the user's display preference. The
            // coordinator applies that preference immediately before render.
            conversations: Array(
                conversations.prefix(RecentConversationLimit.five.rawValue)
            ),
            headerConversation: conversations.first,
            usage: input.usage,
            completionFeedback: input.completionFeedback.flatMap {
                $0.session.termination == .completed ? $0 : nil
            }
        )
    }
}
