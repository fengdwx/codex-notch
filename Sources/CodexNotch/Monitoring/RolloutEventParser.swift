import Foundation

enum RolloutParsedRecord: Equatable, Sendable {
    case event(RolloutEvent)
    case rateLimit(RolloutRateLimitObservation)
}

enum RolloutEventParser {
    private static let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let ISO8601Formatter = ISO8601DateFormatter()

    static func parse(data: Data) -> [RolloutEvent] {
        data.split(separator: 0x0A, omittingEmptySubsequences: true)
            .compactMap { parseLine(Data($0)) }
    }

    static func parseLine(_ data: Data) -> RolloutEvent? {
        guard case let .event(event) = parseRecord(data) else { return nil }
        return event
    }

    static func parseRecord(_ data: Data) -> RolloutParsedRecord? {
        guard let envelope = try? JSONDecoder().decode(EnvelopeDTO.self, from: data),
              let type = envelope.type else {
            return nil
        }

        let timestamp = envelope.timestamp.flatMap { value in
            fractionalISO8601Formatter.date(from: value)
                ?? ISO8601Formatter.date(from: value)
        }
        let payloadType = envelope.payload?.type

        switch type {
        case "session_meta":
            guard let threadID = envelope.payload?.id, !threadID.isEmpty else { return nil }
            let payload = envelope.payload
            if payload?.isSubagent == true {
                return .event(RolloutEvent(
                    timestamp: timestamp,
                    kind: .subagentSessionMeta(
                        threadID: threadID,
                        cwd: payload?.cwd,
                        originator: payload?.originator
                    )
                ))
            }
            return .event(RolloutEvent(
                timestamp: timestamp,
                kind: .sessionMeta(
                    threadID: threadID,
                    cwd: payload?.cwd,
                    originator: payload?.originator
                )
            ))

        case "event_msg", "task_started", "task_complete", "turn_aborted":
            switch payloadType ?? type {
            case "task_started":
                return .event(RolloutEvent(timestamp: timestamp, kind: .taskStarted(turnID: envelope.payload?.turnID)))
            case "user_message":
                return nil
            case "task_complete":
                return .event(RolloutEvent(timestamp: timestamp, kind: .taskCompleted(turnID: envelope.payload?.turnID)))
            case "turn_aborted":
                return .event(RolloutEvent(timestamp: timestamp, kind: .turnAborted(turnID: envelope.payload?.turnID)))
            case "token_count":
                guard let timestamp,
                      let observation = envelope.payload?.rateLimits?.observation(observedAt: timestamp) else {
                    return nil
                }
                return .rateLimit(observation)
            default:
                return nil
            }

        default:
            return nil
        }
    }
}

private struct EnvelopeDTO: Decodable {
    let timestamp: String?
    let type: String?
    let payload: PayloadDTO?
}

private struct PayloadDTO: Decodable {
    let id: String?
    let type: String?
    let turnID: String?
    let cwd: String?
    let originator: String?
    let parentThreadID: String?
    let source: SourceDTO?
    let rateLimits: RolloutRateLimitsDTO?

    var isSubagent: Bool {
        source?.containsSubagentThreadSpawn == true
            || !(parentThreadID?.isEmpty ?? true)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case turnID = "turn_id"
        case cwd
        case originator
        case parentThreadID = "parent_thread_id"
        case source
        case rateLimits = "rate_limits"
    }
}

private struct RolloutRateLimitsDTO: Decodable {
    let limitID: String?
    let primary: RolloutRateLimitWindowDTO?
    let secondary: RolloutRateLimitWindowDTO?
    let planType: String?

    enum CodingKeys: String, CodingKey {
        case limitID = "limit_id"
        case primary
        case secondary
        case planType = "plan_type"
    }

    func observation(observedAt: Date) -> RolloutRateLimitObservation? {
        if let limitID = limitID?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !limitID.isEmpty,
           limitID != "codex" {
            return nil
        }
        let windows = [
            primary?.window(id: "primary"),
            secondary?.window(id: "secondary")
        ].compactMap { $0 }
        guard !windows.isEmpty else { return nil }
        return RolloutRateLimitObservation(
            observedAt: observedAt,
            windows: windows,
            planType: planType
        )
    }
}

private struct RolloutRateLimitWindowDTO: Decodable {
    let usedPercent: Double?
    let windowMinutes: Int?
    let limitWindowSeconds: Int?
    let resetsAt: Date?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
        case limitWindowSeconds = "limit_window_seconds"
        case resetsAt = "resets_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = try container.decodeIfPresent(Double.self, forKey: .usedPercent)
        windowMinutes = try container.decodeIfPresent(Int.self, forKey: .windowMinutes)
        limitWindowSeconds = try container.decodeIfPresent(Int.self, forKey: .limitWindowSeconds)

        if let epoch = try? container.decode(Double.self, forKey: .resetsAt) {
            let seconds = epoch > 1_000_000_000_000 ? epoch / 1_000 : epoch
            resetsAt = Date(timeIntervalSince1970: seconds)
        } else if let text = try? container.decode(String.self, forKey: .resetsAt) {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions.insert(.withFractionalSeconds)
            resetsAt = fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
        } else {
            resetsAt = nil
        }
    }

    func window(id: String) -> UsageWindow? {
        guard let usedPercent,
              let seconds = limitWindowSeconds ?? windowMinutes.map({ $0 * 60 }),
              seconds > 0 else {
            return nil
        }
        return UsageWindow(
            id: id,
            kind: UsageWindowClassifier.kind(seconds: seconds),
            usedPercent: usedPercent,
            resetAt: resetsAt
        )
    }
}

private struct SourceDTO: Decodable {
    let containsSubagentThreadSpawn: Bool

    init(from decoder: Decoder) throws {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            containsSubagentThreadSpawn = false
            return
        }

        containsSubagentThreadSpawn =
            (try? container.decode(SubagentSourceDTO.self, forKey: .subagent))?.threadSpawn != nil
    }

    private enum CodingKeys: String, CodingKey {
        case subagent
    }
}

private struct SubagentSourceDTO: Decodable {
    let threadSpawn: ThreadSpawnDTO?

    enum CodingKeys: String, CodingKey {
        case threadSpawn = "thread_spawn"
    }
}

private struct ThreadSpawnDTO: Decodable {
    init(from decoder: Decoder) throws {
        _ = try decoder.container(keyedBy: EmptyCodingKeys.self)
    }

    private enum EmptyCodingKeys: String, CodingKey {
        case none
    }
}
