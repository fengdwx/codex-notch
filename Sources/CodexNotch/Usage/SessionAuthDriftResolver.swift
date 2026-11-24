import Foundation

struct RolloutRateLimitObservation: Equatable, Sendable {
    let observedAt: Date
    let windows: [UsageWindow]
    let planType: String?

    var weeklyWindow: UsageWindow? {
        windows.first { window in
            if case .weekly = window.kind { return true }
            return false
        }
    }

    var fiveHourWindow: UsageWindow? {
        windows.first { window in
            if case .rolling(hours: 5) = window.kind { return true }
            return false
        }
    }

    func usageSnapshot() -> UsageSnapshot {
        UsageSnapshot(
            windows: windows,
            resetCreditsAvailable: nil,
            resetCredits: [],
            fetchedAt: observedAt
        )
    }
}

struct SessionAuthDrift: Equatable, Sendable {
    let liveUsage: UsageSnapshot
    let liveAccountID: UUID?
    let liveAccountName: String?
    let diskAccountID: UUID?
    let diskAccountName: String?
    let observedAt: Date

    func bannerText(language: AppLanguage) -> String {
        switch (liveAccountName, diskAccountName) {
        case let (live?, disk?):
            return language.localized(
                chinese: "运行中为 \(live)，凭据已切至 \(disk)（重启 Codex 生效）",
                english: "Running \(live) · auth.json is \(disk) (restart Codex)"
            )
        case let (live?, nil):
            return language.localized(
                chinese: "运行中为 \(live)，磁盘凭据已变更（重启 Codex 生效）",
                english: "Running \(live) · auth.json changed (restart Codex)"
            )
        case let (nil, disk?):
            return language.localized(
                chinese: "运行中账号与凭据 \(disk) 不一致（重启 Codex 生效）",
                english: "Live session differs from \(disk) (restart Codex)"
            )
        case (nil, nil):
            return language.localized(
                chinese: "运行中账号与磁盘凭据不一致（重启 Codex 生效）",
                english: "Live session differs from auth.json (restart Codex)"
            )
        }
    }
}

enum SessionAuthDriftResolver {
    static let resetMatchTolerance: TimeInterval = 120
    static let authModificationGraceInterval: TimeInterval = 1

    struct Resolution: Equatable, Sendable {
        let drift: SessionAuthDrift?
        let needsFreshAPIUsage: Bool
    }

    static func resolve(
        sharedAuthUsage: UsageSnapshot?,
        sharedAuthModifiedAt: Date?,
        diskAccount: AccountProfile?,
        rolloutRateLimit: RolloutRateLimitObservation?,
        accounts: [AccountProfile],
        codexAppLaunchDate: Date? = nil
    ) -> Resolution {
        guard let sharedAuthUsage,
              let sharedAuthModifiedAt,
              let rolloutRateLimit,
              !rolloutRateLimit.windows.isEmpty else {
            return Resolution(drift: nil, needsFreshAPIUsage: false)
        }

        // Only consider rollout events emitted strictly after auth.json was
        // modified; older rollouts may simply belong to a previous account
        // before a normal switch.
        guard rolloutRateLimit.observedAt > sharedAuthModifiedAt.addingTimeInterval(authModificationGraceInterval) else {
            return Resolution(drift: nil, needsFreshAPIUsage: false)
        }

        // If Codex Desktop relaunched after auth.json was updated and no newer
        // rollout event has been emitted since that launch, assume the freshly
        // restarted app loaded the updated auth.json.
        if let codexAppLaunchDate,
           codexAppLaunchDate > sharedAuthModifiedAt,
           rolloutRateLimit.observedAt < codexAppLaunchDate {
            return Resolution(drift: nil, needsFreshAPIUsage: false)
        }

        let weeklyStatus = compareWindow(
            rolloutWindow: rolloutRateLimit.weeklyWindow,
            apiWindow: sharedAuthUsage.weeklyWindow,
            observedAt: rolloutRateLimit.observedAt,
            apiFetchedAt: sharedAuthUsage.fetchedAt
        )
        let fiveHourStatus = compareWindow(
            rolloutWindow: rolloutRateLimit.fiveHourWindow,
            apiWindow: sharedAuthUsage.fiveHourWindow,
            observedAt: rolloutRateLimit.observedAt,
            apiFetchedAt: sharedAuthUsage.fetchedAt
        )

        if weeklyStatus == .diverged || fiveHourStatus == .diverged {
            let matchedLiveAccount = matchAccount(
                for: rolloutRateLimit,
                in: accounts,
                excluding: diskAccount?.id
            )
            return Resolution(
                drift: SessionAuthDrift(
                    liveUsage: rolloutRateLimit.usageSnapshot(),
                    liveAccountID: matchedLiveAccount?.id,
                    liveAccountName: matchedLiveAccount?.shortLabel,
                    diskAccountID: diskAccount?.id,
                    diskAccountName: diskAccount?.shortLabel,
                    observedAt: rolloutRateLimit.observedAt
                ),
                needsFreshAPIUsage: false
            )
        }

        let needsFreshAPI = weeklyStatus == .needsFreshAPI || fiveHourStatus == .needsFreshAPI
        return Resolution(drift: nil, needsFreshAPIUsage: needsFreshAPI)
    }

    private enum WindowComparisonStatus {
        case matched
        case diverged
        case needsFreshAPI
        case inconclusive
    }

    private static func compareWindow(
        rolloutWindow: UsageWindow?,
        apiWindow: UsageWindow?,
        observedAt: Date,
        apiFetchedAt: Date
    ) -> WindowComparisonStatus {
        guard let rolloutWindow,
              let apiWindow,
              let rolloutReset = rolloutWindow.resetAt,
              let apiReset = apiWindow.resetAt else {
            return .inconclusive
        }

        if abs(rolloutReset.timeIntervalSince(apiReset)) <= resetMatchTolerance {
            return .matched
        }

        // Ignore natural window rollovers where the older observation's window
        // expired before the newer observation was recorded.
        if apiReset <= observedAt, rolloutReset > apiReset {
            return .inconclusive
        }
        if rolloutReset <= apiFetchedAt, apiReset > rolloutReset {
            return .inconclusive
        }

        // Unused (0%) windows often carry a rolling placeholder `reset_at`
        // (`now + windowDuration`). Avoid false positives when a single account
        // transitions from 0% to >0% between an older API poll and a newer turn.
        if rolloutWindow.usedPercent == 0, apiWindow.usedPercent == 0 {
            return .inconclusive
        }
        if apiWindow.usedPercent == 0 {
            return observedAt > apiFetchedAt ? .needsFreshAPI : .diverged
        }
        if rolloutWindow.usedPercent == 0 {
            return apiFetchedAt > observedAt ? .inconclusive : .diverged
        }

        return .diverged
    }

    private static func matchAccount(
        for observation: RolloutRateLimitObservation,
        in accounts: [AccountProfile],
        excluding diskAccountID: UUID?
    ) -> AccountProfile? {
        let candidates = accounts.filter { account in
            guard account.id != diskAccountID, let quota = account.quota else { return false }
            if let rolloutWeeklyReset = observation.weeklyWindow?.resetAt,
               let accountWeeklyReset = quota.secondaryResetsAt {
                return abs(rolloutWeeklyReset.timeIntervalSince(accountWeeklyReset)) <= resetMatchTolerance
            }
            if let rolloutFiveHour = observation.fiveHourWindow,
               rolloutFiveHour.usedPercent > 0,
               let rolloutFiveReset = rolloutFiveHour.resetAt,
               let accountFiveUsed = quota.primaryUsedPercent,
               accountFiveUsed > 0,
               let accountFiveReset = quota.primaryResetsAt {
                return abs(rolloutFiveReset.timeIntervalSince(accountFiveReset)) <= resetMatchTolerance
            }
            return false
        }
        return candidates.count == 1 ? candidates[0] : nil
    }
}
