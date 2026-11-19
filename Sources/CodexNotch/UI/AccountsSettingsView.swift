import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AccountsSettingsView: View {
    @ObservedObject var service: AccountsService
    let appLanguage: AppLanguage
    @Binding var isShowingWebLoginSheet: Bool

    @State private var editingAccountID: UUID?
    @State private var editingName = ""
    @State private var editingNote = ""
    @State private var confirmingDeleteAccountID: UUID?
    @State private var deleteResetTask: Task<Void, Never>?
    @State private var busyAccountID: UUID?
    @State private var refreshingAccountIDs: Set<UUID> = []
    @State private var noticeBanner: SettingsNoticeBanner?
    @State private var noticeDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSheetIntro(
                subtitle: appLanguage.localized(
                    chinese: "共用本地 ~/.codex 工作区，切换自动延续项目与对话",
                    english: "Shared ~/.codex workspace with automatic project continuation"
                )
            )

            quickImportStrip

            if let noticeBanner {
                bannerRow(noticeBanner)
            }

            if service.accounts.isEmpty {
                emptyStateCard
            } else {
                ScrollView(.vertical, showsIndicators: service.accounts.count > 3) {
                    LazyVStack(spacing: 10) {
                        ForEach(service.accounts) { account in
                            accountCard(account)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            Spacer(minLength: 0)

            footerNote
        }
        .sheet(isPresented: $isShowingWebLoginSheet, onDismiss: {
            if service.isolatedLoginState.phase.isInProgress {
                service.cancelWebLogin(language: appLanguage)
            }
            service.resetWebLoginState()
        }) {
            IsolatedLoginSheet(service: service, appLanguage: appLanguage) {
                isShowingWebLoginSheet = false
            }
        }
        .onDisappear {
            deleteResetTask?.cancel()
            noticeDismissTask?.cancel()
        }
    }

    // MARK: - Quiet Secondary Import Utility Strip

    private var quickImportStrip: some View {
        HStack(spacing: 8) {
            Text(appLanguage.localized(chinese: "其他导入方式：", english: "Or import:"))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            utilityLink(
                title: appLanguage.localized(chinese: "导入 auth.json 文件", english: "Import auth.json"),
                systemImage: "doc"
            ) {
                importAuthFile()
            }

            Text("·")
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)

            utilityLink(
                title: appLanguage.localized(chinese: "导入当前本地登录", english: "Adopt local login"),
                systemImage: "desktopcomputer"
            ) {
                importCurrentLocalSession()
            }

            Spacer(minLength: 0)
        }
    }

    private func utilityLink(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 10.5))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        SettingsSurfaceCard(padding: 24) {
            VStack(spacing: 8) {
                Image(systemName: "person.2")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.secondary)
                Text(appLanguage.localized(chinese: "暂无已保存账号", english: "No accounts saved"))
                    .font(.system(size: 13.5, weight: .semibold))
                Text(appLanguage.localized(
                    chinese: "点击右上角「+ 网页登录」在独立浏览器沙盒中授权添加，或使用上方导入选项。",
                    english: "Click + Sign in above to authorize via browser, or use one of the import options."
                ))
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Clean Account Card

    private func accountCard(_ account: AccountProfile) -> some View {
        let isActive = account.id == service.activeAccountID
        let isConfirmingDelete = confirmingDeleteAccountID == account.id
        let isEditing = editingAccountID == account.id
        let status = account.resolvedAvailabilityStatus

        let border: Color? = isConfirmingDelete ? Color.red.opacity(0.42) : nil

        return SettingsSurfaceCard(padding: 0, accentBorder: border) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 11) {
                    AccountMonogramAvatar(account: account, size: 32, cornerRadius: 8)

                    VStack(alignment: .leading, spacing: 2.5) {
                        HStack(spacing: 6) {
                            Text(account.shortLabel)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if let plan = account.planType, !plan.isEmpty {
                                Text(plan.uppercased())
                                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(Color.primary.opacity(0.06))
                                    )
                            }

                            if isActive {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 5.5, height: 5.5)
                                    Text(appLanguage.localized(chinese: "当前", english: "Active"))
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundStyle(.green)
                                }
                            }

                            if status != .available {
                                Text(
                                    status == .reauthRequired
                                        ? appLanguage.localized(chinese: "需重新登录", english: "Re-auth")
                                        : appLanguage.localized(chinese: "不可用", english: "Unavailable")
                                )
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(status == .reauthRequired ? .orange : .red)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule()
                                        .fill((status == .reauthRequired ? Color.orange : Color.red).opacity(0.12))
                                )
                            }
                        }

                        subtitleLine(for: account)
                    }

                    Spacer(minLength: 8)

                    cardActions(
                        for: account,
                        isActive: isActive,
                        isConfirmingDelete: isConfirmingDelete,
                        status: status
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                if isEditing {
                    SettingsHairlineDivider()
                        .padding(.horizontal, 14)
                    inlineEditor(for: account)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                }

                SettingsHairlineDivider()
                    .padding(.horizontal, 14)

                AccountQuotaStripView(
                    account: account,
                    appLanguage: appLanguage,
                    isRefreshing: refreshingAccountIDs.contains(account.id),
                    onRefresh: { Task { await refreshSingle(account) } }
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isConfirmingDelete)
        .animation(.easeInOut(duration: 0.15), value: isEditing)
    }

    private func subtitleLine(for account: AccountProfile) -> some View {
        HStack(spacing: 5) {
            if let email = account.email, !email.isEmpty {
                Text(email)
                    .lineLimit(1)
            }
            if let note = account.note, !note.isEmpty {
                if account.email?.isEmpty == false {
                    Text("·")
                }
                Text(note)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            if let checkedAt = account.quota?.checkedAt ?? account.lastCheckedAt {
                Text("· \(AccountProfile.conciseRelativeAge(since: checkedAt, now: .now, language: appLanguage))")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func cardActions(
        for account: AccountProfile,
        isActive: Bool,
        isConfirmingDelete: Bool,
        status: AccountAvailabilityStatus
    ) -> some View {
        let isSwitching = busyAccountID != nil || service.switchPhase.isSwitching

        if isConfirmingDelete {
            HStack(spacing: 6) {
                SettingsActionButton(
                    title: appLanguage.localized(chinese: "取消", english: "Cancel"),
                    tone: .secondary
                ) {
                    cancelDeleteConfirmation()
                }

                SettingsActionButton(
                    title: appLanguage.localized(chinese: "确认删除", english: "Delete"),
                    tone: .destructive,
                    isDisabled: isSwitching
                ) {
                    performDelete(account)
                }
            }
        } else {
            HStack(spacing: 2) {
                primaryActionButton(for: account, isActive: isActive, status: status)
                    .padding(.trailing, 4)

                SettingsIconButton(
                    systemName: editingAccountID == account.id ? "pencil.circle.fill" : "pencil",
                    tint: .secondary,
                    isActive: editingAccountID == account.id,
                    helpText: appLanguage.localized(chinese: "编辑名称与备注", english: "Edit name & note")
                ) {
                    toggleInlineEditor(for: account)
                }

                SettingsIconButton(
                    systemName: "arrow.clockwise",
                    tint: .secondary,
                    isLoading: refreshingAccountIDs.contains(account.id),
                    isDisabled: refreshingAccountIDs.contains(account.id),
                    helpText: appLanguage.localized(chinese: "刷新此账号额度", english: "Refresh quota")
                ) {
                    Task { await refreshSingle(account) }
                }

                SettingsIconButton(
                    systemName: "square.and.arrow.up",
                    tint: .secondary,
                    helpText: appLanguage.localized(chinese: "导出 auth.json…", english: "Export auth.json…")
                ) {
                    export(account)
                }

                SettingsIconButton(
                    systemName: "folder",
                    tint: .secondary,
                    helpText: appLanguage.localized(chinese: "在 Finder 中显示 Codex 目录", english: "Reveal Codex folder")
                ) {
                    NSWorkspace.shared.activateFileViewerSelecting([service.homeURL(for: account.id)])
                }

                SettingsIconButton(
                    systemName: "trash",
                    tint: .red.opacity(0.75),
                    isDisabled: isSwitching,
                    helpText: appLanguage.localized(chinese: "删除账号", english: "Delete account")
                ) {
                    armDeleteConfirmation(for: account.id)
                }
            }
        }
    }

    @ViewBuilder
    private func primaryActionButton(
        for account: AccountProfile,
        isActive: Bool,
        status: AccountAvailabilityStatus
    ) -> some View {
        let isAnySwitching = busyAccountID != nil || service.switchPhase.isSwitching
        let isThisSwitching: Bool = {
            if case let .switching(targetID) = service.switchPhase, targetID == account.id {
                return true
            }
            return busyAccountID == account.id
        }()

        if status == .reauthRequired {
            SettingsActionButton(
                title: appLanguage.localized(chinese: "重新登录", english: "Sign in"),
                tone: .prominent(.orange)
            ) {
                startBrowserLogin()
            }
        } else if isActive {
            SettingsActionButton(
                title: appLanguage.localized(chinese: "重启", english: "Relaunch"),
                tone: .secondary,
                isLoading: isThisSwitching,
                isDisabled: isAnySwitching
            ) {
                switchTo(account)
            }
        } else {
            SettingsActionButton(
                title: appLanguage.localized(chinese: "切换", english: "Switch"),
                tone: .prominent(.accentColor),
                isLoading: isThisSwitching,
                isDisabled: isAnySwitching
            ) {
                switchTo(account)
            }
        }
    }

    private func inlineEditor(for account: AccountProfile) -> some View {
        HStack(spacing: 6) {
            TextField(appLanguage.localized(chinese: "名称", english: "Name"), text: $editingName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 140)
                .onSubmit { saveInlineEditor(for: account) }

            TextField(appLanguage.localized(chinese: "备注（仅本机）", english: "Note (local only)"), text: $editingNote)
                .textFieldStyle(.roundedBorder)
                .onSubmit { saveInlineEditor(for: account) }

            SettingsActionButton(
                title: appLanguage.localized(chinese: "取消", english: "Cancel"),
                tone: .secondary
            ) {
                editingAccountID = nil
            }

            SettingsActionButton(
                title: appLanguage.localized(chinese: "保存", english: "Save"),
                tone: .prominent(.accentColor)
            ) {
                saveInlineEditor(for: account)
            }
        }
    }

    // MARK: - Banner & Footer

    private func bannerRow(_ banner: SettingsNoticeBanner) -> some View {
        HStack(spacing: 8) {
            Image(systemName: banner.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(banner.isError ? .red : .green)
                .font(.system(size: 12))
            Text(banner.message)
                .font(.system(size: 11.5))
                .foregroundStyle(banner.isError ? .red : .primary)
                .lineLimit(2)
            Spacer()
            SettingsIconButton(systemName: "xmark", tint: .secondary) {
                noticeBanner = nil
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill((banner.isError ? Color.red : Color.green).opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder((banner.isError ? Color.red : Color.green).opacity(0.22), lineWidth: 0.75)
        )
    }

    static func sharedHomeFooterText(for appLanguage: AppLanguage) -> String {
        appLanguage.localized(
            chinese: "凭据保存在本机 0700/0600 保险库；切换时会先回存当前凭据，再原子写入 ~/.codex/auth.json。",
            english: "Credentials stay in your local 0700/0600 vault; switching saves the active token first, then updates ~/.codex/auth.json."
        )
    }

    private var footerNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield")
                .font(.system(size: 10.5))
            Text(Self.sharedHomeFooterText(for: appLanguage))
            .font(.system(size: 10.5))
            Spacer()
        }
        .foregroundStyle(.tertiary)
    }

    // MARK: - Actions

    private func startBrowserLogin() {
        isShowingWebLoginSheet = true
        service.startWebLogin(language: appLanguage)
    }

    private func toggleInlineEditor(for account: AccountProfile) {
        if editingAccountID == account.id {
            editingAccountID = nil
        } else {
            editingName = account.displayName
            editingNote = account.note ?? ""
            editingAccountID = account.id
        }
    }

    private func saveInlineEditor(for account: AccountProfile) {
        do {
            try service.rename(account.id, to: editingName)
            try service.updateNote(account.id, note: editingNote)
            editingAccountID = nil
        } catch {
            showNotice(error.localizedDescription, isError: true)
        }
    }

    private func armDeleteConfirmation(for id: UUID) {
        deleteResetTask?.cancel()
        confirmingDeleteAccountID = id
        deleteResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            if confirmingDeleteAccountID == id {
                confirmingDeleteAccountID = nil
            }
        }
    }

    private func cancelDeleteConfirmation() {
        deleteResetTask?.cancel()
        confirmingDeleteAccountID = nil
    }

    private func performDelete(_ account: AccountProfile) {
        guard busyAccountID == nil, !service.switchPhase.isSwitching else { return }
        deleteResetTask?.cancel()
        confirmingDeleteAccountID = nil
        if editingAccountID == account.id {
            editingAccountID = nil
        }
        do {
            try service.delete(account.id)
            showNotice(
                appLanguage.localized(
                    chinese: "已删除账号「\(account.shortLabel)」的本地凭据。",
                    english: "Removed saved credentials for \(account.shortLabel)."
                ),
                isError: false
            )
        } catch {
            showNotice(error.localizedDescription, isError: true)
        }
    }

    private func switchTo(_ account: AccountProfile) {
        guard busyAccountID == nil, !service.switchPhase.isSwitching else { return }
        guard let task = service.beginSwitch(to: account.id, language: appLanguage) else { return }
        busyAccountID = account.id
        Task { @MainActor in
            await task.value
            if case let .failed(_, message) = service.switchPhase {
                showNotice(message, isError: true)
            }
            busyAccountID = nil
        }
    }

    private func refreshSingle(_ account: AccountProfile) async {
        refreshingAccountIDs.insert(account.id)
        defer { refreshingAccountIDs.remove(account.id) }
        do {
            try await service.refreshQuota(for: account.id)
        } catch {
            showNotice(error.localizedDescription, isError: true)
        }
    }

    private func importAuthFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let profile = try service.importSession(data)
            showNotice(
                appLanguage.localized(
                    chinese: "已导入账号「\(profile.shortLabel)」",
                    english: "Imported account \(profile.shortLabel)"
                ),
                isError: false
            )
            Task { @MainActor in
                try? await service.refreshQuota(for: profile.id)
            }
        } catch {
            showNotice(error.localizedDescription, isError: true)
        }
    }

    private func importCurrentLocalSession() {
        do {
            let profile = try service.importCurrentCodexSession()
            showNotice(
                appLanguage.localized(
                    chinese: "已导入当前登录账号「\(profile.shortLabel)」",
                    english: "Imported active session \(profile.shortLabel)"
                ),
                isError: false
            )
        } catch {
            showNotice(error.localizedDescription, isError: true)
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
            showNotice(
                appLanguage.localized(chinese: "已导出凭据文件", english: "Exported auth.json"),
                isError: false
            )
        } catch {
            showNotice(error.localizedDescription, isError: true)
        }
    }

    private func showNotice(_ message: String, isError: Bool) {
        noticeDismissTask?.cancel()
        noticeBanner = SettingsNoticeBanner(message: message, isError: isError)
        if !isError {
            noticeDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                noticeBanner = nil
            }
        }
    }
}

private struct SettingsNoticeBanner: Equatable {
    let message: String
    let isError: Bool
}

private struct AccountQuotaStripView: View {
    let account: AccountProfile
    let appLanguage: AppLanguage
    let isRefreshing: Bool
    let onRefresh: () -> Void

    private var snapshot: UsageSnapshot? {
        account.quota?.previewUsageSnapshot(preservingResetCreditsFrom: nil)
    }

    var body: some View {
        if let snapshot, snapshot.fiveHourWindow != nil || snapshot.weeklyWindow != nil {
            HStack(spacing: 16) {
                if let fiveHour = snapshot.fiveHourWindow {
                    AccountQuotaLinearBar(
                        title: appLanguage.localized(chinese: "5 小时", english: "5h"),
                        window: fiveHour,
                        appLanguage: appLanguage
                    )
                }

                if let weekly = snapshot.weeklyWindow {
                    AccountQuotaLinearBar(
                        title: appLanguage.localized(chinese: "7 天周限额", english: "7d weekly"),
                        window: weekly,
                        appLanguage: appLanguage
                    )
                }
            }
        } else {
            HStack(spacing: 8) {
                Text(appLanguage.localized(
                    chinese: "尚未获取额度快照",
                    english: "No quota snapshot yet"
                ))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

                Spacer()

                SettingsActionButton(
                    title: appLanguage.localized(chinese: "立即刷新", english: "Refresh"),
                    systemImage: "arrow.clockwise",
                    tone: .secondary,
                    isLoading: isRefreshing
                ) {
                    onRefresh()
                }
            }
        }
    }
}

private struct AccountQuotaLinearBar: View {
    let title: String
    let window: UsageWindow
    let appLanguage: AppLanguage

    private static let resetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()

    private var remaining: Double { window.remainingPercent }
    private var barColor: Color { QuotaColorScale.color(for: remaining) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                if let resetAt = window.resetAt {
                    Text("· \(Self.resetFormatter.string(from: resetAt))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text(NotchText.percent(remaining))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(barColor)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(barColor)
                            .frame(width: max(0, proxy.size.width * CGFloat(min(max(remaining, 0), 100) / 100)))
                    }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
