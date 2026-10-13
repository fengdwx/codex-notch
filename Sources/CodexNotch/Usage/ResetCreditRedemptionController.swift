import Foundation

enum ResetCreditRedemptionError: Error, Equatable {
    case busy
    case unavailable
    case accountChanged
}

/// An explicit user action only. All state, including retry keys, stays in memory.
@MainActor
final class ResetCreditRedemptionController {
    private struct Attempt: Hashable {
        let account: String
        let credit: String
    }

    private let readCredentials: () throws -> CodexCredentials
    private let fetchCredits: (CodexCredentials) async throws -> [ResetCredit]
    private let consume: (CodexCredentials, String, String) async throws -> ResetCreditConsumptionOutcome
    private let now: () -> Date
    private var retryKeys: [Attempt: String] = [:]
    private var finished: Set<Attempt> = []
    private(set) var isProcessing = false

    init(
        readCredentials: @escaping () throws -> CodexCredentials,
        fetchCredits: @escaping (CodexCredentials) async throws -> [ResetCredit],
        consume: @escaping (CodexCredentials, String, String) async throws -> ResetCreditConsumptionOutcome,
        now: @escaping () -> Date = { .now }
    ) {
        self.readCredentials = readCredentials
        self.fetchCredits = fetchCredits
        self.consume = consume
        self.now = now
    }

    func redeem(
        _ credit: ResetCredit,
        expectedCredentials: CodexCredentials
    ) async throws -> ResetCreditConsumptionOutcome {
        guard !isProcessing else { throw ResetCreditRedemptionError.busy }
        guard credit.canRedeem(at: now()), let creditID = credit.redemptionID else {
            throw ResetCreditRedemptionError.unavailable
        }
        isProcessing = true
        defer { isProcessing = false }

        let credentials = try readCredentials()
        guard Self.sameAccount(credentials, expectedCredentials) else {
            throw ResetCreditRedemptionError.accountChanged
        }
        let attempt = Attempt(account: credentials.accountID ?? credentials.accessToken, credit: creditID)
        guard !finished.contains(attempt) else { throw ResetCreditRedemptionError.unavailable }

        // Confirm the selected credit still exists immediately before the write.
        let available = try await fetchCredits(credentials)
        try Task.checkCancellation()
        guard available.contains(where: { $0.redemptionID == creditID && $0.canRedeem(at: now()) }) else {
            throw ResetCreditRedemptionError.unavailable
        }
        let latestCredentials = try readCredentials()
        guard Self.sameAccount(credentials, latestCredentials) else {
            throw ResetCreditRedemptionError.accountChanged
        }
        let key = retryKeys[attempt] ?? UUID().uuidString
        retryKeys[attempt] = key
        // Never retry automatically. An explicit retry after an ambiguous error
        // reuses this key, even if the first request actually reached the server.
        let outcome = try await consume(latestCredentials, creditID, key)
        if outcome == .reset || outcome == .alreadyRedeemed || outcome == .noCredit {
            finished.insert(attempt)
        }
        // A definite response ends this logical attempt, including a no-op.
        // Only an ambiguous thrown error retains its idempotency key.
        retryKeys.removeValue(forKey: attempt)
        return outcome
    }

    static func sameAccount(_ lhs: CodexCredentials, _ rhs: CodexCredentials) -> Bool {
        if let left = lhs.accountID, !left.isEmpty, let right = rhs.accountID, !right.isEmpty {
            return left == right
        }
        return lhs.accountID == rhs.accountID && lhs.accessToken == rhs.accessToken
    }
}
