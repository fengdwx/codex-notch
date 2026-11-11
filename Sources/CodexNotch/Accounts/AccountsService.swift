import Combine
import Foundation

/// Owns the account list, the auth vault and the per-account Codex homes.
/// This is the only type that mutates account state; UI reads a snapshot.
final class AccountsService: ObservableObject {
    let paths: AccountPaths
    let vault: AccountVault
    let homeStore: AccountHomeStore

    private let repository: AccountRepository
    private let launcher: CodexLaunching
    private let fileManager: FileManager
    private let defaultCodexHome: URL
    private let legacyRoot: URL?

    @Published private(set) var accounts: [AccountProfile] = []
    @Published private(set) var activeAccountID: UUID?

    init(
        paths: AccountPaths = .default(),
        launcher: CodexLaunching? = nil,
        fileManager: FileManager = .default,
        defaultCodexHome: URL? = nil,
        legacyRoot: URL? = nil
    ) {
        self.paths = paths
        self.vault = AccountVault(directory: paths.vaultDirectory, fileManager: fileManager)
        self.homeStore = AccountHomeStore(directory: paths.homesDirectory, fileManager: fileManager)
        self.repository = AccountRepository(paths: paths, fileManager: fileManager)
        self.launcher = launcher ?? LiveCodexLauncher()
        self.fileManager = fileManager
        self.defaultCodexHome = defaultCodexHome ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
        self.legacyRoot = legacyRoot ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexAccountSwitcher", isDirectory: true)
    }

    static let shared = AccountsService()

    /// Only report a home once it exists. Before the first switch the running
    /// Codex still uses the legacy `~/.codex`, and the notch must keep reading
    /// that instead of an empty directory.
    var activeHomeURL: URL? {
        guard let activeAccountID, homeStore.hasHome(for: activeAccountID) else {
            return nil
        }
        return homeStore.paths(for: activeAccountID).codexHome
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

        accounts = envelope.accounts
        activeAccountID = envelope.activeAccountID.flatMap { id in
            accounts.contains { $0.id == id } ? id : nil
        }
        try reconcileActiveAccount()
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

    func switchTo(_ id: UUID) async throws {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else {
            throw AccountError.accountNotFound
        }

        try captureActiveAuth()
        let authData = try authDataForLaunch(id)
        let home = try homeStore.ensureHome(
            for: id,
            authData: authData,
            seedFrom: defaultCodexHome
        )

        try await launcher.restart(home: home.codexHome, userData: home.userData)

        activeAccountID = id
        accounts[index].lastUsedAt = .now
        try persist()
        onActiveAccountChanged?()
    }

    /// Persists tokens refreshed inside the currently running account's home
    /// before that process is terminated.
    private func captureActiveAuth() throws {
        if let activeAccountID,
           let data = homeStore.authData(for: activeAccountID) {
            try? vault.store(data, for: activeAccountID)
            return
        }

        // Before the first switch the running Codex still owns ~/.codex, and
        // its auth.json may hold tokens refreshed after the import.
        let legacyAuth = defaultCodexHome.appendingPathComponent("auth.json")
        guard let data = try? Data(contentsOf: legacyAuth),
              let identity = try? AccountIdentityParser.parse(data),
              let profile = match(identity) else {
            return
        }
        try? vault.store(data, for: profile.id)
    }

    private func authDataForLaunch(_ id: UUID) throws -> Data {
        if let data = homeStore.authData(for: id) {
            return data
        }
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
            accounts[index] = updated
            profile = updated
        } else {
            let created = AccountProfile(
                displayName: suggestedName(for: identity),
                email: identity.email,
                accountIdentifier: identity.accountIdentifier,
                planType: identity.planType,
                fingerprint: identity.fingerprint
            )
            accounts.append(created)
            profile = created
        }

        try vault.store(data, for: profile.id)
        try persist()
        return profile
    }

    func exportSession(_ id: UUID) throws -> Data {
        guard let profile = account(withID: id) else {
            throw AccountError.accountNotFound
        }
        if let homeData = homeStore.authData(for: id),
           let identity = try? AccountIdentityParser.parse(homeData),
           matches(identity, profile) {
            try vault.store(homeData, for: id)
            return homeData
        }
        return try vault.retrieve(id)
    }

    // MARK: - Quota

    func refreshQuota(for id: UUID) async throws {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else {
            throw AccountError.accountNotFound
        }

        let data = try quotaAuthData(for: id)
        let identity = try? AccountIdentityParser.parse(data)
        let credentials = try CodexAuthReader.credentials(from: data)
        let snapshot = try await CodexUsageClient(credentials: credentials).fetch()

        accounts[index].quota = AccountQuota(
            snapshot: snapshot,
            planType: identity?.planType ?? accounts[index].planType
        )
        accounts[index].lastCheckedAt = .now
        if let identity {
            apply(identity, to: &accounts[index])
        }
        try persist()
    }

    func refreshAllQuotas() async {
        for account in accounts {
            try? await refreshQuota(for: account.id)
        }
    }

    /// Refreshes every account whose quota is older than `ttl`. The notch calls
    /// this when it expands so the list is current without polling in the
    /// background.
    func refreshStaleQuotas(ttl: TimeInterval = 120) async {
        let now = Date()
        for account in accounts {
            if let checked = account.lastCheckedAt,
               now.timeIntervalSince(checked) < ttl {
                continue
            }
            try? await refreshQuota(for: account.id)
        }
    }

    private func quotaAuthData(for id: UUID) throws -> Data {
        if let homeData = homeStore.authData(for: id) {
            try? vault.store(homeData, for: id)
            return homeData
        }
        return try vault.retrieve(id)
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
        accounts.remove(at: index)
        try? vault.delete(id)
        if removeHome {
            try? homeStore.removeHome(for: id)
        }
        try persist()
    }

    // MARK: - Lookup helpers

    func homeURL(for id: UUID) -> URL {
        homeStore.paths(for: id).codexHome
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
