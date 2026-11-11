import SwiftUI

/// Inline account switcher shown in the expanded notch card. The first click
/// on an avatar switches immediately; there is no intermediate menu.
struct AccountQuickSwitchBar: View {
    @ObservedObject var service: AccountsService
    let language: AppLanguage

    @State private var switchingAccountID: UUID?

    private var visibleAccounts: [AccountProfile] {
        Array(service.accounts.prefix(5))
    }

    private var overflowAccounts: [AccountProfile] {
        Array(service.accounts.dropFirst(5))
    }

    var body: some View {
        if service.accounts.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 6) {
                ForEach(visibleAccounts) { account in
                    avatar(for: account)
                }

                if !overflowAccounts.isEmpty {
                    Menu {
                        ForEach(overflowAccounts) { account in
                            Button(account.shortLabel) { switchTo(account) }
                        }
                    } label: {
                        Text("+\(overflowAccounts.count)")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 22, height: 22)
                            .background(Color.secondary.opacity(0.14), in: Circle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }

                if let active = service.activeAccount {
                    Text(active.shortLabel)
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 76, alignment: .leading)
                }
            }
            .accessibilityLabel(
                language.localized(chinese: "切换 Codex 账号", english: "Switch Codex account")
            )
        }
    }

    private func avatar(for account: AccountProfile) -> some View {
        let isActive = account.id == service.activeAccountID
        let isSwitching = switchingAccountID == account.id

        return Button {
            switchTo(account)
        } label: {
            ZStack {
                Circle()
                    .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.16))

                if isSwitching {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Text(String(account.shortLabel.prefix(1)).uppercased())
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(isActive ? Color.white : Color.secondary)
                }
            }
            .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .disabled(switchingAccountID != nil)
        .help(helpText(for: account))
        .accessibilityLabel(account.shortLabel)
        .accessibilityValue(
            isActive
                ? language.localized(chinese: "当前账号", english: "Active account")
                : ""
        )
    }

    private func helpText(for account: AccountProfile) -> String {
        var parts = [account.shortLabel]
        if let email = account.email, !email.isEmpty {
            parts.append(email)
        }
        if account.id == service.activeAccountID {
            parts.append(language.localized(chinese: "当前账号", english: "Active"))
        }
        return parts.joined(separator: " · ")
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
