import Foundation

enum RolloutEventKind: Equatable, Sendable {
    case sessionMeta(threadID: String, cwd: String?, originator: String?)
    case subagentSessionMeta(threadID: String, cwd: String?, originator: String?)
    case taskStarted(turnID: String?)
    case taskCompleted(turnID: String?)
    case turnAborted(turnID: String?)
}

struct RolloutEvent: Equatable, Sendable {
    let timestamp: Date?
    let kind: RolloutEventKind
}

struct SessionActivity: Equatable, Identifiable, Sendable {
    let threadID: String
    let turnID: String
    let title: String?
    let cwd: String?
    let originator: String?
    let startedAt: Date
    let lastActivityAt: Date

    var id: String { "\(threadID)#\(turnID)" }

    init(
        threadID: String,
        turnID: String,
        title: String? = nil,
        cwd: String?,
        originator: String?,
        startedAt: Date,
        lastActivityAt: Date
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.title = title
        self.cwd = cwd
        self.originator = originator
        self.startedAt = startedAt
        self.lastActivityAt = lastActivityAt
    }

    func updating(
        threadID: String = "",
        cwd: String? = nil,
        originator: String? = nil,
        lastActivityAt: Date? = nil
    ) -> SessionActivity {
        SessionActivity(
            threadID: threadID.isEmpty ? self.threadID : threadID,
            turnID: turnID,
            title: title,
            cwd: cwd ?? self.cwd,
            originator: originator ?? self.originator,
            startedAt: startedAt,
            lastActivityAt: lastActivityAt ?? self.lastActivityAt
        )
    }

    func withTitle(_ title: String?) -> SessionActivity {
        SessionActivity(
            threadID: threadID,
            turnID: turnID,
            title: title,
            cwd: cwd,
            originator: originator,
            startedAt: startedAt,
            lastActivityAt: lastActivityAt
        )
    }
}

struct ActiveSessionReduction: Equatable, Sendable {
    let active: [SessionActivity]
    let completed: [SessionActivity]
}

enum ActiveSessionReducer {
    static func reduce(_ events: [RolloutEvent]) -> ActiveSessionReduction {
        var threadID = "unknown-thread"
        var cwd: String?
        var originator: String?
        var active: [String: SessionActivity] = [:]
        var completed: [SessionActivity] = []
        var isSubagentRollout = false

        for (index, event) in events.enumerated() {
            switch event.kind {
            case let .sessionMeta(newThreadID, newCWD, newOriginator):
                isSubagentRollout = false
                threadID = newThreadID
                cwd = newCWD
                originator = newOriginator
                active = active.mapValues {
                    $0.updating(threadID: threadID, cwd: cwd, originator: originator)
                }

            case .subagentSessionMeta:
                isSubagentRollout = true
                active.removeAll()

            case let .taskStarted(turnID):
                guard !isSubagentRollout else { continue }
                let resolvedTurnID = turnID ?? "anonymous-turn-\(index)"
                let timestamp = event.timestamp ?? .distantPast
                // A rollout represents one serial Codex conversation. When
                // the log starts another turn before an earlier one records a
                // terminal event, that earlier turn was interrupted or lost
                // its terminal event; it must not keep the compact notch in
                // the running state for the store's six-hour stale window.
                for key in active.keys.filter({ active[$0]?.threadID == threadID }) {
                    active.removeValue(forKey: key)
                }
                active[resolvedTurnID] = SessionActivity(
                    threadID: threadID,
                    turnID: resolvedTurnID,
                    title: nil,
                    cwd: cwd,
                    originator: originator,
                    startedAt: timestamp,
                    lastActivityAt: timestamp
                )

            case let .taskCompleted(turnID), let .turnAborted(turnID):
                guard !isSubagentRollout else { continue }
                guard let key = matchingKey(for: turnID, active: active),
                      let item = active.removeValue(forKey: key) else {
                    continue
                }
                completed.append(item.updating(lastActivityAt: event.timestamp ?? item.lastActivityAt))
            }
        }

        return ActiveSessionReduction(
            active: active.values.sorted { $0.lastActivityAt > $1.lastActivityAt },
            completed: completed
        )
    }

    private static func matchingKey(
        for turnID: String?,
        active: [String: SessionActivity]
    ) -> String? {
        if let turnID {
            // A late terminal event for a turn that was superseded by a newer
            // turn must not fall back to and finish the newer active turn.
            return active[turnID] == nil ? nil : turnID
        }
        return active.max { $0.value.lastActivityAt < $1.value.lastActivityAt }?.key
    }
}
