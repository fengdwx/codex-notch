import Foundation

/// Transient feedback for observed normal turn endings, independent of history.
/// This keeps no messages or persistent notification/read-state cache.
struct CompletionFeedbackTracker {
    static let duration: TimeInterval = 5

    private struct TurnIdentity: Hashable {
        let threadID: String
        let turnID: String
        let startedAt: Date

        init(_ session: SessionActivity) {
            threadID = session.threadID
            turnID = session.turnID
            startedAt = session.startedAt
        }
    }

    private struct CompletionIdentity: Hashable {
        let turn: TurnIdentity
        let endedAt: Date

        init(_ completion: CompletedSession) {
            turn = TurnIdentity(completion.session)
            endedAt = completion.completedAt
        }
    }

    private var observationStartedAt: Date?
    private var latestObservedEndAt: Date?
    private var seenAtLatestEnd: Set<CompletionIdentity> = []
    private var activeTurns: Set<TurnIdentity> = []
    private var expiresAt: Date?
    private(set) var feedback: CompletedSession?

    @discardableResult
    mutating func observe(
        _ snapshot: ActiveSessionStoreSnapshot,
        initialScanComplete: Bool,
        now: Date
    ) -> Bool {
        let previousFeedback = feedback
        expire(now: now)
        if observationStartedAt == nil { observationStartedAt = now }
        guard initialScanComplete else { return previousFeedback != feedback }

        let currentTurns = Set(snapshot.activeSessions.map(TurnIdentity.init))
        guard let latestObservedEndAt else {
            // Discovery publishes files one by one. Only the completed initial
            // scan establishes a baseline; an empty early snapshot is not one.
            let cutoff = max(observationStartedAt ?? now, snapshot.recentCompletions.map(\.completedAt).max() ?? .distantPast)
            self.latestObservedEndAt = cutoff
            activeTurns = currentTurns
            seenAtLatestEnd = Set(snapshot.recentCompletions.filter { $0.completedAt == cutoff }.map(CompletionIdentity.init))
            return previousFeedback != feedback
        }

        let hasNewTask = !currentTurns.subtracting(activeTurns).isEmpty
        activeTurns = currentTurns
        let newEndings = snapshot.recentCompletions.filter {
            $0.completedAt > latestObservedEndAt
                || ($0.completedAt == latestObservedEndAt && !seenAtLatestEnd.contains(CompletionIdentity($0)))
        }
        if let newestEnd = newEndings.map(\.completedAt).max() {
            if newestEnd > latestObservedEndAt {
                self.latestObservedEndAt = newestEnd
                seenAtLatestEnd = []
            }
            seenAtLatestEnd.formUnion(newEndings.filter { $0.completedAt == newestEnd }.map(CompletionIdentity.init))
        }

        if hasNewTask {
            // New work takes over immediately, including a start and another
            // task's terminal event delivered together in one snapshot.
            clear()
        } else if let completion = newEndings
            .filter({ $0.session.termination == .completed })
            .max(by: { $0.completedAt < $1.completedAt }) {
            feedback = completion
            expiresAt = now.addingTimeInterval(Self.duration)
        } else if let feedback,
                  newEndings.contains(where: {
                      $0.session.threadID == feedback.session.threadID && $0.session.termination == .aborted
                  }) {
            clear()
        }
        return previousFeedback != feedback
    }

    @discardableResult
    mutating func expire(now: Date) -> Bool {
        guard let expiresAt, now >= expiresAt else { return false }
        clear()
        return true
    }

    private mutating func clear() {
        feedback = nil
        expiresAt = nil
    }
}
