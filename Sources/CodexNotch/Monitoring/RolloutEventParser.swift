import Foundation

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
            return RolloutEvent(
                timestamp: timestamp,
                kind: .sessionMeta(
                    threadID: threadID,
                    cwd: envelope.payload?.cwd,
                    originator: envelope.payload?.originator
                )
            )

        case "event_msg", "task_started", "task_complete", "turn_aborted":
            switch payloadType ?? type {
            case "task_started":
                return RolloutEvent(timestamp: timestamp, kind: .taskStarted(turnID: envelope.payload?.turnID))
            case "task_complete":
                return RolloutEvent(timestamp: timestamp, kind: .taskCompleted(turnID: envelope.payload?.turnID))
            case "turn_aborted":
                return RolloutEvent(timestamp: timestamp, kind: .turnAborted(turnID: envelope.payload?.turnID))
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

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case turnID = "turn_id"
        case cwd
        case originator
    }
}
