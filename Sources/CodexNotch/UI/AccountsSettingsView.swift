import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AccountsSettingsView: View {
    @ObservedObject var service: AccountsService
    let appLanguage: AppLanguage

    @State private var editing: AccountProfile?
    @State private var editingName = ""
    @State private var editingNote = ""
    @State private var pendingDelete: AccountProfile?
    @State private var busyAccountID: UUID?
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            if service.accounts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(service.accounts) { account in
                            accountRow(account)
                        }
                    }
                }
            }
            footer
        }
        .sheet(item: $editing) { account in
            editSheet(account)
        }
        .confirmationDialog(
            appLanguage.localized(
                chinese: "删除「\(pendingDelete?.shortLabel ?? "")」？",
                english: "Delete \(pendingDelete?.shortLabel ?? "")?"
            ),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button(appLanguage.localized(chinese: "删除账号和本地数据", english: "Delete account and local data"), role: .destructive) {
                if let account = pendingDelete {
                    try? service.delete(account.id)
                }
                pendingDelete = nil
            }
            Button(appLanguage.localized(chinese: "取消", english: "Cancel"), role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text(appLanguage.localized(
                chinese: "会从本机账号库中移除该账号及保存的 auth.json，不会删除 ~/.codex 中的共享项目和对话记录，也不会退出当前已运行的 Codex。",
                english: "This removes the account and its saved auth.json from the local vault. Shared projects and sessions in ~/.codex stay untouched, and a running Codex session is left as is."
            ))
        }
        .alert(
            appLanguage.localized(chinese: "操作失败", english: "Something went wrong"),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(appLanguage.localized(chinese: "Codex 账号", english: "Codex accounts"))
                    .font(.headline)
                Text(appLanguage.localized(
                    chinese: "所有账号共享 ~/.codex 中的项目与对话记录，切换时更新 auth.json 并重启 Codex。",
                    english: "Accounts share projects and sessions in ~/.codex; switching updates auth.json and relaunches Codex."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                importAuthFile()
            } label: {
                Label(appLanguage.localized(chinese: "导入", english: "Import"), systemImage: "square.and.arrow.down")
            }
            Button {
                Task { await refreshAll() }
            } label: {
                if isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Label(appLanguage.localized(chinese: "刷新额度", english: "Refresh quota"), systemImage: "arrow.clockwise")
                }
            }
            .disabled(isRefreshing || service.accounts.isEmpty)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "person.2.badge.key")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(appLanguage.localized(chinese: "还没有账号", english: "No accounts yet"))
                .font(.headline)
            Text(appLanguage.localized(
                chinese: "导入一个 `auth.json`，或从原来的 Codex Account Switcher 自动接管已有账号。",
                english: "Import an `auth.json`, or let CodexNotch adopt accounts from the existing Codex Account Switcher."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 380)
            Button {
                importAuthFile()
            } label: {
                Label(appLanguage.localized(chinese: "导入 auth.json", english: "Import auth.json"), systemImage: "plus")
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func accountRow(_ account: AccountProfile) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                Text(String(account.shortLabel.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(account.shortLabel)
                        .font(.system(size: 13, weight: .semibold))
                    if account.id == service.activeAccountID {
                        Text(appLanguage.localized(chinese: "当前", english: "Active"))
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.green.opacity(0.18)))
                            .foregroundStyle(.green)
                    }
                    if let plan = account.planType, !plan.isEmpty {
                        Text(plan.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    if account.resolvedAvailabilityStatus != .available {
                        Text(
                            account.resolvedAvailabilityStatus == .reauthRequired
                                ? appLanguage.localized(chinese: "已退出", english: "Signed out")
                                : appLanguage.localized(chinese: "不可用", english: "Unavailable")
                        )
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.red.opacity(0.16)))
                        .foregroundStyle(.red)
                    }
                }
                if let email = account.email {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(quotaSummary(account))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let note = account.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                switchTo(account)
            } label: {
                if busyAccountID == account.id {
                    ProgressView().controlSize(.small)
                } else {
                    Text(account.id == service.activeAccountID
                         ? appLanguage.localized(chinese: "重启", english: "Relaunch")
                         : appLanguage.localized(chinese: "切换", english: "Switch"))
                }
            }
            .disabled(busyAccountID != nil)

            Menu {
                Button(appLanguage.localized(chinese: "编辑名称和备注", english: "Edit name and note")) {
                    editingName = account.displayName
                    editingNote = account.note ?? ""
                    editing = account
                }
                Button(appLanguage.localized(chinese: "导出 auth.json", english: "Export auth.json")) {
                    export(account)
                }
                Button(appLanguage.localized(chinese: "在 Finder 中显示数据目录", english: "Reveal data folder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([service.homeURL(for: account.id)])
                }
                Divider()
                Button(appLanguage.localized(chinese: "删除", english: "Delete"), role: .destructive) {
                    pendingDelete = account
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(account.id == service.activeAccountID
                      ? Color.accentColor.opacity(0.07)
                      : Color.secondary.opacity(0.06))
        )
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield")
            Text(appLanguage.localized(
                chinese: "账号凭据仅保存在本机隔离保险库（0700/0600），仅在切换时原子写入 ~/.codex/auth.json。",
                english: "Account credentials stay in your local vault (0700/0600) and are written atomically to ~/.codex/auth.json only when switching."
            ))
            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func editSheet(_ account: AccountProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appLanguage.localized(chinese: "编辑账号", english: "Edit account"))
                .font(.headline)
            TextField(appLanguage.localized(chinese: "名称", english: "Name"), text: $editingName)
                .textFieldStyle(.roundedBorder)
            TextField(appLanguage.localized(chinese: "备注（仅本机）", english: "Note (local only)"), text: $editingNote)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(appLanguage.localized(chinese: "取消", english: "Cancel")) {
                    editing = nil
                }
                Button(appLanguage.localized(chinese: "保存", english: "Save")) {
                    try? service.rename(account.id, to: editingName)
                    try? service.updateNote(account.id, note: editingNote)
                    editing = nil
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private func quotaSummary(_ account: AccountProfile) -> String {
        guard let quota = account.quota else {
            return appLanguage.localized(chinese: "额度未检查", english: "Quota not checked")
        }
        var parts: [String] = []
        if let primary = quota.primaryUsedPercent {
            parts.append(appLanguage.localized(
                chinese: String(format: "5 小时剩 %.0f%%", max(0, 100 - primary)),
                english: String(format: "5h %.0f%% left", max(0, 100 - primary))
            ))
        }
        if let secondary = quota.secondaryUsedPercent {
            parts.append(appLanguage.localized(
                chinese: String(format: "7 天剩 %.0f%%", max(0, 100 - secondary)),
                english: String(format: "7d %.0f%% left", max(0, 100 - secondary))
            ))
        }
        return parts.isEmpty
            ? appLanguage.localized(chinese: "额度未检查", english: "Quota not checked")
            : parts.joined(separator: " · ")
    }

    private func switchTo(_ account: AccountProfile) {
        busyAccountID = account.id
        Task {
            do {
                try await service.switchTo(account.id)
            } catch {
                errorMessage = error.localizedDescription
            }
            busyAccountID = nil
        }
    }

    private func refreshAll() async {
        isRefreshing = true
        await service.refreshAllQuotas()
        isRefreshing = false
    }

    private func importAuthFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            _ = try service.importSession(data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func export(_ account: AccountProfile) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(account.shortLabel)-auth.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try service.exportSession(account.id)
            try data.write(to: url, options: [.atomic])
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
