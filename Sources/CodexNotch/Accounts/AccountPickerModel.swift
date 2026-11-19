import Foundation

enum AccountPickerFilter: String, CaseIterable, Codable, Sendable {
    case availableFirst
    case recentUsed
    case all

    static let storageKey = "codexNotch.accountPickerFilter"
    static let defaultFilter: AccountPickerFilter = .availableFirst

    static func read(from userDefaults: UserDefaults = .standard) -> AccountPickerFilter {
        guard let raw = userDefaults.string(forKey: storageKey),
              let parsed = AccountPickerFilter(rawValue: raw) else {
            return defaultFilter
        }
        return parsed
    }

    func save(to userDefaults: UserDefaults = .standard) {
        userDefaults.set(rawValue, forKey: Self.storageKey)
    }

    func title(
        availableCount: Int,
        totalCount: Int,
        language: AppLanguage
    ) -> String {
        switch self {
        case .availableFirst:
            return language.localized(
                chinese: "余量优先 (\(availableCount))",
                english: "Available (\(availableCount))"
            )
        case .recentUsed:
            return language.localized(
                chinese: "最近使用",
                english: "Recent"
            )
        case .all:
            return language.localized(
                chinese: "全部 (\(totalCount))",
                english: "All (\(totalCount))"
            )
        }
    }
}

struct AccountPickerSnapshot: Equatable, Sendable {
    let totalCount: Int
    let availableCount: Int
    let unusableCount: Int
    let displayedAccounts: [AccountProfile]
    let activeAccount: AccountProfile?
    let bestStandbyAccount: AccountProfile?
    let isActiveLowQuota: Bool
    let latestQuotaCheckAt: Date?

    var bestStandbyRemainingPercent: Double? {
        bestStandbyAccount?.quota?.lowestRemainingPercent
    }

    var shouldShowLowQuotaCue: Bool {
        guard let best = bestStandbyRemainingPercent else { return false }
        if activeAccount?.isUsableAccount == false {
            return best > AccountQuota.availableThresholdPercent
        }
        return isActiveLowQuota && best > AccountQuota.lowQuotaCueThresholdPercent
    }
}

enum AccountPickerLogic {
    /// Minimum account count where the three mouse-only filter pills appear.
    static let filterThresholdCount = 5

    static func snapshot(
        accounts: [AccountProfile],
        activeAccountID: UUID?,
        filter: AccountPickerFilter
    ) -> AccountPickerSnapshot {
        let activeAccount = activeAccountID.flatMap { id in
            accounts.first { $0.id == id }
        }
        let availableCount = accounts.filter(\.isAvailableForPool).count
        let unusableCount = accounts.filter { !$0.isUsableAccount }.count
        let originalIndex = Dictionary(
            uniqueKeysWithValues: accounts.enumerated().map { ($0.element.id, $0.offset) }
        )

        let activeLowest = activeAccount?.quota?.lowestRemainingPercent
        let isActiveLowQuota = activeLowest.map { $0 <= AccountQuota.lowQuotaCueThresholdPercent } ?? false

        let bestStandbyAccount = accounts
            .filter { $0.id != activeAccountID && $0.isUsableAccount }
            .max { lhs, rhs in
                let leftScore = lhs.quota?.lowestRemainingPercent ?? -1
                let rightScore = rhs.quota?.lowestRemainingPercent ?? -1
                if leftScore != rightScore {
                    return leftScore < rightScore
                }
                return (originalIndex[lhs.id] ?? 0) > (originalIndex[rhs.id] ?? 0)
            }

        let latestQuotaCheckAt = accounts
            .compactMap { $0.quota?.checkedAt ?? $0.lastCheckedAt }
            .max()

        let displayedAccounts: [AccountProfile]
        if accounts.count < filterThresholdCount {
            displayedAccounts = sortActiveFirstStable(accounts, activeAccountID: activeAccountID)
        } else {
            switch filter {
            case .availableFirst:
                displayedAccounts = accounts
                    .filter(\.isAvailableForPool)
                    .sorted { lhs, rhs in
                        let leftRemaining = lhs.quota?.lowestRemainingPercent
                        let rightRemaining = rhs.quota?.lowestRemainingPercent
                        switch (leftRemaining, rightRemaining) {
                        case let (left?, right?) where left != right:
                            return left > right
                        case (.some, .none):
                            return true
                        case (.none, .some):
                            return false
                        default:
                            if lhs.id == activeAccountID, rhs.id != activeAccountID { return true }
                            if rhs.id == activeAccountID, lhs.id != activeAccountID { return false }
                            return (originalIndex[lhs.id] ?? 0) < (originalIndex[rhs.id] ?? 0)
                        }
                    }
            case .recentUsed:
                displayedAccounts = accounts.sorted { lhs, rhs in
                    let leftUsed = lhs.lastUsedAt ?? .distantPast
                    let rightUsed = rhs.lastUsedAt ?? .distantPast
                    if leftUsed != rightUsed {
                        return leftUsed > rightUsed
                    }
                    if lhs.id == activeAccountID, rhs.id != activeAccountID { return true }
                    if rhs.id == activeAccountID, lhs.id != activeAccountID { return false }
                    return (originalIndex[lhs.id] ?? 0) < (originalIndex[rhs.id] ?? 0)
                }
            case .all:
                displayedAccounts = sortActiveFirstStable(accounts, activeAccountID: activeAccountID)
            }
        }

        return AccountPickerSnapshot(
            totalCount: accounts.count,
            availableCount: availableCount,
            unusableCount: unusableCount,
            displayedAccounts: displayedAccounts,
            activeAccount: activeAccount,
            bestStandbyAccount: bestStandbyAccount,
            isActiveLowQuota: isActiveLowQuota,
            latestQuotaCheckAt: latestQuotaCheckAt
        )
    }

    private static func sortActiveFirstStable(
        _ accounts: [AccountProfile],
        activeAccountID: UUID?
    ) -> [AccountProfile] {
        guard let activeAccountID,
              let activeIndex = accounts.firstIndex(where: { $0.id == activeAccountID }) else {
            return accounts
        }
        var reordered = [accounts[activeIndex]]
        for (index, account) in accounts.enumerated() where index != activeIndex {
            reordered.append(account)
        }
        return reordered
    }
}

struct AccountPreviewState: Equatable, Sendable {
    let previewAccount: AccountProfile?
    let displayedUsage: UsageSnapshot?
    let isLockedConfirmation: Bool
    let locksFiveHourRow: Bool
    let inlineFiveHourPercent: Double?

    var isPreviewingStandby: Bool {
        previewAccount != nil
    }
}

enum AccountPreviewResolver {
    static func accountSupportsFiveHourWindow(_ account: AccountProfile) -> Bool {
        if account.quota?.primaryRemainingPercent != nil {
            return true
        }
        let normalizedPlan = (account.planType ?? account.quota?.planType)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let normalizedPlan, !normalizedPlan.isEmpty else {
            return false
        }
        return normalizedPlan != "pro" && normalizedPlan != "free"
    }

    static func anyAccountHasFiveHourWindow(_ accounts: [AccountProfile]) -> Bool {
        accounts.contains(where: accountSupportsFiveHourWindow)
    }

    static func resolve(
        activeUsage: UsageSnapshot?,
        accounts: [AccountProfile],
        activeAccountID: UUID?,
        hoveredAccountID: UUID?,
        selectedAccountIDForSwitch: UUID?,
        isDrawerExpanded: Bool
    ) -> AccountPreviewState {
        let activeHasFiveHour = activeUsage?.fiveHourWindow != nil
        guard isDrawerExpanded else {
            return AccountPreviewState(
                previewAccount: nil,
                displayedUsage: activeUsage,
                isLockedConfirmation: false,
                locksFiveHourRow: activeHasFiveHour,
                inlineFiveHourPercent: nil
            )
        }

        let targetID = hoveredAccountID ?? selectedAccountIDForSwitch
        guard let targetID,
              targetID != activeAccountID,
              let previewAccount = accounts.first(where: { $0.id == targetID }) else {
            return AccountPreviewState(
                previewAccount: nil,
                displayedUsage: activeUsage,
                isLockedConfirmation: false,
                locksFiveHourRow: activeHasFiveHour,
                inlineFiveHourPercent: nil
            )
        }

        let previewSnapshot: UsageSnapshot
        if let quota = previewAccount.quota {
            previewSnapshot = quota.previewUsageSnapshot(preservingResetCreditsFrom: activeUsage)
        } else {
            previewSnapshot = UsageSnapshot(
                windows: [],
                resetCreditsAvailable: activeUsage?.resetCreditsAvailable,
                resetCredits: activeUsage?.resetCredits ?? [],
                fetchedAt: previewAccount.lastCheckedAt ?? .now
            )
        }

        let isLocked = hoveredAccountID == nil && selectedAccountIDForSwitch == targetID
        let inlineFiveHour = !activeHasFiveHour
            ? previewSnapshot.fiveHourWindow?.remainingPercent
            : nil

        return AccountPreviewState(
            previewAccount: previewAccount,
            displayedUsage: previewSnapshot,
            isLockedConfirmation: isLocked,
            locksFiveHourRow: activeHasFiveHour,
            inlineFiveHourPercent: inlineFiveHour
        )
    }
}
