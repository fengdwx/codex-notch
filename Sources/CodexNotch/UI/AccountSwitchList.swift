import SwiftUI

/// Multi-account switcher embedded below `QuotaWindowsProgressView` inside `ExpandedNotchView`.
/// Default collapsed state renders only the 36pt Anchor Bar (plus an optional status banner);
/// opening the drawer reveals a pure-mouse filterable vertical list with hover-live top quota preview.
struct AccountSwitchList: View {
    @ObservedObject var service: AccountsService
    let language: AppLanguage
    let now: Date
    let isTaskRunning: Bool
    let isDrawerExpanded: Bool
    let pickerFilter: AccountPickerFilter
    let selectedAccountID: UUID?
    @Binding var hoveredAccountID: UUID?
    let onDrawerExpandedChanged: (Bool) -> Void
    let onPickerFilterChanged: (AccountPickerFilter) -> Void
    let onSelectedAccountChanged: (UUID?) -> Void
    let onConfirmSwitch: (UUID) -> Void
    let onRefreshAll: () -> Void
    let onDismissError: () -> Void

    @Environment(\.notchMotionEnabled) private var motionEnabled

    private var pickerSnapshot: AccountPickerSnapshot {
        AccountPickerLogic.snapshot(
            accounts: service.accounts,
            activeAccountID: service.activeAccountID,
            filter: pickerFilter
        )
    }

    private var showsStatusBanner: Bool {
        switch service.switchPhase {
        case .idle:
            return false
        case .switching, .failed:
            return true
        }
    }

    private var showsAnchorBar: Bool {
        service.accounts.count > 1
    }

    var body: some View {
        if showsAnchorBar || showsStatusBanner {
            VStack(alignment: .leading, spacing: 0) {
                sectionTopSeparator

                if showsAnchorBar {
                    AccountAnchorBar(
                        snapshot: pickerSnapshot,
                        switchPhase: service.switchPhase,
                        recentSwitchCompletedAt: service.recentSwitchCompletedAt,
                        isDrawerExpanded: isDrawerExpanded,
                        now: now,
                        language: language,
                        onToggleDrawer: {
                            guard !service.switchPhase.isSwitching else { return }
                            onDrawerExpandedChanged(!isDrawerExpanded)
                        }
                    )
                }

                if showsStatusBanner {
                    AccountStatusBannerView(
                        switchPhase: service.switchPhase,
                        accountNameLookup: { id in service.account(withID: id)?.shortLabel },
                        language: language,
                        onRetry: onConfirmSwitch,
                        onDismiss: onDismissError
                    )
                    .padding(.top, showsAnchorBar ? NotchExpandedLayout.accountStatusBannerTopSpacing : 0)
                }

                if showsAnchorBar, isDrawerExpanded {
                    drawerContainer
                        .padding(.top, NotchExpandedLayout.accountDrawerTopSpacing)
                        .transition(
                            motionEnabled
                                ? .opacity.combined(with: .move(edge: .top))
                                : .identity
                        )
                }
            }
            .animation(motionEnabled ? .easeInOut(duration: 0.18) : nil, value: isDrawerExpanded)
            .animation(motionEnabled ? .easeInOut(duration: 0.16) : nil, value: selectedAccountID)
            .animation(motionEnabled ? .easeInOut(duration: 0.16) : nil, value: service.switchPhase)
        }
    }

    private var sectionTopSeparator: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Rectangle()
                .fill(NotchPalette.border.opacity(0.45))
                .frame(height: 0.5)
            Spacer(minLength: 0)
        }
        .frame(height: NotchExpandedLayout.accountSectionTopSpacing)
    }

    private var drawerContainer: some View {
        let snapshot = pickerSnapshot
        let listHeight = drawerListHeight(for: snapshot)

        return VStack(alignment: .leading, spacing: 0) {
            AccountDrawerToolbar(
                snapshot: snapshot,
                filter: pickerFilter,
                isRefreshing: service.isRefreshingQuotas,
                isSwitching: service.switchPhase.isSwitching,
                now: now,
                language: language,
                onSelectFilter: onPickerFilterChanged,
                onRefreshAll: onRefreshAll
            )
            .padding(.bottom, NotchExpandedLayout.accountDrawerToolbarBottomSpacing)

            if snapshot.displayedAccounts.isEmpty {
                AccountEmptyFilterGuard(
                    totalCount: snapshot.totalCount,
                    unusableCount: snapshot.unusableCount,
                    language: language,
                    onShowAll: { onPickerFilterChanged(.all) }
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView(
                        .vertical,
                        showsIndicators: snapshot.displayedAccounts.count > NotchExpandedLayout.maxVisibleAccountCards
                    ) {
                        VStack(spacing: NotchExpandedLayout.accountCardSpacing) {
                            ForEach(snapshot.displayedAccounts) { account in
                                AccountDrawerCard(
                                    account: account,
                                    isActive: account.id == service.activeAccountID,
                                    isSelected: account.id == selectedAccountID,
                                    isHovered: account.id == hoveredAccountID,
                                    isStale: account.isStaleQuota(
                                        at: now,
                                        failedIDs: service.failedQuotaAccountIDs
                                    ),
                                    isSwitching: service.switchPhase.isSwitching,
                                    isTaskRunning: isTaskRunning,
                                    now: now,
                                    language: language,
                                    onHoverChanged: { hovering in
                                        if hovering {
                                            hoveredAccountID = account.id
                                        } else if hoveredAccountID == account.id {
                                            hoveredAccountID = nil
                                        }
                                    },
                                    onTapRow: {
                                        guard !service.switchPhase.isSwitching else { return }
                                        guard account.id != service.activeAccountID else {
                                            if selectedAccountID != nil {
                                                onSelectedAccountChanged(nil)
                                            }
                                            return
                                        }
                                        onSelectedAccountChanged(
                                            selectedAccountID == account.id ? nil : account.id
                                        )
                                    },
                                    onCancelConfirm: {
                                        onSelectedAccountChanged(nil)
                                    },
                                    onConfirmSwitch: {
                                        onConfirmSwitch(account.id)
                                    }
                                )
                                .id(account.id)
                            }
                        }
                        .onHover { inside in
                            if !inside {
                                hoveredAccountID = nil
                            }
                        }
                    }
                    .frame(height: listHeight)
                    .onChange(of: selectedAccountID) { _, newValue in
                        guard let newValue else { return }
                        if motionEnabled {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        } else {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, NotchExpandedLayout.accountDrawerVerticalPadding / 2)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NotchPalette.border.opacity(0.6), lineWidth: 0.5)
        }
    }

    private func drawerListHeight(for snapshot: AccountPickerSnapshot) -> CGFloat {
        let count = snapshot.displayedAccounts.count
        guard count > 0 else { return NotchExpandedLayout.accountEmptyGuardHeight }
        let visibleCards = min(count, NotchExpandedLayout.maxVisibleAccountCards)
        let isConfirmingVisible = selectedAccountID != nil
            && snapshot.displayedAccounts.contains(where: {
                $0.id == selectedAccountID && $0.id != service.activeAccountID
            })
        return CGFloat(visibleCards) * NotchExpandedLayout.accountCardHeight
            + CGFloat(max(0, visibleCards - 1)) * NotchExpandedLayout.accountCardSpacing
            + (isConfirmingVisible ? NotchExpandedLayout.accountConfirmFooterHeight : 0)
    }
}

private struct AccountAnchorBar: View {
    let snapshot: AccountPickerSnapshot
    let switchPhase: AccountSwitchPhase
    let recentSwitchCompletedAt: Date?
    let isDrawerExpanded: Bool
    let now: Date
    let language: AppLanguage
    let onToggleDrawer: () -> Void

    private var showsSwitchedFeedback: Bool {
        guard !isDrawerExpanded,
              !switchPhase.isSwitching,
              let recentSwitchCompletedAt else {
            return false
        }
        return now.timeIntervalSince(recentSwitchCompletedAt) < 1.8
    }

    private var activeLabel: String {
        snapshot.activeAccount?.shortLabel
            ?? language.localized(chinese: "选择 Codex 账号", english: "Choose account")
    }

    var body: some View {
        Button(action: onToggleDrawer) {
            HStack(spacing: 8) {
                if let active = snapshot.activeAccount {
                    AccountMonogramAvatar(account: active, size: 20, cornerRadius: 6)
                } else {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(NotchPalette.row)
                        .frame(width: 20, height: 20)
                        .overlay {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(NotchPalette.secondaryText)
                        }
                }

                Text(activeLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NotchPalette.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let plan = snapshot.activeAccount?.planType, !plan.isEmpty {
                    AccountPlanPill(planType: plan)
                }

                if let activeStatus = snapshot.activeAccount?.resolvedAvailabilityStatus,
                   activeStatus != .available {
                    AccountAvailabilityBadge(status: activeStatus, language: language)
                }

                Spacer(minLength: 4)

                trailingPill
                    .fixedSize(horizontal: true, vertical: false)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(NotchPalette.secondaryText)
                    .rotationEffect(.degrees(isDrawerExpanded ? 180 : 0))
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: NotchExpandedLayout.accountAnchorBarHeight)
            .background(
                NotchPalette.row.opacity(isDrawerExpanded ? 0.65 : 0.45),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isDrawerExpanded
                            ? NotchPalette.accent.opacity(0.45)
                            : NotchPalette.border.opacity(0.7),
                        lineWidth: 0.6
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle())
        .disabled(switchPhase.isSwitching)
        .accessibilityLabel(
            language.localized(
                chinese: "当前账号：\(activeLabel)，\(snapshot.availableCount) 个可用",
                english: "Active account \(activeLabel), \(snapshot.availableCount) available"
            )
        )
        .accessibilityHint(
            language.localized(
                chinese: isDrawerExpanded ? "收起账号列表" : "展开切换多账号列表",
                english: isDrawerExpanded ? "Collapse account list" : "Expand account switcher"
            )
        )
    }

    @ViewBuilder
    private var trailingPill: some View {
        if switchPhase.isSwitching {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.7)
                Text(language.localized(chinese: "切换中…", english: "Switching…"))
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(NotchPalette.accent)
            .padding(.horizontal, 7)
            .frame(height: 19)
            .background(NotchPalette.accent.opacity(0.15), in: Capsule())
        } else if showsSwitchedFeedback {
            HStack(spacing: 3) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                Text(language.localized(chinese: "已切换", english: "Switched"))
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(NotchPalette.success)
            .padding(.horizontal, 7)
            .frame(height: 19)
            .background(NotchPalette.success.opacity(0.16), in: Capsule())
        } else {
            let isAmber = snapshot.shouldShowLowQuotaCue
            let isCriticalEmpty = !isAmber && snapshot.availableCount == 0
            let dotColor: Color = isAmber
                ? NotchPalette.warning
                : (snapshot.availableCount > 0 ? NotchPalette.success : NotchPalette.danger)
            let pillTextColor: Color = if isAmber {
                NotchPalette.warning
            } else if isCriticalEmpty {
                NotchPalette.danger
            } else {
                NotchPalette.secondaryText
            }
            let pillBackground: Color = if isAmber {
                NotchPalette.warning.opacity(0.15)
            } else if isCriticalEmpty {
                NotchPalette.danger.opacity(0.14)
            } else {
                Color.white.opacity(0.06)
            }
            let pillText: String = {
                if isAmber, let best = snapshot.bestStandbyRemainingPercent {
                    return language.localized(
                        chinese: "\(snapshot.availableCount)/\(snapshot.totalCount) 可用 · 最高 \(Int(best.rounded()))%",
                        english: "\(snapshot.availableCount)/\(snapshot.totalCount) · Best \(Int(best.rounded()))%"
                    )
                }
                return language.localized(
                    chinese: "\(snapshot.availableCount)/\(snapshot.totalCount) 可用",
                    english: "\(snapshot.availableCount)/\(snapshot.totalCount) avail"
                )
            }()

            HStack(spacing: 4) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 5, height: 5)
                Text(pillText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(pillTextColor)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .frame(height: 19)
            .background(pillBackground, in: Capsule())
            .overlay {
                if isAmber {
                    Capsule().stroke(NotchPalette.warning.opacity(0.32), lineWidth: 0.5)
                } else if isCriticalEmpty {
                    Capsule().stroke(NotchPalette.danger.opacity(0.30), lineWidth: 0.5)
                }
            }
        }
    }
}

private struct AccountStatusBannerView: View {
    let switchPhase: AccountSwitchPhase
    let accountNameLookup: (UUID) -> String?
    let language: AppLanguage
    let onRetry: (UUID) -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            switch switchPhase {
            case .idle:
                EmptyView()
            case let .switching(targetID):
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.72)
                Text(
                    language.localized(
                        chinese: "正在切换至 \(accountNameLookup(targetID) ?? "")（重启 Codex 中）…",
                        english: "Switching to \(accountNameLookup(targetID) ?? "account") (relaunching Codex)…"
                    )
                )
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(NotchPalette.accent)
                .lineLimit(1)
                Spacer(minLength: 0)
            case let .failed(targetID, message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(NotchPalette.danger)
                Text(message)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(NotchPalette.danger)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if let targetID {
                    Button {
                        onRetry(targetID)
                    } label: {
                        Text(language.localized(chinese: "重试", english: "Retry"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(NotchPalette.primaryText)
                            .padding(.horizontal, 8)
                            .frame(height: 20)
                            .background(NotchPalette.danger.opacity(0.32), in: Capsule())
                    }
                    .buttonStyle(NotchButtonStyle())
                    .accessibilityLabel(language.localized(chinese: "重试切换账号", english: "Retry switch"))
                }
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(NotchPalette.secondaryText)
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(NotchButtonStyle())
                .accessibilityLabel(language.localized(chinese: "关闭提示", english: "Dismiss error"))
            }
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity)
        .frame(height: NotchExpandedLayout.accountStatusBannerHeight)
        .background(bannerFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(bannerBorder, lineWidth: 0.5)
        }
    }

    private var bannerFill: Color {
        if case .failed = switchPhase {
            return NotchPalette.danger.opacity(0.14)
        }
        return NotchPalette.accent.opacity(0.12)
    }

    private var bannerBorder: Color {
        if case .failed = switchPhase {
            return NotchPalette.danger.opacity(0.32)
        }
        return NotchPalette.accent.opacity(0.28)
    }
}

private struct AccountDrawerToolbar: View {
    let snapshot: AccountPickerSnapshot
    let filter: AccountPickerFilter
    let isRefreshing: Bool
    let isSwitching: Bool
    let now: Date
    let language: AppLanguage
    let onSelectFilter: (AccountPickerFilter) -> Void
    let onRefreshAll: () -> Void

    private var showsFilterPills: Bool {
        snapshot.totalCount >= AccountPickerLogic.filterThresholdCount
    }

    var body: some View {
        HStack(spacing: 5) {
            if showsFilterPills {
                HStack(spacing: 4) {
                    ForEach(AccountPickerFilter.allCases, id: \.self) { candidate in
                        let selected = candidate == filter
                        Button {
                            onSelectFilter(candidate)
                        } label: {
                            Text(
                                candidate.title(
                                    availableCount: snapshot.availableCount,
                                    totalCount: snapshot.totalCount,
                                    language: language
                                )
                            )
                            .font(.system(size: 10, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? NotchPalette.primaryText : NotchPalette.secondaryText)
                            .padding(.horizontal, 7)
                            .frame(height: 21)
                            .background(
                                selected ? Color.white.opacity(0.14) : Color.white.opacity(0.04),
                                in: Capsule()
                            )
                            .overlay {
                                if selected {
                                    Capsule().stroke(Color.white.opacity(0.16), lineWidth: 0.5)
                                }
                            }
                            .lineLimit(1)
                        }
                        .buttonStyle(NotchButtonStyle())
                    }
                }
            } else {
                Text(
                    language.localized(
                        chinese: "选择切换账号 (\(snapshot.totalCount))",
                        english: "Switch account (\(snapshot.totalCount))"
                    )
                )
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(NotchPalette.secondaryText)
            }

            Spacer(minLength: 4)

            if !isRefreshing, let checkedAt = snapshot.latestQuotaCheckAt {
                Text(AccountProfile.conciseRelativeAge(since: checkedAt, now: now, language: language))
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(NotchPalette.secondaryText.opacity(0.75))
                    .monospacedDigit()
            }

            Button(action: onRefreshAll) {
                HStack(spacing: 3) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(0.68)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    Text(
                        isRefreshing
                            ? language.localized(chinese: "刷新中", english: "Syncing")
                            : language.localized(
                                chinese: showsFilterPills ? "刷新" : "刷新额度",
                                english: showsFilterPills ? "Sync" : "Refresh"
                            )
                    )
                    .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(NotchPalette.secondaryText)
                .padding(.horizontal, 7)
                .frame(height: 21)
                .background(Color.white.opacity(0.05), in: Capsule())
            }
            .buttonStyle(NotchButtonStyle())
            .disabled(isRefreshing || isSwitching)
            .accessibilityLabel(language.localized(chinese: "刷新全部账号额度", english: "Refresh all account quotas"))
        }
        .frame(height: NotchExpandedLayout.accountDrawerToolbarHeight)
    }
}

private struct AccountEmptyFilterGuard: View {
    let totalCount: Int
    let unusableCount: Int
    let language: AppLanguage
    let onShowAll: () -> Void

    private var emptyMessage: String {
        if unusableCount > 0 && unusableCount == totalCount {
            return language.localized(
                chinese: "当前 \(totalCount) 个账号均已退出或不可用",
                english: "All \(totalCount) accounts signed out or unavailable"
            )
        }
        if unusableCount > 0 {
            return language.localized(
                chinese: "无可用且余量 > 10% 账号（\(unusableCount) 个已退出/不可用）",
                english: "No usable accounts >10% (\(unusableCount) unavailable)"
            )
        }
        return language.localized(
            chinese: "当前筛选条件下无余量 > 10% 账号",
            english: "No accounts with >10% quota left"
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(emptyMessage)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(NotchPalette.secondaryText)
            .lineLimit(1)

            Button(action: onShowAll) {
                Text(
                    language.localized(
                        chinese: "查看全部 \(totalCount) 个账号",
                        english: "Show all \(totalCount) accounts"
                    )
                )
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(NotchPalette.accent)
                .padding(.horizontal, 12)
                .frame(height: 24)
                .background(NotchPalette.accent.opacity(0.14), in: Capsule())
                .overlay {
                    Capsule().stroke(NotchPalette.accent.opacity(0.32), lineWidth: 0.5)
                }
            }
            .buttonStyle(NotchButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .frame(height: NotchExpandedLayout.accountEmptyGuardHeight)
    }
}

private struct AccountDrawerCard: View {
    let account: AccountProfile
    let isActive: Bool
    let isSelected: Bool
    let isHovered: Bool
    let isStale: Bool
    let isSwitching: Bool
    let isTaskRunning: Bool
    let now: Date
    let language: AppLanguage
    let onHoverChanged: (Bool) -> Void
    let onTapRow: () -> Void
    let onCancelConfirm: () -> Void
    let onConfirmSwitch: () -> Void

    private var availabilityStatus: AccountAvailabilityStatus {
        account.resolvedAvailabilityStatus
    }

    private var isUsable: Bool {
        availabilityStatus == .available
    }

    private var confirmWarningStyle: AccountConfirmWarningStyle {
        if availabilityStatus != .available {
            return .unusableAccount(availabilityStatus, interruptsTask: isTaskRunning)
        }
        return isTaskRunning ? .interruptRunning : .normal
    }

    private var subtitle: String {
        account.subtitleText
    }

    private var cardBackground: Color {
        if isSelected && !isActive {
            let accentColor: Color = if !isUsable {
                NotchPalette.danger
            } else if isTaskRunning {
                NotchPalette.warning
            } else {
                NotchPalette.accent
            }
            return accentColor.opacity(0.11)
        }
        if isActive {
            return (!isUsable ? NotchPalette.danger : NotchPalette.accent).opacity(0.09)
        }
        if isHovered {
            return Color.white.opacity(0.08)
        }
        return Color.white.opacity(0.03)
    }

    private var cardBorder: Color {
        if isSelected && !isActive {
            let accentColor: Color = if !isUsable {
                NotchPalette.danger
            } else if isTaskRunning {
                NotchPalette.warning
            } else {
                NotchPalette.accent
            }
            return accentColor.opacity(0.42)
        }
        if isActive {
            return (!isUsable ? NotchPalette.danger : NotchPalette.accent).opacity(0.28)
        }
        if !isUsable {
            return NotchPalette.danger.opacity(isHovered ? 0.38 : 0.22)
        }
        if isHovered {
            return NotchPalette.accent.opacity(0.36)
        }
        return NotchPalette.border.opacity(0.45)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTapRow) {
                HStack(spacing: 8) {
                    AccountMonogramAvatar(account: account, size: 22, cornerRadius: 6.5)
                        .opacity(isUsable ? 1.0 : 0.78)

                    VStack(alignment: .leading, spacing: 1.5) {
                        HStack(spacing: 4) {
                            Text(account.shortLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(isUsable ? NotchPalette.primaryText : NotchPalette.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            if let plan = account.planType, !plan.isEmpty {
                                AccountPlanPill(planType: plan)
                            }

                            if isActive {
                                Text(language.localized(chinese: "当前", english: "Active"))
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .foregroundStyle(NotchPalette.accent)
                                    .padding(.horizontal, 5)
                                    .frame(height: 14)
                                    .background(NotchPalette.accent.opacity(0.18), in: Capsule())
                            }

                            if availabilityStatus != .available {
                                AccountAvailabilityBadge(status: availabilityStatus, language: language)
                            } else if isStale {
                                Text(language.localized(chinese: "旧", english: "Stale"))
                                    .font(.system(size: 8.5, weight: .medium))
                                    .foregroundStyle(NotchPalette.warning)
                                    .padding(.horizontal, 4)
                                    .frame(height: 14)
                                    .background(NotchPalette.warning.opacity(0.16), in: Capsule())
                            }
                        }

                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(NotchPalette.secondaryText)
                                .opacity(isUsable ? 1.0 : 0.78)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    Spacer(minLength: 4)

                    AccountQuotaSummaryView(
                        quota: account.quota,
                        availabilityStatus: availabilityStatus,
                        language: language
                    )
                    .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .frame(height: NotchExpandedLayout.accountCardHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(NotchButtonStyle())
            .disabled(isSwitching)
            .accessibilityLabel(accessibilityLabel)

            if isSelected, !isActive {
                AccountConfirmFooter(
                    warningStyle: confirmWarningStyle,
                    isSwitching: isSwitching,
                    language: language,
                    onCancel: onCancelConfirm,
                    onConfirm: onConfirmSwitch
                )
            }
        }
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(cardBorder, lineWidth: 0.6)
        }
        .onHover(perform: onHoverChanged)
    }

    private var accessibilityLabel: String {
        var parts = [account.shortLabel]
        if isActive {
            parts.append(language.localized(chinese: "当前账号", english: "active account"))
        }
        switch availabilityStatus {
        case .available:
            break
        case .reauthRequired:
            parts.append(language.localized(chinese: "已退出需重登", english: "signed out"))
        case .unavailable:
            parts.append(language.localized(chinese: "账号不可用", english: "unavailable"))
        }
        if let fiveHour = account.quota?.primaryRemainingPercent {
            parts.append(
                language.localized(
                    chinese: "5小时剩余 \(Int(fiveHour.rounded()))%",
                    english: "5h \(Int(fiveHour.rounded()))% remaining"
                )
            )
        }
        if let weekly = account.quota?.secondaryRemainingPercent {
            parts.append(
                language.localized(
                    chinese: "本周剩余 \(Int(weekly.rounded()))%",
                    english: "weekly \(Int(weekly.rounded()))% remaining"
                )
            )
        }
        return parts.joined(separator: ", ")
    }
}

private enum AccountConfirmWarningStyle {
    case normal
    case interruptRunning
    case unusableAccount(AccountAvailabilityStatus, interruptsTask: Bool)
}

private struct AccountConfirmFooter: View {
    let warningStyle: AccountConfirmWarningStyle
    let isSwitching: Bool
    let language: AppLanguage
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var cueColor: Color {
        switch warningStyle {
        case .normal:
            return NotchPalette.accent
        case .interruptRunning:
            return NotchPalette.warning
        case .unusableAccount:
            return NotchPalette.danger
        }
    }

    private var messageText: String {
        switch warningStyle {
        case .normal:
            return language.localized(chinese: "重启 Codex 并切换至此账号", english: "Relaunch Codex & switch")
        case .interruptRunning:
            return language.localized(chinese: "⚠ 运行中任务将被中断并重启", english: "⚠ Running tasks will be interrupted")
        case let .unusableAccount(status, interruptsTask):
            if interruptsTask {
                return language.localized(
                    chinese: "⚠ 该账号已退出/不可用且会中断任务",
                    english: "⚠ Account unusable & interrupts tasks"
                )
            }
            switch status {
            case .reauthRequired, .available:
                return language.localized(
                    chinese: "⚠ 该账号已退出，切换后需在 Codex 重登",
                    english: "⚠ Signed out — re-login needed in Codex"
                )
            case .unavailable:
                return language.localized(
                    chinese: "⚠ 该账号当前不可用，仍要切换？",
                    english: "⚠ Account unavailable — switch anyway?"
                )
            }
        }
    }

    private var confirmTitle: String {
        switch warningStyle {
        case .normal:
            return language.localized(chinese: "确认切换", english: "Confirm")
        case .interruptRunning:
            return language.localized(chinese: "中断并切换", english: "Interrupt & switch")
        case .unusableAccount:
            return language.localized(chinese: "仍要切换", english: "Switch anyway")
        }
    }

    private var confirmTextColor: Color {
        switch warningStyle {
        case .interruptRunning:
            return Color.black
        case .normal, .unusableAccount:
            return Color.white
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)

            HStack(spacing: 6) {
                Circle()
                    .fill(cueColor)
                    .frame(width: 5, height: 5)

                Text(messageText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(cueColor)
                .lineLimit(1)
                .truncationMode(.tail)

                Spacer(minLength: 4)

                Button(action: onCancel) {
                    Text(language.localized(chinese: "取消", english: "Cancel"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NotchPalette.secondaryText)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(NotchButtonStyle())
                .disabled(isSwitching)

                Button(action: onConfirm) {
                    Text(confirmTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(confirmTextColor)
                    .padding(.horizontal, 9)
                    .frame(height: 22)
                    .background(cueColor, in: Capsule())
                }
                .buttonStyle(NotchButtonStyle())
                .disabled(isSwitching)
            }
            .padding(.horizontal, 8)
            .frame(height: NotchExpandedLayout.accountConfirmFooterHeight - 0.5)
        }
        .frame(height: NotchExpandedLayout.accountConfirmFooterHeight)
    }
}

private struct AccountQuotaSummaryView: View {
    let quota: AccountQuota?
    let availabilityStatus: AccountAvailabilityStatus
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if availabilityStatus != .available {
                Text(
                    availabilityStatus == .reauthRequired
                        ? language.localized(chinese: "需重新登录", english: "Sign in again")
                        : language.localized(chinese: "账号不可用", english: "Unavailable")
                )
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(NotchPalette.danger)
                .lineLimit(1)

                if let weekly = quota?.secondaryRemainingPercent {
                    Text(
                        language.localized(
                            chinese: "原 7d \(Int(weekly.rounded()))%",
                            english: "Was 7d \(Int(weekly.rounded()))%"
                        )
                    )
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(NotchPalette.secondaryText.opacity(0.75))
                    .monospacedDigit()
                    .lineLimit(1)
                } else {
                    Text("—")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(NotchPalette.secondaryText.opacity(0.6))
                }
            } else if let quota, quota.secondaryRemainingPercent != nil || quota.primaryRemainingPercent != nil {
                HStack(spacing: 4) {
                    if let fiveHour = quota.primaryRemainingPercent {
                        Text("5h \(Int(fiveHour.rounded()))%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(QuotaColorScale.color(for: fiveHour))
                    }

                    if quota.primaryRemainingPercent != nil, quota.secondaryRemainingPercent != nil {
                        Text("·")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(NotchPalette.secondaryText.opacity(0.55))
                    }

                    if let weekly = quota.secondaryRemainingPercent {
                        Text("7d \(Int(weekly.rounded()))%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(QuotaColorScale.color(for: weekly))
                    }
                }
                .monospacedDigit()

                Text(quota.conciseResetText(language: language))
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(NotchPalette.secondaryText.opacity(0.75))
                    .monospacedDigit()
                    .lineLimit(1)
            } else {
                Text(language.localized(chinese: "未检查", english: "Unchecked"))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(NotchPalette.secondaryText)
            }
        }
    }
}

private struct AccountPlanPill: View {
    let planType: String

    var body: some View {
        Text(planType.uppercased())
            .font(.system(size: 8.5, weight: .bold))
            .foregroundStyle(NotchPalette.secondaryText)
            .padding(.horizontal, 4.5)
            .frame(height: 14)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}

private struct AccountAvailabilityBadge: View {
    let status: AccountAvailabilityStatus
    let language: AppLanguage

    private var labelText: String {
        switch status {
        case .available:
            return ""
        case .reauthRequired:
            return language.localized(chinese: "已退出", english: "Signed out")
        case .unavailable:
            return language.localized(chinese: "不可用", english: "Unavailable")
        }
    }

    var body: some View {
        Text(labelText)
            .font(.system(size: 8.5, weight: .semibold))
            .foregroundStyle(NotchPalette.danger)
            .padding(.horizontal, 4.5)
            .frame(height: 14)
            .background(NotchPalette.danger.opacity(0.16), in: Capsule())
            .overlay {
                Capsule().stroke(NotchPalette.danger.opacity(0.30), lineWidth: 0.5)
            }
    }
}

private struct AccountMonogramAvatar: View {
    let account: AccountProfile
    let size: CGFloat
    let cornerRadius: CGFloat

    private static let palette: [(Color, Color)] = [
        (Color(red: 0.25, green: 0.54, blue: 0.98), Color(red: 0.16, green: 0.36, blue: 0.80)),
        (Color(red: 0.20, green: 0.76, blue: 0.54), Color(red: 0.10, green: 0.54, blue: 0.38)),
        (Color(red: 0.96, green: 0.62, blue: 0.20), Color(red: 0.78, green: 0.42, blue: 0.10)),
        (Color(red: 0.62, green: 0.44, blue: 0.96), Color(red: 0.44, green: 0.28, blue: 0.76)),
        (Color(red: 0.92, green: 0.38, blue: 0.54), Color(red: 0.72, green: 0.22, blue: 0.38)),
        (Color(red: 0.22, green: 0.74, blue: 0.86), Color(red: 0.12, green: 0.52, blue: 0.66))
    ]

    var body: some View {
        let pair = Self.palette[account.monogramPaletteIndex % Self.palette.count]
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [pair.0, pair.1],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
            }
            .overlay {
                Text(account.monogramCharacter)
                    .font(.system(size: size * 0.48, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
            }
    }
}
