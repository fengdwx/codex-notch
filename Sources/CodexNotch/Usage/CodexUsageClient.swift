import Foundation

enum CodexUsageError: Error, Equatable {
    case reauthenticationRequired
    case invalidHTTPResponse
    case httpStatus(Int)
    case decodingFailed
    case invalidResetRequest
    case resetHTTPStatus(status: Int, code: String?)
}

struct CodexUsageClient {
    static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }()

    static let defaultEndpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    static let defaultResetCreditsEndpoint = URL(
        string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits"
    )!

    let credentials: CodexCredentials
    let session: URLSession
    let endpoint: URL
    let resetCreditsEndpoint: URL

    init(credentials: CodexCredentials,
         session: URLSession = CodexUsageClient.defaultSession,
         endpoint: URL = CodexUsageClient.defaultEndpoint,
         resetCreditsEndpoint: URL? = nil) {
        self.credentials = credentials
        self.session = session
        self.endpoint = endpoint
        self.resetCreditsEndpoint = resetCreditsEndpoint
            ?? (endpoint == Self.defaultEndpoint
                ? Self.defaultResetCreditsEndpoint
                : endpoint.deletingLastPathComponent().appendingPathComponent("rate-limit-reset-credits"))
    }

    func fetch(requireResetCredits: Bool = false) async throws -> UsageSnapshot {
        let data = try await fetchData(from: endpoint)
        let usageResponse: UsageResponseDTO
        do {
            usageResponse = try JSONDecoder().decode(UsageResponseDTO.self, from: data)
        } catch {
            throw CodexUsageError.decodingFailed
        }

        let usageSnapshot = usageResponse.snapshot()

        // Credit detail is an auxiliary endpoint. A failure must not hide a
        // successfully fetched weekly quota or the count returned by /usage.
        let resetCredits: ResetCreditsDTO
        do {
            resetCredits = try await fetchResetCredits()
            if requireResetCredits && resetCredits.credits == nil {
                throw CodexUsageError.decodingFailed
            }
        } catch {
            try Task.checkCancellation()
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw error
            }
            if requireResetCredits { throw error }
            return usageSnapshot
        }

        return usageSnapshot.replacingResetCredits(
            availableCount: resetCredits.availableCount,
            credits: resetCredits.credits.map { _ in resetCredits.availableCredits }
        )
    }

    func fetchResetCredits() async throws -> ResetCreditsDTO {
        let data = try await fetchData(from: resetCreditsEndpoint)
        do {
            return try JSONDecoder().decode(ResetCreditsDTO.self, from: data)
        } catch {
            throw CodexUsageError.decodingFailed
        }
    }

    /// The caller retains one key for one logical attempt, including retries
    /// after a timeout or lost response. This method never retries a POST.
    func consumeResetCredit(
        creditID: String,
        idempotencyKey: String
    ) async throws -> ResetCreditConsumptionOutcome {
        guard !creditID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !idempotencyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CodexUsageError.invalidResetRequest
        }
        try Task.checkCancellation()
        var request = authorizedRequest(to: resetCreditsEndpoint.appendingPathComponent("consume"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ResetCreditConsumptionRequest(
            creditID: creditID,
            redeemRequestID: idempotencyKey
        ))

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw CodexUsageError.invalidHTTPResponse
        }
        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 {
                throw CodexUsageError.reauthenticationRequired
            }
            throw CodexUsageError.resetHTTPStatus(
                status: response.statusCode,
                code: safeResetErrorCode(from: data)
            )
        }
        do {
            return try JSONDecoder().decode(ResetCreditConsumptionResponseDTO.self, from: data).code
        } catch {
            throw CodexUsageError.decodingFailed
        }
    }

    private func fetchData(from endpoint: URL) async throws -> Data {
        try Task.checkCancellation()
        var request = authorizedRequest(to: endpoint)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexUsageError.invalidHTTPResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw CodexUsageError.reauthenticationRequired
            }
            throw CodexUsageError.httpStatus(httpResponse.statusCode)
        }

        return data
    }

    private func authorizedRequest(to endpoint: URL) -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        if let accountID = credentials.accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        return request
    }

    private func safeResetErrorCode(from data: Data) -> String? {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let code = (payload["error"] as? [String: Any])?["code"] as? String
            ?? payload["code"] as? String
            ?? (payload["detail"] as? [String: Any])?["code"] as? String
        // Never surface arbitrary backend text, identifiers, or credentials.
        let safeCodes: Set<String> = [
            "nothing_to_reset", "no_credit", "already_redeemed",
            "invalid_request", "invalid_request_error", "invalid_credit", "credit_expired",
            "unauthorized", "forbidden", "permission_denied", "insufficient_permissions",
            "rate_limit_exceeded", "too_many_requests", "internal_error", "server_error"
        ]
        return code.flatMap { safeCodes.contains($0) ? $0 : nil }
    }
}

private struct ResetCreditConsumptionRequest: Encodable {
    let creditID: String
    let redeemRequestID: String

    enum CodingKeys: String, CodingKey {
        case creditID = "credit_id"
        case redeemRequestID = "redeem_request_id"
    }
}
