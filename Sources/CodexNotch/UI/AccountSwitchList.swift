import SwiftUI

/// Vertical account list shown in the expanded notch card.
///
/// Rows are 28pt tall and capped at four visible rows. The first click on an
/// inactive row arms an inline confirmation (3.2s timeout); only the confirm
/// button actually switches. Hovering a row reveals its reset countdowns in
/// the section header.
struct AccountSwitchList: View {
    @ObservedObject var service: AccountsService
    let language: AppLanguage
    let isTaskRunning: Bool

    @State private var hoveredAccountID: UUID?
    @State private var confirmingAccountID: UUID?
    @State private var switchingAccountID: UUID?
    @State private var switchErrorText: String?
    @State private var confirmResetTask: Task<Void, Never>?

    private var orderedAccounts: [AccountProfile] {
        guard let activeID = service.activeAccountID else { return service.accounts }
        let active = service.accounts.filter { $0.id == activeID }
        let others = service.accounts.filter { $0.id != activeID }
        return active + others
    }

    private var visibleRowCount: Int {
        min(orderedAccounts.count, NotchExpandedLayout.maxVisibleAccountRows)
    }

    var body: some View {
        if service.accounts.count > 1 {
            VStack(alignment: .leading, spacing: 0) {
                header
                accountContainer
            }
            .padding(.top, NotchExpandedLayout.accountListTopSpacing)
            .task { await service.refreshStaleQuotas() }
            .onDisappear(perform: resetTransientState)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                language.localized(chinese: "Codex 账号列表", english: "Codex account list")
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Text(language.localized(chinese: "账号", english: "Accounts"))
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(NotchPalette.secondaryText)

            Spacer(minLength: 8)

            headerAccessory
                .font(.system(size: 10.5, weight: .regular))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(height: NotchExpandedLayout.accountListHeaderHeight, alignment: .bottom)
        .padding(.bottom, NotchExpandedLayout.accountListHeaderBottomSpacing)
    }

    @ViewBuilder
    private var headerAccessory: some View {
        if switchingAccountID != nil {
            Text(language.localized(chinese: "切换中…", english: "Switching…"))
                .foregroundStyle(NotchPalette.secondaryText)
        } else if let switchErrorText {
            Text("⚠️ \(switchErrorText)")
                .foregroundStyle(NotchPalette.danger)
        } else if confirmingAccountID != nil, isTaskRunning {
            Text(language.localized(
                chinese: "⚠️ 切换将中断当前运行中任务",
                english: "⚠️ Switching will interrupt the running task"
            ))
            .foregroundStyle(NotchPalette.warning)
        } else if let hoveredAccountID,
                  let account = service.accounts.first(where: { $0.id == hoveredAccountID }) {
            Text(countdownSummary(for: account))
                .foregroundStyle(NotchPalette.secondaryText)
        } else {
            EmptyView()
        }
    }

    private func countdownSummary(for account: AccountProfile) -> String {
        let primary = countdownText(account.quota?.primaryResetsAt)
        let secondary = countdownText(account.quota?.secondaryResetsAt)
        return language.localized(
            chinese: "\(account.shortLabel) · 5h 重置 \(primary) · 7d 重置 \(secondary)",
            english: "\(account.shortLabel) · 5h resets \(primary) · 7d resets \(secondary)"
        )
    }

    private func countdownText(_ resetsAt: Date?) -> String {
        guard let resetsAt else { return "—" }
        let remaining = resetsAt.timeIntervalSinceNow
        guard remaining > 0 else { return "—" }
        return compactDuration(remaining)
    }

    private func compactDuration(_ interval: TimeInterval) -> String {
        let seconds = Int(interval.rounded())
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h\(minutes % 60)m" }
        let days = hours / 24
        return "\(days)d\(hours % 24)h"
    }

    // MARK: - List

    private var accountContainer: some View {
        Group {
            if orderedAccounts.count > NotchExpandedLayout.maxVisibleAccountRows {
                ScrollView(.vertical, showsIndicators: true) {
                    rows
                }
                .frame(height: CGFloat(visibleRowCount) * NotchExpandedLayout.accountRowHeight)
            } else {
                rows
            }
        }
        .padding(.horizontal, 3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(NotchPalette.row.opacity(0.28))
        )
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(orderedAccounts) { account in
                row(for: account)
            }
        }
    }

    private func row(for account: AccountProfile) -> some View {
        let isActive = account.id == service.activeAccountID
        let isConfirming = confirmingAccountID == account.id
        let isSwitching = switchingAccountID == account.id
        let isHovered = hoveredAccountID == account.id

        return HStack(spacing: 8) {
            if isConfirming {
                leadingContent(for: account, isActive: isActive, isConfirming: true)
                    .contentShape(Rectangle())
                    .onTapGesture { cancelConfirmation() }
            } else {
                leadingContent(for: account, isActive: isActive, isConfirming: false)
            }

            Spacer(minLength: 6)

            if isSwitching {
                switchingContent
            } else if isConfirming {
                confirmationControls(for: account)
            } else {
                quotaCells(for: account)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: NotchExpandedLayout.accountRowHeight)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackground(isActive: isActive, isHovered: isHovered, isConfirming: isConfirming))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                hoveredAccountID = account.id
            } else if hoveredAccountID == account.id {
                hoveredAccountID = nil
            }
        }
        .onTapGesture {
            guard !isConfirming else { return }
            handleTap(account)
        }
        .accessibilityLabel(account.shortLabel)
        .accessibilityValue(accessibilityValue(for: account, isActive: isActive))
    }

    private func leadingContent(
        for account: AccountProfile,
        isActive: Bool,
        isConfirming: Bool
    ) -> some View {
        HStack(spacing: 8) {
            statusIndicator(for: account, isActive: isActive)

            Text(account.shortLabel)
                .font(.system(size: 12, weight: isActive ? .medium : .regular))
                .foregroundStyle(NotchPalette.primaryText.opacity(isActive ? 1 : 0.85))
                .lineLimit(1)

            if let plan = account.planType, !plan.isEmpty {
                Text(plan.uppercased())
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(NotchPalette.secondaryText)
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1)
                    .background(
                        NotchPalette.row,
                        in: RoundedRectangle(cornerRadius: 3.5)
                    )
            }

            if let note = account.note, !note.isEmpty, !isConfirming {
                Text(note)
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(NotchPalette.secondaryText.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }

    private func statusIndicator(
        for account: AccountProfile,
        isActive: Bool
    ) -> some View {
        Group {
            if isActive {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NotchPalette.success)
            } else {
                Circle()
                    .fill(statusColor(for: account))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 14, alignment: .center)
    }

    private func statusColor(for account: AccountProfile) -> Color {
        guard let used = account.quota?.secondaryUsedPercent else {
            return NotchPalette.secondaryText
        }
        return QuotaColorScale.color(for: max(0, 100 - used))
    }

    private var switchingContent: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.mini)
            Text(language.localized(chinese: "切换中…", english: "Switching…"))
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(NotchPalette.secondaryText)
        }
    }

    private func confirmationControls(for account: AccountProfile) -> some View {
        HStack(spacing: 6) {
            Button {
                cancelConfirmation()
            } label: {
                Text(language.localized(chinese: "取消", english: "Cancel"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(NotchPalette.secondaryText)
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(
                        NotchPalette.row,
                        in: RoundedRectangle(cornerRadius: 4.5)
                    )
            }
            .buttonStyle(NotchButtonStyle())

            Button {
                performSwitch(to: account)
            } label: {
                Text(
                    isTaskRunning
                        ? language.localized(chinese: "中断并切换", english: "Interrupt & switch")
                        : language.localized(chinese: "确认切换 ↻", english: "Switch ↻")
                )
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 8)
                .frame(height: 20)
                .background(
                    isTaskRunning ? NotchPalette.warning : NotchPalette.accent,
                    in: RoundedRectangle(cornerRadius: 4.5)
                )
            }
            .buttonStyle(NotchButtonStyle())
        }
        .fixedSize()
    }

    private func quotaCells(for account: AccountProfile) -> some View {
        HStack(spacing: 10) {
            quotaCell(
                label: language.localized(chinese: "5h", english: "5h"),
                usedPercent: account.quota?.primaryUsedPercent
            )
            quotaCell(
                label: language.localized(chinese: "7d", english: "7d"),
                usedPercent: account.quota?.secondaryUsedPercent
            )
        }
    }

    private func quotaCell(label: String, usedPercent: Double?) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(NotchPalette.secondaryText)

            Spacer(minLength: 0)

            Text(quotaText(usedPercent))
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(quotaColor(usedPercent))
        }
        .frame(width: 54)
    }

    private func quotaText(_ usedPercent: Double?) -> String {
        guard let usedPercent else { return "—" }
        return String(format: "%.0f%%", max(0, 100 - usedPercent))
    }

    private func quotaColor(_ usedPercent: Double?) -> Color {
        guard let usedPercent else { return NotchPalette.secondaryText }
        return QuotaColorScale.color(for: max(0, 100 - usedPercent))
    }

    private func rowBackground(
        isActive: Bool,
        isHovered: Bool,
        isConfirming: Bool
    ) -> Color {
        if isConfirming {
            return (isTaskRunning ? NotchPalette.warning : NotchPalette.accent)
                .opacity(0.15)
        }
        if isActive {
            return NotchPalette.row.opacity(0.65)
        }
        if isHovered {
            return NotchPalette.row.opacity(0.45)
        }
        return .clear
    }

    // MARK: - Interaction

    private func handleTap(_ account: AccountProfile) {
        guard switchingAccountID == nil else { return }
        guard account.id != service.activeAccountID else { return }

        if confirmingAccountID == account.id {
            cancelConfirmation()
            return
        }

        confirmResetTask?.cancel()
        switchErrorText = nil
        confirmingAccountID = account.id

        let armedID = account.id
        confirmResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard !Task.isCancelled else { return }
            if confirmingAccountID == armedID {
                confirmingAccountID = nil
            }
        }
    }

    private func cancelConfirmation() {
        confirmResetTask?.cancel()
        confirmResetTask = nil
        confirmingAccountID = nil
    }

    private func performSwitch(to account: AccountProfile) {
        confirmResetTask?.cancel()
        confirmResetTask = nil
        confirmingAccountID = nil
        switchingAccountID = account.id
        switchErrorText = nil

        Task { @MainActor in
            do {
                try await service.switchTo(account.id)
            } catch {
                switchErrorText = language.localized(
                    chinese: "切换失败，请重试",
                    english: "Switch failed, try again"
                )
            }
            switchingAccountID = nil
        }
    }

    private func resetTransientState() {
        confirmResetTask?.cancel()
        confirmResetTask = nil
        hoveredAccountID = nil
        confirmingAccountID = nil
        switchErrorText = nil
    }

    private func accessibilityValue(for account: AccountProfile, isActive: Bool) -> String {
        var parts: [String] = []
        if isActive {
            parts.append(language.localized(chinese: "当前账号", english: "Active account"))
        }
        if let used = account.quota?.secondaryUsedPercent {
            parts.append(language.localized(
                chinese: String(format: "7 天剩 %.0f%%", max(0, 100 - used)),
                english: String(format: "7d %.0f%% left", max(0, 100 - used))
            ))
        }
        return parts.joined(separator: ", ")
    }
}
