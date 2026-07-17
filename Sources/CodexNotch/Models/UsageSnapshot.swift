import Foundation

enum UsageWindowKind: Equatable, Sendable {
    case rolling(hours: Int)
    case daily
    case weekly
    case custom(seconds: Int)
}

struct UsageWindow: Equatable, Identifiable, Sendable {
    let id: String
    let kind: UsageWindowKind
    let usedPercent: Double
    let resetAt: Date?

    init(id: String, kind: UsageWindowKind, usedPercent: Double, resetAt: Date? = nil) {
        self.id = id
        self.kind = kind
        self.usedPercent = UsageWindowClassifier.clampPercent(usedPercent)
        self.resetAt = resetAt
    }

    var remainingPercent: Double {
        max(0, 100 - usedPercent)
    }
}

struct ResetCredit: Equatable, Identifiable, Sendable {
    let id: String
    let title: String?
    let expiresAt: Date?

    init(id: String, title: String? = nil, expiresAt: Date? = nil) {
        self.id = id
        self.title = title
        self.expiresAt = expiresAt
    }
}

struct UsageSnapshot: Equatable, Sendable {
    let windows: [UsageWindow]
    let resetCreditsAvailable: Int?
    let resetCredits: [ResetCredit]
    let fetchedAt: Date

    init(
        windows: [UsageWindow],
        resetCreditsAvailable: Int? = nil,
        resetCredits: [ResetCredit] = [],
        fetchedAt: Date = .now
    ) {
        self.windows = windows
        self.resetCreditsAvailable = resetCreditsAvailable
        self.resetCredits = resetCredits.sorted { lhs, rhs in
            switch (lhs.expiresAt, rhs.expiresAt) {
            case let (lhsDate?, rhsDate?):
                return lhsDate < rhsDate
            case (.some, .none):
                return true
            default:
                return false
            }
        }
        self.fetchedAt = fetchedAt
    }

    var weeklyWindow: UsageWindow? {
        windows.first { window in
            if case .weekly = window.kind { return true }
            return false
        }
    }

    func replacingResetCredits(
        availableCount: Int?,
        credits: [ResetCredit]
    ) -> UsageSnapshot {
        UsageSnapshot(
            windows: windows,
            resetCreditsAvailable: availableCount
                ?? (credits.isEmpty ? resetCreditsAvailable : credits.count),
            resetCredits: credits.isEmpty ? resetCredits : credits,
            fetchedAt: fetchedAt
        )
    }
}

enum WeeklyQuotaLevel: Equatable, Sendable {
    case healthy
    case critical
    case unavailable

    init(weeklyWindow: UsageWindow?) {
        guard let weeklyWindow else {
            self = .unavailable
            return
        }
        self = weeklyWindow.remainingPercent < 20 ? .critical : .healthy
    }
}
