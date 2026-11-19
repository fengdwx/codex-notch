import CryptoKit
import Foundation

struct AccountIdentity: Equatable, Sendable {
    let accountIdentifier: String?
    let userIdentifier: String?
    let email: String?
    let planType: String?
    let fingerprint: String

    init(
        accountIdentifier: String?,
        userIdentifier: String? = nil,
        email: String?,
        planType: String?,
        fingerprint: String
    ) {
        self.accountIdentifier = accountIdentifier
        self.userIdentifier = userIdentifier
        self.email = email
        self.planType = planType
        self.fingerprint = fingerprint
    }

    /// Matches Codex Desktop's `electron-renderer-content-owner` hash:
    /// lowercase hex SHA-256 of `JSON.stringify([userId, accountId])`.
    var ownerHash: String? {
        guard
            let userIdentifier,
            let accountIdentifier,
            let serialized = Self.jsonTupleKey([userIdentifier, accountIdentifier])
        else {
            return nil
        }
        let digest = SHA256.hash(data: Data(serialized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Serializes a string tuple in the exact compact UTF-8 JSON format
    /// produced by JavaScript's `JSON.stringify(parts)`.
    static func jsonTupleKey(_ parts: [String]) -> String? {
        guard JSONSerialization.isValidJSONObject(parts),
              let data = try? JSONSerialization.data(
                  withJSONObject: parts,
                  options: [.withoutEscapingSlashes]
              )
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

enum AccountIdentityParser {
    /// Reads the ChatGPT identity out of a Codex `auth.json` without touching
    /// the network. Only the id_token payload is inspected; tokens are never
    /// logged.
    static func parse(_ data: Data) throws -> AccountIdentity {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tokens = root["tokens"] as? [String: Any],
            let idToken = tokens["id_token"] as? String,
            !idToken.isEmpty
        else {
            throw AccountError.invalidAuthFile
        }

        let claims = decodeJWTPayload(idToken) ?? [:]
        let auth = claims["https://api.openai.com/auth"] as? [String: Any] ?? [:]
        let accountIdentifier = nonEmpty(auth["chatgpt_account_id"] as? String)
            ?? nonEmpty(tokens["account_id"] as? String)
        let userIdentifier = nonEmpty(auth["chatgpt_user_id"] as? String)
            ?? nonEmpty(auth["user_id"] as? String)
        let email = nonEmpty(claims["email"] as? String)
        let planType = nonEmpty(auth["chatgpt_plan_type"] as? String)

        return AccountIdentity(
            accountIdentifier: accountIdentifier,
            userIdentifier: userIdentifier,
            email: email,
            planType: planType,
            fingerprint: fingerprint(idToken)
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }

    static func fingerprint(_ idToken: String) -> String {
        let digest = SHA256.hash(data: Data(idToken.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 {
            payload.append("=")
        }
        guard
            let data = Data(base64Encoded: payload),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return object
    }
}

/// Non-sensitive freshness metadata extracted from a Codex `auth.json` payload
/// (`last_refresh`, JWT `iat`, and JWT `exp`) so CodexNotch never overwrites a
/// fresher rotated refresh token with an older Vault or file copy.
struct AccountAuthFreshness: Equatable, Sendable {
    let lastRefresh: Date?
    let issuedAt: Date?
    let expiresAt: Date?

    var freshnessDate: Date? {
        [lastRefresh, issuedAt].compactMap { $0 }.max()
    }

    func isExpired(at now: Date = .now) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= now
    }

    static func parse(_ data: Data) -> AccountAuthFreshness {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return AccountAuthFreshness(lastRefresh: nil, issuedAt: nil, expiresAt: nil)
        }
        let lastRefresh = (root["last_refresh"] as? String).flatMap(parseISO8601Date)
        let tokens = root["tokens"] as? [String: Any]
        let accessClaims = (tokens?["access_token"] as? String).flatMap(AccountIdentityParser.decodeJWTPayload)
        let idClaims = (tokens?["id_token"] as? String).flatMap(AccountIdentityParser.decodeJWTPayload)

        let issuedAt = unixDate(in: accessClaims, key: "iat") ?? unixDate(in: idClaims, key: "iat")
        let expiresAt = unixDate(in: accessClaims, key: "exp") ?? unixDate(in: idClaims, key: "exp")

        return AccountAuthFreshness(
            lastRefresh: lastRefresh,
            issuedAt: issuedAt,
            expiresAt: expiresAt
        )
    }

    static func shouldReplace(
        existing: Data,
        with candidate: Data,
        preferCandidateOnTie: Bool
    ) -> Bool {
        guard candidate != existing else { return false }
        let existingMeta = parse(existing)
        let candidateMeta = parse(candidate)

        if let candidateDate = candidateMeta.freshnessDate,
           let existingDate = existingMeta.freshnessDate {
            if candidateDate > existingDate { return true }
            if candidateDate < existingDate { return false }
            return preferCandidateOnTie
        }
        if candidateMeta.freshnessDate != nil {
            return true
        }
        if existingMeta.freshnessDate != nil {
            return false
        }
        return preferCandidateOnTie
    }

    private static func unixDate(in claims: [String: Any]?, key: String) -> Date? {
        guard let number = claims?[key] as? NSNumber else { return nil }
        let seconds = number.doubleValue
        guard seconds.isFinite, seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private static func parseISO8601Date(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: trimmed) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: trimmed) {
            return date
        }

        // Handle microsecond precision (`2026-11-19T07:16:57.634821Z`) cleanly.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for pattern in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX", "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"] {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }
}
