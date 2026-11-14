import Foundation

/// A normalized quota snapshot that is small enough to persist next to an account.
struct AccountQuota: Codable, Equatable, Sendable {
    /// Distinguishes caches written after mapping by semantic `UsageWindowKind`
    /// (`5h` vs `7d`) from pre-fix caches that mapped blindly by JSON slot name.
    static let currentWindowLayoutVersion = 2

    var primaryUsedPercent: Double?
    var primaryResetsAt: Date?
    var secondaryUsedPercent: Double?
    var secondaryResetsAt: Date?
    var planType: String?
    var checkedAt: Date?
    var windowLayoutVersion: Int?

    init(
        primaryUsedPercent: Double? = nil,
        primaryResetsAt: Date? = nil,
        secondaryUsedPercent: Double? = nil,
        secondaryResetsAt: Date? = nil,
        planType: String? = nil,
        checkedAt: Date? = nil,
        windowLayoutVersion: Int? = AccountQuota.currentWindowLayoutVersion
    ) {
        self.primaryUsedPercent = primaryUsedPercent
        self.primaryResetsAt = primaryResetsAt
        self.secondaryUsedPercent = secondaryUsedPercent
        self.secondaryResetsAt = secondaryResetsAt
        self.planType = planType
        self.checkedAt = checkedAt
        self.windowLayoutVersion = windowLayoutVersion
    }

    init(snapshot: UsageSnapshot, planType: String?, checkedAt: Date = .now) {
        // Map by semantic window duration instead of API slot name: single-window
        // plans (e.g. weekly-only 7d) arrive in JSON under `primary_window`
        // with `limit_window_seconds = 604800` and `secondary_window = null`.
        let fiveHour = snapshot.fiveHourWindow
        let weekly = snapshot.weeklyWindow
        self.init(
            primaryUsedPercent: fiveHour?.usedPercent,
            primaryResetsAt: fiveHour?.resetAt,
            secondaryUsedPercent: weekly?.usedPercent,
            secondaryResetsAt: weekly?.resetAt,
            planType: planType,
            checkedAt: checkedAt,
            windowLayoutVersion: Self.currentWindowLayoutVersion
        )
    }

    /// Migrates pre-fix cached records where a single weekly window (> 6h reset
    /// horizon) had been misfiled into `primaryUsedPercent`.
    mutating func normalizeLegacySingleWindowLayout(fallbackCheckedAt: Date?) -> Bool {
        guard windowLayoutVersion == nil,
              secondaryUsedPercent == nil,
              let used = primaryUsedPercent,
              let resetAt = primaryResetsAt else {
            return false
        }
        let referenceDate = checkedAt ?? fallbackCheckedAt ?? .now
        guard resetAt.timeIntervalSince(referenceDate) > 6 * 3_600 else {
            return false
        }
        secondaryUsedPercent = used
        secondaryResetsAt = resetAt
        primaryUsedPercent = nil
        primaryResetsAt = nil
        return true
    }

    /// Thresholds and freshness windows used by the notch account picker.
    static let availableThresholdPercent: Double = 10
    static let lowQuotaCueThresholdPercent: Double = 20
    static let staleQuotaAgeInterval: TimeInterval = 3_600

    var primaryRemainingPercent: Double? {
        primaryUsedPercent.map { UsageWindowClassifier.clampPercent(100 - $0) }
    }

    var secondaryRemainingPercent: Double? {
        secondaryUsedPercent.map { UsageWindowClassifier.clampPercent(100 - $0) }
    }

    /// Lowest remaining percentage across the known windows, used for the
    /// compact account badge.
    var lowestRemainingPercent: Double? {
        [primaryUsedPercent, secondaryUsedPercent]
            .compactMap { $0 }
            .map { UsageWindowClassifier.clampPercent(100 - $0) }
            .min()
    }

    var isAvailableForPool: Bool {
        guard let lowestRemainingPercent else { return true }
        return lowestRemainingPercent > Self.availableThresholdPercent
    }

    func previewUsageSnapshot(
        preservingResetCreditsFrom activeUsage: UsageSnapshot?
    ) -> UsageSnapshot {
        var windows: [UsageWindow] = []
        if let primaryUsedPercent {
            windows.append(
                UsageWindow(
                    id: "primary",
                    kind: .rolling(hours: 5),
                    usedPercent: primaryUsedPercent,
                    resetAt: primaryResetsAt
                )
            )
        }
        if let secondaryUsedPercent {
            windows.append(
                UsageWindow(
                    id: "secondary",
                    kind: .weekly,
                    usedPercent: secondaryUsedPercent,
                    resetAt: secondaryResetsAt
                )
            )
        }
        return UsageSnapshot(
            windows: windows,
            resetCreditsAvailable: activeUsage?.resetCreditsAvailable,
            resetCredits: activeUsage?.resetCredits ?? [],
            fetchedAt: checkedAt ?? .now
        )
    }

    private static func makeFormatter(_ format: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }

    private static let currentDateTimeFormatter = makeFormatter("MM-dd HH:mm", timeZone: .current)
    private static let currentTimeOnlyFormatter = makeFormatter("HH:mm", timeZone: .current)
    private static let currentMonthDayFormatter = makeFormatter("MM-dd", timeZone: .current)

    /// Summarizes reset timing for the compact drawer row. Full `100%` 5h
    /// windows hold a rolling placeholder reset timestamp, so 5h reset timing is
    /// revealed side-by-side only once 5h quota actually drops below 100%.
    func conciseResetText(
        language: AppLanguage,
        timeZone: TimeZone = .current
    ) -> String {
        let dateTimeFormatter = timeZone == .current
            ? Self.currentDateTimeFormatter
            : Self.makeFormatter("MM-dd HH:mm", timeZone: timeZone)
        let timeOnlyFormatter = timeZone == .current
            ? Self.currentTimeOnlyFormatter
            : Self.makeFormatter("HH:mm", timeZone: timeZone)
        let monthDayFormatter = timeZone == .current
            ? Self.currentMonthDayFormatter
            : Self.makeFormatter("MM-dd", timeZone: timeZone)

        let hasConsumedFiveHour = primaryRemainingPercent.map { Int($0.rounded()) < 100 } ?? false
        if hasConsumedFiveHour, let primaryResetsAt {
            let fiveHourText = timeOnlyFormatter.string(from: primaryResetsAt)
            if let secondaryResetsAt {
                let weeklyDate = monthDayFormatter.string(from: secondaryResetsAt)
                return "5h \(fiveHourText) · 7d \(weeklyDate)"
            }
            return language.localized(
                chinese: "5h \(fiveHourText) 重置",
                english: "Resets 5h \(fiveHourText)"
            )
        }

        if let secondaryResetsAt {
            let formatted = dateTimeFormatter.string(from: secondaryResetsAt)
            return language.localized(chinese: "\(formatted) 重置", english: "Resets \(formatted)")
        }
        if let primaryResetsAt {
            let formatted = dateTimeFormatter.string(from: primaryResetsAt)
            return language.localized(chinese: "5h \(formatted) 重置", english: "5h \(formatted)")
        }
        return "—"
    }
}

enum AccountAvailabilityStatus: String, Codable, Equatable, Sendable {
    case available
    case reauthRequired
    case unavailable
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
    var availabilityStatus: AccountAvailabilityStatus?

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
        quota: AccountQuota? = nil,
        availabilityStatus: AccountAvailabilityStatus? = nil
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
        self.availabilityStatus = availabilityStatus
    }

    var shortLabel: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let email, !email.isEmpty { return email }
        return String(id.uuidString.prefix(8))
    }

    var monogramCharacter: String {
        guard let first = shortLabel.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return "A"
        }
        return String(first).uppercased()
    }

    /// Deterministic index in `0..<6` across app launches so each account keeps
    /// a consistent avatar tint instead of hashing with per-process Swift seeds.
    var monogramPaletteIndex: Int {
        let seed = (accountIdentifier ?? email ?? fingerprint)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % 6)
    }

    var resolvedAvailabilityStatus: AccountAvailabilityStatus {
        availabilityStatus ?? .available
    }

    var isUsableAccount: Bool {
        resolvedAvailabilityStatus == .available
    }

    var isAvailableForPool: Bool {
        isUsableAccount && (quota?.isAvailableForPool ?? true)
    }

    func isStaleQuota(
        at now: Date,
        failedIDs: Set<UUID> = []
    ) -> Bool {
        guard isUsableAccount else { return false }
        if failedIDs.contains(id) { return true }
        let checkedAt = quota?.checkedAt ?? lastCheckedAt
        guard let checkedAt else { return quota == nil }
        return now.timeIntervalSince(checkedAt) > AccountQuota.staleQuotaAgeInterval
    }

    var subtitleText: String {
        let normalizedTitle = shortLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        var parts: [String] = []
        var seen: Set<String> = normalizedTitle.isEmpty ? [] : [normalizedTitle]

        for candidate in [note, email] {
            guard let raw = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else {
                continue
            }
            let normalized = raw.lowercased()
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            parts.append(raw)
        }

        return parts.prefix(2).joined(separator: " · ")
    }

    static func conciseRelativeAge(
        since date: Date,
        now: Date,
        language: AppLanguage
    ) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 {
            return language.localized(chinese: "刚刚", english: "Just now")
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return language.localized(chinese: "\(minutes)m前", english: "\(minutes)m ago")
        }
        let hours = minutes / 60
        if hours < 24 {
            return language.localized(chinese: "\(hours)h前", english: "\(hours)h ago")
        }
        let days = hours / 24
        return language.localized(chinese: "\(days)d前", english: "\(days)d ago")
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
