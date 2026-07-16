import Foundation

struct ActiveSessionStoreSnapshot: Equatable, Sendable {
    let activeSessions: [SessionActivity]
    let latestCompletion: CompletedSession?
}

actor ActiveSessionStore {
    private struct RolloutState {
        let active: [SessionActivity]
        let completed: [CompletedSession]
        let lastModifiedAt: Date
    }

    private let staleAfter: TimeInterval
    private var rollouts: [String: RolloutState] = [:]

    init(staleAfter: TimeInterval = 6 * 60 * 60) {
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
        let cutoff = now.addingTimeInterval(-staleAfter)
        rollouts = rollouts.filter { $0.value.lastModifiedAt >= cutoff }

        let active = rollouts.values
            .flatMap(\.active)
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
        let latestCompletion = rollouts.values
            .flatMap(\.completed)
            .max { $0.completedAt < $1.completedAt }

        return ActiveSessionStoreSnapshot(
            activeSessions: active,
            latestCompletion: latestCompletion
        )
    }

    func remove(rolloutID: String) {
        rollouts.removeValue(forKey: rolloutID)
    }
}
