import Foundation

struct ActiveSessionStoreSnapshot: Equatable, Sendable {
    let activeSessions: [SessionActivity]
    let recentCompletions: [CompletedSession]

    var latestCompletion: CompletedSession? {
        recentCompletions.first
    }
}

actor ActiveSessionStore {
    static let defaultStaleAfter: TimeInterval = 6 * 60 * 60

    private struct RolloutState {
        let active: [SessionActivity]
        let completed: [CompletedSession]
        let lastModifiedAt: Date
    }

    private let staleAfter: TimeInterval
    private var rollouts: [String: RolloutState] = [:]

    init(staleAfter: TimeInterval = ActiveSessionStore.defaultStaleAfter) {
        self.staleAfter = staleAfter
    }

    func replace(
        rolloutID: String,
        reduction: ActiveSessionReduction,
        lastModifiedAt: Date
    ) {
        rollouts[rolloutID] = RolloutState(
            active: reduction.active,
            completed: reduction.completed.map {
                CompletedSession(session: $0, completedAt: $0.lastActivityAt)
            },
            lastModifiedAt: lastModifiedAt
        )
    }

    func activeSessions(now: Date = .now) -> [SessionActivity] {
        snapshot(now: now).activeSessions
    }

    func snapshot(now: Date = .now) -> ActiveSessionStoreSnapshot {
        let activeCutoff = now.addingTimeInterval(-staleAfter)
        // Age only invalidates unfinished work. Completed conversations stay
        // available until their rollout is removed or superseded in discovery.
        let active = rollouts.values
            .filter { $0.lastModifiedAt >= activeCutoff }
            .flatMap(\.active)
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
        let sortedCompletions = rollouts.values
            .flatMap(\.completed)
            .sorted { $0.completedAt > $1.completedAt }
        var seenThreadIDs = Set<String>()
        let recentCompletions = sortedCompletions.filter { completion in
            seenThreadIDs.insert(completion.session.threadID).inserted
        }

        return ActiveSessionStoreSnapshot(
            activeSessions: active,
            recentCompletions: recentCompletions
        )
    }

    func remove(rolloutID: String) {
        rollouts.removeValue(forKey: rolloutID)
    }
}
