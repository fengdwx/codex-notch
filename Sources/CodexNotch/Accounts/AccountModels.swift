import Foundation

enum AccountResetCountdownState: Equatable, Sendable {
    case counting(String)
    /// 5h window is still at 100% so its rolling timer has not started yet.
    case idle
    case expired
}

enum AccountResetCountdownTone: Equatable, Sendable {
    /// Reset timestamp has passed; window is ready to refresh/use.
    case ready
    /// Quota is exhausted or low (`<= 20%`); highlights the recovery countdown.
    case recovering
    /// Standard calm secondary countdown tone shared across healthy windows.
    case normal
    /// Quieter metadata tone for an unstarted 100% 5h window.
    case muted
}

struct AccountResetWindowCountdown: Equatable, Sendable {
    let windowLabel: String?
    let state: AccountResetCountdownState
    let tone: AccountResetCountdownTone
}

enum AccountResetPresentation: Equatable, Sendable {
    case dual(fiveHour: AccountResetWindowCountdown, weekly: AccountResetWindowCountdown)
    case single(AccountResetWindowCountdown)
    case unavailable
}

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

    enum CodingKeys: String, CodingKey {
        case primaryUsedPercent
        case primaryResetsAt
        case secondaryUsedPercent
        case secondaryResetsAt
        case planType
        case checkedAt
        case windowLayoutVersion
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case primary
        case secondary
        case fetchedAt
    }

    private struct LegacyWindow: Decodable {
        let durationMinutes: Int?
        let usedPercent: Double?
        let resetsAt: Date?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)

        var primaryUsed = try container.decodeIfPresent(Double.self, forKey: .primaryUsedPercent)
        var primaryReset = try container.decodeIfPresent(Date.self, forKey: .primaryResetsAt)
        var secondaryUsed = try container.decodeIfPresent(Double.self, forKey: .secondaryUsedPercent)
        var secondaryReset = try container.decodeIfPresent(Date.self, forKey: .secondaryResetsAt)
        let decodedPlanType = try container.decodeIfPresent(String.self, forKey: .planType)
        let decodedCheckedAt = try container.decodeIfPresent(Date.self, forKey: .checkedAt)
            ?? (try legacyContainer.decodeIfPresent(Date.self, forKey: .fetchedAt))
        var layoutVersion = try container.decodeIfPresent(Int.self, forKey: .windowLayoutVersion)

        if primaryUsed == nil && secondaryUsed == nil {
            let legacyPrimary = try legacyContainer.decodeIfPresent(LegacyWindow.self, forKey: .primary)
            let legacySecondary = try legacyContainer.decodeIfPresent(LegacyWindow.self, forKey: .secondary)

            var hasLegacyDuration = false
            for (isSecondarySlot, window) in [(false, legacyPrimary), (true, legacySecondary)] {
                guard let window, let used = window.usedPercent else { continue }
                if let durationMinutes = window.durationMinutes {
                    hasLegacyDuration = true
                    if durationMinutes > 360 {
                        secondaryUsed = used
                        secondaryReset = window.resetsAt
                    } else {
                        primaryUsed = used
                        primaryReset = window.resetsAt
                    }
                } else if isSecondarySlot {
                    secondaryUsed = used
                    secondaryReset = window.resetsAt
                } else {
                    primaryUsed = used
                    primaryReset = window.resetsAt
                }
            }
            if hasLegacyDuration && layoutVersion == nil {
                layoutVersion = Self.currentWindowLayoutVersion
            }
        }

        self.primaryUsedPercent = primaryUsed
        self.primaryResetsAt = primaryReset
        self.secondaryUsedPercent = secondaryUsed
        self.secondaryResetsAt = secondaryReset
        self.planType = decodedPlanType
        self.checkedAt = decodedCheckedAt
        self.windowLayoutVersion = layoutVersion
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(primaryUsedPercent, forKey: .primaryUsedPercent)
        try container.encodeIfPresent(primaryResetsAt, forKey: .primaryResetsAt)
        try container.encodeIfPresent(secondaryUsedPercent, forKey: .secondaryUsedPercent)
        try container.encodeIfPresent(secondaryResetsAt, forKey: .secondaryResetsAt)
        try container.encodeIfPresent(planType, forKey: .planType)
        try container.encodeIfPresent(checkedAt, forKey: .checkedAt)
        try container.encodeIfPresent(windowLayoutVersion, forKey: .windowLayoutVersion)
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

    private static func conciseCountdown(to resetAt: Date, now: Date) -> String? {
        let totalSeconds = Int(resetAt.timeIntervalSince(now).rounded(.down))
        guard totalSeconds > 0 else { return nil }

        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if days > 0 {
            return String(format: "%dd %02d:%02d:%02d", days, hours, minutes, seconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private static func countdownSegment(
        windowLabel: String,
        resetAt: Date,
        now: Date,
        remainingPercent: Double?
    ) -> AccountResetWindowCountdown {
        if let countdown = conciseCountdown(to: resetAt, now: now) {
            let isLowOrExhausted = remainingPercent.map {
                $0 <= Self.lowQuotaCueThresholdPercent
            } ?? false
            return AccountResetWindowCountdown(
                windowLabel: windowLabel,
                state: .counting(countdown),
                tone: isLowOrExhausted ? .recovering : .normal
            )
        }
        return AccountResetWindowCountdown(
            windowLabel: windowLabel,
            state: .expired,
            tone: .ready
        )
    }

    /// Structured countdown presentation used by both the styled drawer view
    /// and plain-text summaries. Full `100%` 5h windows hold a rolling
    /// placeholder reset timestamp, so 5h shows an idle cue until quota drops
    /// below 100%.
    func resetPresentation(now: Date = .now) -> AccountResetPresentation {
        let hasFiveHourWindow = primaryRemainingPercent != nil
        let hasConsumedFiveHour = primaryRemainingPercent.map { Int($0.rounded()) < 100 } ?? false

        if hasFiveHourWindow {
            let fiveHour: AccountResetWindowCountdown? = if hasConsumedFiveHour, let primaryResetsAt {
                Self.countdownSegment(
                    windowLabel: "5h",
                    resetAt: primaryResetsAt,
                    now: now,
                    remainingPercent: primaryRemainingPercent
                )
            } else if !hasConsumedFiveHour {
                AccountResetWindowCountdown(
                    windowLabel: "5h",
                    state: .idle,
                    tone: .muted
                )
            } else {
                nil
            }

            if let fiveHour {
                if let secondaryResetsAt {
                    let weekly = Self.countdownSegment(
                        windowLabel: "7d",
                        resetAt: secondaryResetsAt,
                        now: now,
                        remainingPercent: secondaryRemainingPercent
                    )
                    return .dual(fiveHour: fiveHour, weekly: weekly)
                }
                return .single(fiveHour)
            }
        }

        if let secondaryResetsAt {
            return .single(
                Self.countdownSegment(
                    windowLabel: "7d",
                    resetAt: secondaryResetsAt,
                    now: now,
                    remainingPercent: secondaryRemainingPercent
                )
            )
        }

        if let primaryResetsAt {
            return .single(
                Self.countdownSegment(
                    windowLabel: "5h",
                    resetAt: primaryResetsAt,
                    now: now,
                    remainingPercent: primaryRemainingPercent
                )
            )
        }

        return .unavailable
    }

    /// Summarizes reset countdown for the compact drawer row.
    func conciseResetText(
        now: Date = .now,
        language: AppLanguage
    ) -> String {
        switch resetPresentation(now: now) {
        case let .dual(fiveHour, weekly):
            let fiveHourText = Self.plainValue(for: fiveHour.state, language: language)
            let weeklyText = Self.plainValue(for: weekly.state, language: language)
            return "\(fiveHour.windowLabel ?? "5h") \(fiveHourText) · \(weekly.windowLabel ?? "7d") \(weeklyText)"

        case let .single(segment):
            let value = Self.plainValue(for: segment.state, language: language)
            if let prefix = segment.windowLabel {
                return "\(prefix) \(value)"
            }
            return value

        case .unavailable:
            return "—"
        }
    }

    private static func plainValue(
        for state: AccountResetCountdownState,
        language: AppLanguage
    ) -> String {
        switch state {
        case let .counting(countdown):
            return countdown
        case .idle:
            return language.localized(chinese: "待开始", english: "Ready")
        case .expired:
            return language.localized(chinese: "已重置", english: "Reset")
        }
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
    case externalSessionsRunning(Int)

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
        case .externalSessionsRunning(let count):
            return "\(count) Codex CLI or IDE session(s) are still using auth.json."
        }
    }
}
