import Foundation

enum CodexUsageError: Error, Equatable {
    case reauthenticationRequired
    case invalidHTTPResponse
    case httpStatus(Int)
    case decodingFailed
}

struct CodexUsageClient {
    static let defaultEndpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    static let defaultResetCreditsEndpoint = URL(
        string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits"
    )!

    let credentials: CodexCredentials
    let session: URLSession
    let endpoint: URL
    let resetCreditsEndpoint: URL

    init(credentials: CodexCredentials,
         session: URLSession = .shared,
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

    func fetch() async throws -> UsageSnapshot {
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
        guard let resetCredits = try? await fetchResetCredits() else {
            return usageSnapshot
        }

        return usageSnapshot.replacingResetCredits(
            availableCount: resetCredits.availableCount,
            credits: resetCredits.availableCredits
        )
    }

    private func fetchResetCredits() async throws -> ResetCreditsDTO {
        let data = try await fetchData(from: resetCreditsEndpoint)
        do {
            return try JSONDecoder().decode(ResetCreditsDTO.self, from: data)
        } catch {
            throw CodexUsageError.decodingFailed
        }
    }

    private func fetchData(from endpoint: URL) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        if let accountID = credentials.accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexUsageError.invalidHTTPResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw CodexUsageError.reauthenticationRequired
            }
            throw CodexUsageError.httpStatus(httpResponse.statusCode)
        }

        return data
    }
}
