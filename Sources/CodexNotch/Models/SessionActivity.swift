import Foundation

enum RolloutEventKind: Equatable, Sendable {
    case sessionMeta(threadID: String, cwd: String?, originator: String?)
    case userMessage(message: String)
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
        title: String? = nil,
        cwd: String? = nil,
        originator: String? = nil,
        lastActivityAt: Date? = nil
    ) -> SessionActivity {
        SessionActivity(
            threadID: threadID.isEmpty ? self.threadID : threadID,
            turnID: turnID,
            title: title ?? self.title,
            cwd: cwd ?? self.cwd,
            originator: originator ?? self.originator,
            startedAt: startedAt,
            lastActivityAt: lastActivityAt ?? self.lastActivityAt
        )
    }
}

enum ConversationTitle {
    static let maximumLength = 96

    static func normalized(_ rawValue: String) -> String? {
        let collapsed = rawValue
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        guard !collapsed.hasPrefix("# Response annotations:"),
              !collapsed.hasPrefix("# Files mentioned by the user:") else {
            return nil
        }
        return String(collapsed.prefix(maximumLength))
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
        var latestTitle: String?
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

            case let .userMessage(message):
                guard let title = ConversationTitle.normalized(message) else { continue }
                latestTitle = title
                guard let key = matchingKey(for: nil, active: active),
                      let session = active[key] else {
                    continue
                }
                active[key] = session.updating(title: title, lastActivityAt: event.timestamp)

            case let .taskStarted(turnID):
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
                    title: latestTitle,
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
        if let turnID {
            // A late terminal event for a turn that was superseded by a newer
            // turn must not fall back to and finish the newer active turn.
            return active[turnID] == nil ? nil : turnID
        }
        return active.max { $0.value.lastActivityAt < $1.value.lastActivityAt }?.key
    }
}
