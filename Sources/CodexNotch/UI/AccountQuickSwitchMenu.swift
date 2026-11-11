import SwiftUI

/// Compact account switcher shown in the expanded notch card. It deliberately
/// keeps the 24pt footer height so the notch geometry contract is unchanged.
struct AccountQuickSwitchMenu: View {
    @ObservedObject var service: AccountsService
    let language: AppLanguage

    var body: some View {
        if service.accounts.isEmpty {
            EmptyView()
        } else {
            Menu {
                ForEach(service.accounts) { account in
                    Button {
                        switchTo(account)
                    } label: {
                        if account.id == service.activeAccountID {
                            Label(account.shortLabel, systemImage: "checkmark")
                        } else {
                            Text(account.shortLabel)
                        }
                    }
                }
                Divider()
                SettingsLink {
                    Text(language.localized(chinese: "管理账号…", english: "Manage accounts…"))
                }
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(
                            service.activeAccountID == nil
                                ? Color.secondary
                                : Color.green
                        )
                        .frame(width: 5, height: 5)
                    Text(service.activeAccount?.shortLabel ?? "—")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 92, alignment: .leading)
                }
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(Color.secondary.opacity(0.14), in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(
                language.localized(chinese: "切换 Codex 账号", english: "Switch Codex account")
            )
        }
    }

    private func switchTo(_ account: AccountProfile) {
        Task { @MainActor in
            try? await service.switchTo(account.id)
        }
    }
}
