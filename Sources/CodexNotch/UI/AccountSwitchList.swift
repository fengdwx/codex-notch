import SwiftUI

/// Account list shown inside the expanded notch card. The list is visible as
/// soon as the card expands; tapping a row switches immediately.
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
                    Text(account.shortLabel)
                        .font(.system(size: 11.5, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let detail = detailLine(for: account) {
                        Text(detail)
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if isSwitching {
                    ProgressView().controlSize(.mini)
                } else if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.green)
                } else {
                    Text(quotaLabel(for: account))
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(Color.secondary)
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
        .accessibilityValue(
            isActive
                ? language.localized(chinese: "当前账号", english: "Active account")
                : quotaLabel(for: account)
        )
    }

    private func detailLine(for account: AccountProfile) -> String? {
        var parts: [String] = []
        if let email = account.email, !email.isEmpty {
            parts.append(email)
        }
        if let plan = account.planType, !plan.isEmpty {
            parts.append(plan.uppercased())
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func quotaLabel(for account: AccountProfile) -> String {
        guard let used = account.quota?.secondaryUsedPercent else {
            return language.localized(chinese: "未检查", english: "Not checked")
        }
        return language.localized(
            chinese: String(format: "7 天剩 %.0f%%", max(0, 100 - used)),
            english: String(format: "7d %.0f%% left", max(0, 100 - used))
        )
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
