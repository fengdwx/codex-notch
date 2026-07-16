import Foundation

struct ActiveSessionStoreSnapshot: Equatable, Sendable {
    let activeSessions: [SessionActivity]
    let recentCompletions: [CompletedSession]

    var latestCompletion: CompletedSession? {
        recentCompletions.first
    }
}

actor ActiveSessionStore {
    private struct RolloutState {
        let active: [SessionActivity]
        let completed: [CompletedSession]
        let lastModifiedAt: Date
    }

    private let staleAfter: TimeInterval
    private let historyRetention: TimeInterval
    private var rollouts: [String: RolloutState] = [:]

    init(
        staleAfter: TimeInterval = 6 * 60 * 60,
        historyRetention: TimeInterval = 24 * 60 * 60
    ) {
        self.staleAfter = staleAfter
        self.historyRetention = historyRetention
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
        let retentionCutoff = now.addingTimeInterval(-max(staleAfter, historyRetention))
        rollouts = rollouts.filter { $0.value.lastModifiedAt >= retentionCutoff }

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
