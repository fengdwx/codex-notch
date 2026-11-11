import CryptoKit
import Foundation

struct AccountIdentity: Equatable, Sendable {
    let accountIdentifier: String?
    let email: String?
    let planType: String?
    let fingerprint: String
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
        let accountIdentifier = (auth["chatgpt_account_id"] as? String)
            ?? (tokens["account_id"] as? String)
        let email = claims["email"] as? String
        let planType = auth["chatgpt_plan_type"] as? String

        return AccountIdentity(
            accountIdentifier: accountIdentifier,
            email: email,
            planType: planType,
            fingerprint: fingerprint(idToken)
        )
    }

    static func fingerprint(_ idToken: String) -> String {
        let digest = SHA256.hash(data: Data(idToken.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
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
