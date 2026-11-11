import Foundation

/// A normalized quota snapshot that is small enough to persist next to an account.
struct AccountQuota: Codable, Equatable, Sendable {
    var primaryUsedPercent: Double?
    var primaryResetsAt: Date?
    var secondaryUsedPercent: Double?
    var secondaryResetsAt: Date?
    var planType: String?
    var checkedAt: Date?

    init(
        primaryUsedPercent: Double? = nil,
        primaryResetsAt: Date? = nil,
        secondaryUsedPercent: Double? = nil,
        secondaryResetsAt: Date? = nil,
        planType: String? = nil,
        checkedAt: Date? = nil
    ) {
        self.primaryUsedPercent = primaryUsedPercent
        self.primaryResetsAt = primaryResetsAt
        self.secondaryUsedPercent = secondaryUsedPercent
        self.secondaryResetsAt = secondaryResetsAt
        self.planType = planType
        self.checkedAt = checkedAt
    }

    init(snapshot: UsageSnapshot, planType: String?, checkedAt: Date = .now) {
        let primary = snapshot.windows.first { $0.id == "primary" }
        let secondary = snapshot.windows.first { $0.id == "secondary" }
        self.init(
            primaryUsedPercent: primary?.usedPercent,
            primaryResetsAt: primary?.resetAt,
            secondaryUsedPercent: secondary?.usedPercent,
            secondaryResetsAt: secondary?.resetAt,
            planType: planType,
            checkedAt: checkedAt
        )
    }

    /// Lowest remaining percentage across the known windows, used for the
    /// compact account badge.
    var lowestRemainingPercent: Double? {
        [primaryUsedPercent, secondaryUsedPercent]
            .compactMap { $0 }
            .map { min(100, max(0, 100 - $0)) }
            .min()
    }
}

struct AccountProfile: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var displayName: String
    var email: String?
    var accountIdentifier: String?
    var planType: String?
    var fingerprint: String
    var note: String?
    var importedAt: Date
    var lastCheckedAt: Date?
    var lastUsedAt: Date?
    var quota: AccountQuota?

    init(
        id: UUID = UUID(),
        displayName: String,
        email: String? = nil,
        accountIdentifier: String? = nil,
        planType: String? = nil,
        fingerprint: String,
        note: String? = nil,
        importedAt: Date = .now,
        lastCheckedAt: Date? = nil,
        lastUsedAt: Date? = nil,
        quota: AccountQuota? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.accountIdentifier = accountIdentifier
        self.planType = planType
        self.fingerprint = fingerprint
        self.note = note
        self.importedAt = importedAt
        self.lastCheckedAt = lastCheckedAt
        self.lastUsedAt = lastUsedAt
        self.quota = quota
    }

    var shortLabel: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let email, !email.isEmpty { return email }
        return String(id.uuidString.prefix(8))
    }
}

struct AccountEnvelope: Codable, Equatable, Sendable {
    var version: Int
    var accounts: [AccountProfile]
    var activeAccountID: UUID?

    init(
        version: Int = 1,
        accounts: [AccountProfile] = [],
        activeAccountID: UUID? = nil
    ) {
        self.version = version
        self.accounts = accounts
        self.activeAccountID = activeAccountID
    }
}

enum AccountError: LocalizedError, Equatable {
    case invalidAuthFile
    case authDataMissing(String)
    case accountNotFound
    case launchFailed(String)
    case legacyImportFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidAuthFile:
            return "auth.json is missing a usable id_token."
        case .authDataMissing(let name):
            return "No saved auth.json for \(name). Re-import the account."
        case .accountNotFound:
            return "That account no longer exists."
        case .launchFailed(let reason):
            return "Could not launch Codex: \(reason)"
        case .legacyImportFailed(let reason):
            return "Could not import the existing Codex Account Switcher data: \(reason)"
        }
    }
}
