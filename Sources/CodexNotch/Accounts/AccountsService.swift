import Combine
import Foundation

enum AccountSwitchPhase: Equatable, Sendable {
    case idle
    case switching(targetID: UUID)
    case failed(targetID: UUID?, message: String)

    var isSwitching: Bool {
        if case .switching = self { return true }
        return false
    }
}

/// Owns the account list, the auth vault and the per-account Codex homes.
/// This is the only type that mutates account state; UI reads a snapshot.
final class AccountsService: ObservableObject {
    let paths: AccountPaths
    let vault: AccountVault
    let homeStore: AccountHomeStore

    private let repository: AccountRepository
    private let launcher: CodexLaunching
    private let sessionDetector: CodexSessionDetecting
    private let fileManager: FileManager
    private let defaultCodexHome: URL
    private let legacyRoot: URL?
    private let urlSession: URLSession
    private let usageEndpoint: URL
    private let codexBinaryProvider: () -> URL?
    private var switchCompletionResetTask: Task<Void, Never>?
    private lazy var isolatedLoginService: IsolatedLoginService = IsolatedLoginService(
        rootDirectory: paths.root.appendingPathComponent("PendingLogins", isDirectory: true),
        fileManager: fileManager,
        codexBinaryProvider: codexBinaryProvider
    ) { [weak self] data in
        guard let self else { throw AccountError.accountNotFound }
        return try self.importSession(data)
    }

    @Published private(set) var accounts: [AccountProfile] = []
    @Published private(set) var activeAccountID: UUID?
    @Published private(set) var switchPhase: AccountSwitchPhase = .idle
    @Published private(set) var recentSwitchCompletedAt: Date?
    @Published private(set) var isRefreshingQuotas = false
    @Published private(set) var failedQuotaAccountIDs: Set<UUID> = []
    @Published private(set) var isolatedLoginState = IsolatedLoginState()

    init(
        paths: AccountPaths = .default(),
        launcher: CodexLaunching? = nil,
        sessionDetector: CodexSessionDetecting = NoopCodexSessionDetector(),
        fileManager: FileManager = .default,
        defaultCodexHome: URL? = nil,
        legacyRoot: URL? = nil,
        urlSession: URLSession = CodexUsageClient.defaultSession,
        usageEndpoint: URL = CodexUsageClient.defaultEndpoint,
        codexBinaryProvider: @escaping () -> URL? = { CodexBinaryLocator.locate() }
    ) {
        self.paths = paths
        self.vault = AccountVault(directory: paths.vaultDirectory, fileManager: fileManager)
        self.homeStore = AccountHomeStore(directory: paths.homesDirectory, fileManager: fileManager)
        self.repository = AccountRepository(paths: paths, fileManager: fileManager)
        self.launcher = launcher ?? LiveCodexLauncher()
        self.sessionDetector = sessionDetector
        self.fileManager = fileManager
        self.defaultCodexHome = defaultCodexHome ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
        self.legacyRoot = legacyRoot ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexAccountSwitcher", isDirectory: true)
        self.urlSession = urlSession
        self.usageEndpoint = usageEndpoint
        self.codexBinaryProvider = codexBinaryProvider
    }

    static let shared = AccountsService(sessionDetector: LiveCodexSessionDetector())

    /// All accounts share the original `~/.codex`, so there is no separate
    /// per-account home to report. The notch always reads the default home.
    var activeHomeURL: URL? { nil }

    var sharedAuthURL: URL {
        defaultCodexHome.appendingPathComponent("auth.json")
    }

    /// Called after a successful switch so long-lived observers (the notch
    /// runtime, session monitoring) can re-point at the new Codex home.
    var onActiveAccountChanged: (() -> Void)?

    var activeAccount: AccountProfile? {
        guard let activeAccountID else { return nil }
        return accounts.first { $0.id == activeAccountID }
    }

    func account(withID id: UUID) -> AccountProfile? {
        accounts.first { $0.id == id }
    }

    // MARK: - Loading

    func load() throws {
        try PrivateFileWriter.ensureDirectory(paths.root, fileManager: fileManager)

        var envelope = try repository.load()
        if envelope.accounts.isEmpty {
            let imported = (try? importLegacyAccounts()) ?? []
            if !imported.isEmpty {
                envelope = AccountEnvelope(accounts: imported, activeAccountID: nil)
                try repository.save(envelope)
            }
        }

        var didNormalize = false
        for index in envelope.accounts.indices {
            let fallbackCheckedAt = envelope.accounts[index].lastCheckedAt
            if envelope.accounts[index].quota?.normalizeLegacySingleWindowLayout(
                fallbackCheckedAt: fallbackCheckedAt
            ) == true {
                didNormalize = true
            }
        }
        if didNormalize {
            try? repository.save(envelope)
        }

        accounts = envelope.accounts
        activeAccountID = envelope.activeAccountID.flatMap { id in
            accounts.contains { $0.id == id } ? id : nil
        }
        try reconcileActiveAccount()
        captureActiveAuth()
    }

    private func importLegacyAccounts() throws -> [AccountProfile] {
        guard let legacyRoot else { return [] }
        let reader = LegacySwitcherReader(root: legacyRoot, fileManager: fileManager)
        guard reader.isAvailable else { return [] }

        let legacyAccounts = try reader.readAccounts()
        for account in legacyAccounts {
            guard let data = reader.authData(for: account.id) else { continue }
            try vault.store(data, for: account.id)
        }
        return legacyAccounts
    }

    private func reconcileActiveAccount() throws {
        if let activeAccountID, accounts.contains(where: { $0.id == activeAccountID }) {
            return
        }
        let authURL = defaultCodexHome.appendingPathComponent("auth.json")
        guard
            let data = try? Data(contentsOf: authURL),
            let identity = try? AccountIdentityParser.parse(data),
            let match = match(identity)
        else {
            return
        }
        activeAccountID = match.id
        try persist()
    }

    // MARK: - Switching

    @discardableResult
    @MainActor
    func beginSwitch(to id: UUID, language: AppLanguage = .chinese) -> Task<Void, Never>? {
        guard !switchPhase.isSwitching else { return nil }
        guard accounts.contains(where: { $0.id == id }) else {
            switchPhase = .failed(
                targetID: nil,
                message: Self.sanitizedSwitchErrorMessage(
                    for: AccountError.accountNotFound,
                    language: language
                )
            )
            return nil
        }

        switchCompletionResetTask?.cancel()
        recentSwitchCompletedAt = nil
        switchPhase = .switching(targetID: id)

        return Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.switchTo(id)
                self.switchPhase = .idle
                let completedAt = Date()
                self.recentSwitchCompletedAt = completedAt
                self.switchCompletionResetTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(1.8))
                    guard !Task.isCancelled, let self else { return }
                    if self.recentSwitchCompletedAt == completedAt {
                        self.recentSwitchCompletedAt = nil
                    }
                }
            } catch {
                self.switchPhase = .failed(
                    targetID: id,
                    message: Self.sanitizedSwitchErrorMessage(for: error, language: language)
                )
            }
        }
    }

    @MainActor
    func dismissSwitchError() {
        guard case .failed = switchPhase else { return }
        switchPhase = .idle
    }

    static func sanitizedSwitchErrorMessage(
        for error: Error,
        language: AppLanguage
    ) -> String {
        if let accountError = error as? AccountError {
            switch accountError {
            case .accountNotFound:
                return language.localized(
                    chinese: "该账号已不存在",
                    english: "Account no longer exists"
                )
            case .invalidAuthFile:
                return language.localized(
                    chinese: "认证凭据无效，请重新导入",
                    english: "Invalid auth credentials; please re-import"
                )
            case .authDataMissing:
                return language.localized(
                    chinese: "缺少已保存的登录凭据，请重新导入",
                    english: "Saved credentials missing; please re-import"
                )
            case .launchFailed:
                return language.localized(
                    chinese: "重启 Codex 失败，请重试",
                    english: "Failed to relaunch Codex"
                )
            case .legacyImportFailed:
                return language.localized(
                    chinese: "账号数据读取失败",
                    english: "Could not read account data"
                )
            case .externalSessionsRunning(let count):
                return language.localized(
                    chinese: "检测到 \(count) 个 Codex CLI/IDE 会话，请先结束它们再切换",
                    english: "\(count) Codex CLI/IDE session(s) are running; end them first"
                )
            }
        }
        return language.localized(
            chinese: "切换失败，请重试或前往设置检查",
            english: "Switch failed; retry or check Settings"
        )
    }

    /// Switches the shared `~/.codex` account.
    ///
    /// Ordering matters: Codex is quit first so the renderer/app-server flush
    /// any rotated token, then the freshest auth payload is captured into the
    /// vault, then the target auth is written and the project continuation
    /// state is synchronized before Codex relaunches.
    ///
    /// `force` bypasses the external-session guard (CLI/IDE processes that
    /// would otherwise race on `auth.json`). The UI only passes `true` after
    /// showing the detected sessions to the user.
    func switchTo(_ id: UUID, force: Bool = false) async throws {
        guard accounts.contains(where: { $0.id == id }) else {
            throw AccountError.accountNotFound
        }

        if !force {
            let sessions = sessionDetector.externalSessions()
            if !sessions.isEmpty {
                throw AccountError.externalSessionsRunning(sessions.count)
            }
        }

        let sourceAuthURL = sharedAuthURL
        var sourceAuthData = try? Data(contentsOf: sourceAuthURL)

        // Safety net in case quitting fails before the authoritative capture.
        captureActiveAuth()

        await launcher.quit()
        if let postQuitAuthData = try? Data(contentsOf: sourceAuthURL) {
            if let existingSource = sourceAuthData {
                if AccountAuthFreshness.shouldReplace(
                    existing: existingSource,
                    with: postQuitAuthData,
                    preferCandidateOnTie: true
                ) {
                    sourceAuthData = postQuitAuthData
                }
            } else {
                sourceAuthData = postQuitAuthData
            }
        }
        let sourceIdentity = sourceAuthData.flatMap { try? AccountIdentityParser.parse($0) }
        captureActiveAuth()

        let authData = try authDataForLaunch(id)
        let targetIdentity = try AccountIdentityParser.parse(authData)

        do {
            try PrivateFileWriter.write(authData, to: sourceAuthURL, fileManager: fileManager)
            _ = try? SidebarProjectSynchronizer.synchronizeCodexHome(
                defaultCodexHome,
                sourceIdentity: sourceIdentity,
                targetIdentity: targetIdentity,
                fileManager: fileManager
            )
            try await launcher.launchShared()
        } catch {
            // Codex is already closed and auth.json may point at the target.
            // Restore the previous credentials and bring the old session back
            // so a failed switch never leaves the user without Codex.
            if let sourceAuthData {
                try? PrivateFileWriter.write(
                    sourceAuthData,
                    to: sourceAuthURL,
                    fileManager: fileManager
                )
            }
            try? await launcher.launchShared()
            throw error
        }

        try await MainActor.run {
            guard let index = accounts.firstIndex(where: { $0.id == id }) else {
                throw AccountError.accountNotFound
            }
            activeAccountID = id
            accounts[index].lastUsedAt = .now
            try persist()
            onActiveAccountChanged?()
        }
    }

    /// Persists the tokens the running Codex refreshed inside `~/.codex`
    /// without ever downgrading a fresher Vault copy.
    private func captureActiveAuth() {
        guard let data = try? Data(contentsOf: sharedAuthURL),
              let identity = try? AccountIdentityParser.parse(data),
              let profile = match(identity) else {
            return
        }
        syncVaultIfFresher(data, for: profile.id, preferCandidateOnTie: true)
    }

    private func syncVaultIfFresher(
        _ candidate: Data,
        for id: UUID,
        preferCandidateOnTie: Bool
    ) {
        if let existing = try? vault.retrieve(id) {
            guard AccountAuthFreshness.shouldReplace(
                existing: existing,
                with: candidate,
                preferCandidateOnTie: preferCandidateOnTie
            ) else {
                return
            }
        }
        try? vault.store(candidate, for: id)
    }

    private func authDataForLaunch(_ id: UUID) throws -> Data {
        do {
            return try vault.retrieve(id)
        } catch {
            throw AccountError.authDataMissing(displayName(for: id))
        }
    }

    // MARK: - Import / export

    @discardableResult
    func importSession(_ data: Data) throws -> AccountProfile {
        let identity = try AccountIdentityParser.parse(data)
        let profile: AccountProfile

        if let index = accounts.firstIndex(where: { matches(identity, $0) }) {
            var updated = accounts[index]
            apply(identity, to: &updated)
            updated.importedAt = .now
            updated.availabilityStatus = .available
            accounts[index] = updated
            profile = updated
        } else {
            let created = AccountProfile(
                displayName: suggestedName(for: identity),
                email: identity.email,
                accountIdentifier: identity.accountIdentifier,
                planType: identity.planType,
                fingerprint: identity.fingerprint,
                availabilityStatus: .available
            )
            accounts.append(created)
            profile = created
        }

        failedQuotaAccountIDs.remove(profile.id)
        try vault.store(data, for: profile.id)
        try persist()
        return profile
    }

    func exportSession(_ id: UUID) throws -> Data {
        guard let profile = account(withID: id) else {
            throw AccountError.accountNotFound
        }
        if let best = sharedAuthDataIfMatching(profile) {
            return best
        }
        return try vault.retrieve(id)
    }

    @MainActor
    func importCurrentCodexSession() throws -> AccountProfile {
        guard let data = try? Data(contentsOf: sharedAuthURL) else {
            throw CodexAuthError.authFileUnavailable
        }
        let profile = try importSession(data)
        Task { @MainActor [weak self] in
            try? await self?.refreshQuota(for: profile.id)
        }
        return profile
    }

    var hasLegacySwitcherData: Bool {
        guard let legacyRoot else { return false }
        return LegacySwitcherReader(root: legacyRoot, fileManager: fileManager).isAvailable
    }

    @MainActor
    @discardableResult
    func importLegacySwitcherAccounts() throws -> Int {
        guard let legacyRoot else { return 0 }
        let reader = LegacySwitcherReader(root: legacyRoot, fileManager: fileManager)
        guard reader.isAvailable else { return 0 }
        let legacyAccounts = try reader.readAccounts()
        var importedIDs: [UUID] = []
        var didModify = false

        for legacy in legacyAccounts {
            guard let data = reader.authData(for: legacy.id),
                  let identity = try? AccountIdentityParser.parse(data) else {
                continue
            }
            if let existingIndex = accounts.firstIndex(where: {
                $0.id == legacy.id || matches(identity, $0)
            }) {
                var updated = accounts[existingIndex]
                if updated.quota == nil, let legacyQuota = legacy.quota {
                    updated.quota = legacyQuota
                    updated.lastCheckedAt = updated.lastCheckedAt ?? legacy.lastCheckedAt
                }
                if updated.note == nil, let legacyNote = legacy.note {
                    updated.note = legacyNote
                }
                if updated != accounts[existingIndex] {
                    accounts[existingIndex] = updated
                    didModify = true
                }
                if !vault.contains(updated.id) {
                    try vault.store(data, for: updated.id)
                }
            } else {
                var newProfile = legacy
                newProfile.availabilityStatus = newProfile.availabilityStatus ?? .available
                accounts.append(newProfile)
                try vault.store(data, for: newProfile.id)
                importedIDs.append(newProfile.id)
                didModify = true
            }
        }

        if didModify {
            try persist()
        }
        if !importedIDs.isEmpty {
            Task { @MainActor [weak self] in
                guard let self else { return }
                for id in importedIDs {
                    try? await self.refreshQuota(for: id)
                }
            }
        }
        return importedIDs.count
    }

    // MARK: - Ephemeral Browser OAuth Login

    @MainActor
    func startWebLogin(language: AppLanguage = .chinese) {
        isolatedLoginState = IsolatedLoginState(phase: .startingServer)
        isolatedLoginService.startLogin(language: language) { [weak self] nextState in
            guard let self else { return }
            self.isolatedLoginState = nextState
            if case let .completed(profile) = nextState.phase {
                Task { @MainActor [weak self] in
                    try? await self?.refreshQuota(for: profile.id)
                }
            }
        }
    }

    @MainActor
    func cancelWebLogin(language: AppLanguage = .chinese) {
        isolatedLoginService.cancel(language: language)
        if isolatedLoginState.phase.isInProgress {
            isolatedLoginState.phase = .cancelled
        }
    }

    @MainActor
    func resetWebLoginState() {
        if !isolatedLoginState.phase.isInProgress {
            isolatedLoginState = IsolatedLoginState()
        }
    }

    // MARK: - Quota

    static func availabilityStatus(for error: Error) -> AccountAvailabilityStatus? {
        if let usageError = error as? CodexUsageError {
            switch usageError {
            case .reauthenticationRequired:
                return .reauthRequired
            case .httpStatus(402), .httpStatus(403):
                return .unavailable
            default:
                return nil
            }
        }
        if let accountError = error as? AccountError {
            switch accountError {
            case .authDataMissing, .invalidAuthFile:
                return .reauthRequired
            default:
                return nil
            }
        }
        if error is CodexAuthError {
            return .reauthRequired
        }
        return nil
    }

    func refreshQuota(for id: UUID) async throws {
        guard accounts.contains(where: { $0.id == id }) else {
            throw AccountError.accountNotFound
        }

        do {
            let data = try quotaAuthData(for: id)
            let identity = try? AccountIdentityParser.parse(data)
            let credentials = try CodexAuthReader.credentials(from: data)
            let snapshot = try await CodexUsageClient(
                credentials: credentials,
                session: urlSession,
                endpoint: usageEndpoint
            ).fetch()

            try await MainActor.run {
                guard let index = accounts.firstIndex(where: { $0.id == id }) else {
                    throw AccountError.accountNotFound
                }
                accounts[index].quota = AccountQuota(
                    snapshot: snapshot,
                    planType: identity?.planType ?? accounts[index].planType
                )
                accounts[index].lastCheckedAt = .now
                accounts[index].availabilityStatus = .available
                if let identity {
                    apply(identity, to: &accounts[index])
                }
                failedQuotaAccountIDs.remove(id)
                try persist()
            }
        } catch {
            let status = Self.availabilityStatus(for: error)
            await MainActor.run {
                if let status, let index = accounts.firstIndex(where: { $0.id == id }) {
                    accounts[index].availabilityStatus = status
                    accounts[index].lastCheckedAt = .now
                    failedQuotaAccountIDs.remove(id)
                    try? persist()
                } else {
                    failedQuotaAccountIDs.insert(id)
                }
            }
            throw error
        }
    }

    @MainActor
    func recordSharedAuthUsageSuccess(
        credentials: CodexCredentials,
        snapshot: UsageSnapshot
    ) {
        guard let index = targetAccountIndex(for: credentials) else { return }
        if accounts[index].id == activeAccountID {
            captureActiveAuth()
        }
        accounts[index].quota = AccountQuota(
            snapshot: snapshot,
            planType: accounts[index].planType
        )
        accounts[index].lastCheckedAt = .now
        accounts[index].availabilityStatus = .available
        failedQuotaAccountIDs.remove(accounts[index].id)
        try? persist()
    }

    @MainActor
    func recordSharedAuthUsageFailure(
        credentials: CodexCredentials?,
        error: Error
    ) {
        guard let status = Self.availabilityStatus(for: error),
              let index = targetAccountIndex(for: credentials) else {
            return
        }
        accounts[index].availabilityStatus = status
        accounts[index].lastCheckedAt = .now
        failedQuotaAccountIDs.remove(accounts[index].id)
        try? persist()
    }

    private func targetAccountIndex(for credentials: CodexCredentials?) -> Int? {
        if let accountID = credentials?.accountID,
           let matched = accounts.firstIndex(where: { $0.accountIdentifier == accountID }) {
            return matched
        }
        if let activeAccountID,
           let activeIndex = accounts.firstIndex(where: { $0.id == activeAccountID }) {
            return activeIndex
        }
        return nil
    }

    @MainActor
    func refreshAllQuotas() async {
        guard !isRefreshingQuotas else { return }
        isRefreshingQuotas = true
        defer { isRefreshingQuotas = false }

        let targetIDs = accounts.map(\.id)
        for id in targetIDs {
            try? await refreshQuota(for: id)
        }
    }

    /// Refreshes every account whose quota is older than `ttl`. The notch calls
    /// this when it opens the account drawer so the list stays current without
    /// continuous background polling.
    @MainActor
    func refreshStaleQuotas(ttl: TimeInterval = 120) async {
        guard !isRefreshingQuotas else { return }
        isRefreshingQuotas = true
        defer { isRefreshingQuotas = false }

        let now = Date()
        let snapshot = accounts
        for account in snapshot {
            let hasCurrentQuotaLayout = account.quota.map {
                $0.windowLayoutVersion == AccountQuota.currentWindowLayoutVersion
            } ?? true
            let checkedAt = account.quota?.checkedAt ?? account.lastCheckedAt
            if let checkedAt,
               now.timeIntervalSince(checkedAt) < ttl,
               hasCurrentQuotaLayout,
               account.isUsableAccount,
               !failedQuotaAccountIDs.contains(account.id) {
                continue
            }
            try? await refreshQuota(for: account.id)
        }
    }

    private func quotaAuthData(for id: UUID) throws -> Data {
        let profile = account(withID: id)
        // The active account's token in the shared home may be newer than the
        // vault copy because Codex refreshes it in place. Promote monotonically
        // when `auth.json` belongs to `id`, and never fall back to a stale
        // vault token once the active account has been observed as signed out
        // with no `~/.codex/auth.json` present.
        if activeAccountID == id {
            if let best = sharedAuthDataIfMatching(profile) {
                return best
            }
            if profile?.availabilityStatus == .reauthRequired,
               !fileManager.fileExists(atPath: sharedAuthURL.path) {
                throw CodexAuthError.authFileUnavailable
            }
        }
        return try vault.retrieve(id)
    }

    private func sharedAuthDataIfMatching(_ profile: AccountProfile?) -> Data? {
        guard let profile,
              let sharedData = try? Data(contentsOf: sharedAuthURL),
              let identity = try? AccountIdentityParser.parse(sharedData),
              matches(identity, profile) else {
            return nil
        }
        syncVaultIfFresher(sharedData, for: profile.id, preferCandidateOnTie: true)
        return (try? vault.retrieve(profile.id)) ?? sharedData
    }

    // MARK: - Editing

    func rename(_ id: UUID, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = accounts.firstIndex(where: { $0.id == id }) else {
            throw AccountError.accountNotFound
        }
        accounts[index].displayName = trimmed
        try persist()
    }

    func updateNote(_ id: UUID, note: String) throws {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else {
            throw AccountError.accountNotFound
        }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        accounts[index].note = trimmed.isEmpty ? nil : trimmed
        try persist()
    }

    func delete(_ id: UUID, removeHome: Bool = true) throws {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else {
            throw AccountError.accountNotFound
        }
        if activeAccountID == id {
            activeAccountID = nil
        }
        failedQuotaAccountIDs.remove(id)
        switch switchPhase {
        case let .switching(targetID) where targetID == id,
             let .failed(targetID?, _) where targetID == id:
            switchPhase = .idle
        default:
            break
        }
        accounts.remove(at: index)
        try? vault.delete(id)
        if removeHome {
            try? homeStore.removeHome(for: id)
        }
        try persist()
    }

    // MARK: - Lookup helpers

    func homeURL(for id: UUID) -> URL {
        defaultCodexHome
    }

    private func match(_ identity: AccountIdentity) -> AccountProfile? {
        if let accountIdentifier = identity.accountIdentifier,
           let profile = accounts.first(where: { $0.accountIdentifier == accountIdentifier }) {
            return profile
        }
        if let profile = accounts.first(where: { $0.fingerprint == identity.fingerprint }) {
            return profile
        }
        if let email = identity.email {
            return accounts.first {
                $0.email?.caseInsensitiveCompare(email) == .orderedSame
            }
        }
        return nil
    }

    private func matches(_ identity: AccountIdentity, _ profile: AccountProfile) -> Bool {
        if let accountIdentifier = identity.accountIdentifier,
           let profileIdentifier = profile.accountIdentifier {
            return accountIdentifier == profileIdentifier
        }
        if identity.fingerprint == profile.fingerprint { return true }
        if let email = identity.email, let profileEmail = profile.email {
            return email.caseInsensitiveCompare(profileEmail) == .orderedSame
        }
        return false
    }

    private func apply(_ identity: AccountIdentity, to profile: inout AccountProfile) {
        profile.email = identity.email ?? profile.email
        profile.accountIdentifier = identity.accountIdentifier ?? profile.accountIdentifier
        profile.planType = identity.planType ?? profile.planType
        profile.fingerprint = identity.fingerprint
    }

    private func suggestedName(for identity: AccountIdentity) -> String {
        if let email = identity.email, let name = email.split(separator: "@").first, !name.isEmpty {
            return String(name)
        }
        return "Codex \(accounts.count + 1)"
    }

    private func displayName(for id: UUID) -> String {
        account(withID: id)?.shortLabel ?? id.uuidString
    }

    private func persist() throws {
        try repository.save(
            AccountEnvelope(
                accounts: accounts,
                activeAccountID: activeAccountID
            )
        )
    }
}
