import Foundation

enum RolloutEventKind: Equatable, Sendable {
    case sessionMeta(threadID: String, cwd: String?, originator: String?)
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
    let cwd: String?
    let originator: String?
    let startedAt: Date
    let lastActivityAt: Date

    var id: String { "\(threadID)#\(turnID)" }

    func updating(
        threadID: String = "",
        cwd: String? = nil,
        originator: String? = nil,
        lastActivityAt: Date? = nil
    ) -> SessionActivity {
        SessionActivity(
            threadID: threadID.isEmpty ? self.threadID : threadID,
            turnID: turnID,
            cwd: cwd ?? self.cwd,
            originator: originator ?? self.originator,
            startedAt: startedAt,
            lastActivityAt: lastActivityAt ?? self.lastActivityAt
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

        for (index, event) in events.enumerated() {
            switch event.kind {
            case let .sessionMeta(newThreadID, newCWD, newOriginator):
                threadID = newThreadID
                cwd = newCWD
                originator = newOriginator
                active = active.mapValues {
                    $0.updating(threadID: threadID, cwd: cwd, originator: originator)
                }

            case let .taskStarted(turnID):
                let resolvedTurnID = turnID ?? "anonymous-turn-\(index)"
                let timestamp = event.timestamp ?? .distantPast
                active[resolvedTurnID] = SessionActivity(
                    threadID: threadID,
                    turnID: resolvedTurnID,
                    cwd: cwd,
                    originator: originator,
                    startedAt: timestamp,
                    lastActivityAt: timestamp
                )

            case let .taskCompleted(turnID), let .turnAborted(turnID):
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
        if let turnID, active[turnID] != nil {
            return turnID
        }
        return active.max { $0.value.lastActivityAt < $1.value.lastActivityAt }?.key
    }
}
