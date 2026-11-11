import SwiftUI

/// Account list shown inside the expanded notch card. Rows expose the same
/// 5-hour / weekly quota picture as the main card, and one click switches.
struct AccountSwitchList: View {
    @ObservedObject var service: AccountsService
    let language: AppLanguage

    @State private var switchingAccountID: UUID?

    var body: some View {
        if service.accounts.count > 1 {
            VStack(alignment: .leading, spacing: 0) {
                Text(language.localized(chinese: "账号", english: "Accounts"))
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(Color.secondary)
                    .frame(
                        height: NotchExpandedLayout.accountListHeaderHeight,
                        alignment: .bottomLeading
                    )

                ForEach(service.accounts) { account in
                    row(for: account)
                        .frame(height: NotchExpandedLayout.accountRowHeight)
                }
            }
            .padding(.top, 12)
            .task { await service.refreshStaleQuotas() }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                language.localized(chinese: "Codex 账号列表", english: "Codex account list")
            )
        }
    }

    private func row(for account: AccountProfile) -> some View {
        let isActive = account.id == service.activeAccountID
        let isSwitching = switchingAccountID == account.id

        return Button {
            guard !isActive else { return }
            switchTo(account)
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.16))
                    Text(String(account.shortLabel.prefix(1)).uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(isActive ? Color.white : Color.secondary)
                }
                .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(account.shortLabel)
                            .font(.system(size: 11.5, weight: isActive ? .semibold : .regular))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let plan = account.planType, !plan.isEmpty {
                            Text(plan.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.secondary)
                        }
                        if isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.green)
                        }
                    }
                    if let email = account.email, !email.isEmpty {
                        Text(email)
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

                if isSwitching {
                    ProgressView().controlSize(.mini)
                } else {
                    HStack(spacing: 10) {
                        windowCell(
                            label: language.localized(chinese: "5h", english: "5h"),
                            usedPercent: account.quota?.primaryUsedPercent,
                            resetsAt: account.quota?.primaryResetsAt
                        )
                        windowCell(
                            label: language.localized(chinese: "7d", english: "7d"),
                            usedPercent: account.quota?.secondaryUsedPercent,
                            resetsAt: account.quota?.secondaryResetsAt
                        )
                    }
                }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(switchingAccountID != nil)
        .help(account.email ?? account.shortLabel)
        .accessibilityLabel(account.shortLabel)
        .accessibilityValue(accessibilityValue(for: account, isActive: isActive))
    }

    private func windowCell(
        label: String,
        usedPercent: Double?,
        resetsAt: Date?
    ) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(Color.secondary)
                Text(percentText(usedPercent))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(usedPercent == nil ? Color.secondary : .primary)
            }
            Text(resetText(resetsAt))
                .font(.system(size: 7.5, weight: .regular))
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
        }
        .frame(width: 56, alignment: .trailing)
    }

    private func percentText(_ usedPercent: Double?) -> String {
        guard let usedPercent else {
            return language.localized(chinese: "—", english: "—")
        }
        return String(format: "%.0f%%", max(0, 100 - usedPercent))
    }

    private func resetText(_ resetsAt: Date?) -> String {
        guard let resetsAt else {
            return language.localized(chinese: "未检查", english: "not checked")
        }
        let remaining = resetsAt.timeIntervalSinceNow
        guard remaining > 0 else {
            return language.localized(chinese: "已重置", english: "reset")
        }
        return language.localized(
            chinese: "\(compactDuration(remaining)) 后重置",
            english: "resets in \(compactDuration(remaining))"
        )
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

    private func accessibilityValue(for account: AccountProfile, isActive: Bool) -> String {
        var parts: [String] = []
        if isActive {
            parts.append(language.localized(chinese: "当前账号", english: "Active account"))
        }
        if let plan = account.planType, !plan.isEmpty {
            parts.append(plan.uppercased())
        }
        if let used = account.quota?.secondaryUsedPercent {
            parts.append(language.localized(
                chinese: String(format: "7 天剩 %.0f%%", max(0, 100 - used)),
                english: String(format: "7d %.0f%% left", max(0, 100 - used))
            ))
        }
        return parts.joined(separator: ", ")
    }

    private func switchTo(_ account: AccountProfile) {
        guard switchingAccountID == nil else { return }
        switchingAccountID = account.id
        Task { @MainActor in
            try? await service.switchTo(account.id)
            switchingAccountID = nil
        }
    }
}
