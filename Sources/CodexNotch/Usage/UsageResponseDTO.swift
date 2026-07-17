import Foundation

struct UsageResponseDTO: Decodable {
    let primaryWindow: WindowDTO?
    let secondaryWindow: WindowDTO?
    let rateLimit: RateLimitDTO?
    let rateLimitResetCredits: ResetCreditsDTO?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
        case rateLimit = "rate_limit"
        case rateLimitResetCredits = "rate_limit_reset_credits"
    }

    func snapshot(fetchedAt: Date = .now) -> UsageSnapshot {
        // The current ChatGPT endpoint nests the windows under `rate_limit`.
        // Keep the top-level fields as a compatibility fallback because older
        // responses (and our fixtures) exposed them directly.
        let windows = [
            makeWindow(id: "primary", dto: primaryWindow ?? rateLimit?.primaryWindow),
            makeWindow(id: "secondary", dto: secondaryWindow ?? rateLimit?.secondaryWindow)
        ].compactMap { $0 }

        return UsageSnapshot(
            windows: windows,
            resetCreditsAvailable: rateLimitResetCredits?.availableCount,
            resetCredits: rateLimitResetCredits?.availableCredits ?? [],
            fetchedAt: fetchedAt
        )
    }

    private func makeWindow(id: String, dto: WindowDTO?) -> UsageWindow? {
        guard let dto,
              let usedPercent = dto.usedPercent,
              let seconds = dto.limitWindowSeconds else {
            return nil
        }

        return UsageWindow(
            id: id,
            kind: UsageWindowClassifier.kind(seconds: seconds),
            usedPercent: usedPercent,
            resetAt: dto.resetAt
        )
    }
}

struct RateLimitDTO: Decodable {
    let primaryWindow: WindowDTO?
    let secondaryWindow: WindowDTO?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

struct WindowDTO: Decodable {
    let usedPercent: Double?
    let limitWindowSeconds: Int?
    let resetAt: Date?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case limitWindowSeconds = "limit_window_seconds"
        case resetAt = "reset_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = try container.decodeIfPresent(Double.self, forKey: .usedPercent)
        limitWindowSeconds = try container.decodeIfPresent(Int.self, forKey: .limitWindowSeconds)

        if let epoch = try? container.decode(Double.self, forKey: .resetAt) {
            let seconds = epoch > 1_000_000_000_000 ? epoch / 1_000 : epoch
            resetAt = Date(timeIntervalSince1970: seconds)
        } else if let text = try? container.decode(String.self, forKey: .resetAt) {
            resetAt = ISO8601DateFormatter().date(from: text)
        } else {
            resetAt = nil
        }
    }
}

struct ResetCreditsDTO: Decodable {
    let availableCount: Int?
    let credits: [ResetCreditDTO]?

    enum CodingKeys: String, CodingKey {
        case availableCount = "available_count"
        case credits
    }

    var availableCredits: [ResetCredit] {
        (credits ?? [])
            .filter { $0.status == "available" }
            .enumerated()
            .map { index, credit in
                ResetCredit(
                    id: credit.id ?? "reset-credit-\(index)-\(credit.expiresAt?.timeIntervalSince1970 ?? 0)",
                    title: credit.title,
                    expiresAt: credit.expiresAt
                )
            }
    }
}

struct ResetCreditDTO: Decodable {
    let id: String?
    let title: String?
    let status: String?
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case status
        case expiresAt = "expires_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        expiresAt = FlexibleDate.decode(from: container, forKey: .expiresAt)
    }
}

private enum FlexibleDate {
    static func decode<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) -> Date? {
        if let epoch = try? container.decode(Double.self, forKey: key) {
            let seconds = epoch > 1_000_000_000_000 ? epoch / 1_000 : epoch
            return Date(timeIntervalSince1970: seconds)
        }
        if let text = try? container.decode(String.self, forKey: key) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions.insert(.withFractionalSeconds)
            return formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
        }
        return nil
    }
}
