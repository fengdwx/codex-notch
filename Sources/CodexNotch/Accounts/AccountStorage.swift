import Foundation

enum PrivateFileWriter {
    static func ensureDirectory(
        _ url: URL,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: url.path
        )
    }

    static func write(
        _ data: Data,
        to url: URL,
        fileManager: FileManager = .default
    ) throws {
        try ensureDirectory(url.deletingLastPathComponent(), fileManager: fileManager)
        try data.write(to: url, options: [.atomic])
        try? fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }
}

struct AccountPaths: Equatable, Sendable {
    let root: URL

    var accountsFile: URL { root.appendingPathComponent("accounts.json") }
    var vaultDirectory: URL { root.appendingPathComponent("Vault", isDirectory: true) }
    var homesDirectory: URL { root.appendingPathComponent("Homes", isDirectory: true) }

    static func `default`() -> AccountPaths {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return AccountPaths(
            root: support
                .appendingPathComponent("CodexNotch", isDirectory: true)
                .appendingPathComponent("Accounts", isDirectory: true)
        )
    }
}

/// Stores one raw `auth.json` per account, mirroring the on-disk format the
/// standalone switcher used so existing data can be imported byte-for-byte.
final class AccountVault {
    let directory: URL
    private let fileManager: FileManager

    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    func fileURL(for id: UUID) -> URL {
        directory
            .appendingPathComponent(id.uuidString.lowercased())
            .appendingPathExtension("authdata")
    }

    func contains(_ id: UUID) -> Bool {
        fileManager.fileExists(atPath: fileURL(for: id).path)
    }

    func retrieve(_ id: UUID) throws -> Data {
        let url = fileURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else {
            throw AccountError.authDataMissing(id.uuidString)
        }
        return try Data(contentsOf: url)
    }

    func store(_ data: Data, for id: UUID) throws {
        try PrivateFileWriter.write(data, to: fileURL(for: id), fileManager: fileManager)
    }

    func delete(_ id: UUID) throws {
        let url = fileURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }
}

struct AccountHomePaths: Equatable, Sendable {
    let root: URL
    let codexHome: URL
    let userData: URL
}

/// Each account gets a private `CODEX_HOME` and Electron user-data directory,
/// which is what keeps projects, sessions and quotas from bleeding across
/// accounts.
final class AccountHomeStore {
    let directory: URL
    private let fileManager: FileManager
    private let seedFiles = ["config.toml", "AGENTS.md"]

    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    func paths(for id: UUID) -> AccountHomePaths {
        let root = directory.appendingPathComponent(id.uuidString.lowercased(), isDirectory: true)
        return AccountHomePaths(
            root: root,
            codexHome: root.appendingPathComponent("codex", isDirectory: true),
            userData: root.appendingPathComponent("userdata", isDirectory: true)
        )
    }

    func hasHome(for id: UUID) -> Bool {
        fileManager.fileExists(
            atPath: paths(for: id).codexHome.appendingPathComponent("auth.json").path
        )
    }

    func authData(for id: UUID) -> Data? {
        let url = paths(for: id).codexHome.appendingPathComponent("auth.json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    func storeAuthData(_ data: Data, for id: UUID) throws {
        _ = try AccountIdentityParser.parse(data)
        let url = paths(for: id).codexHome.appendingPathComponent("auth.json")
        try PrivateFileWriter.write(data, to: url, fileManager: fileManager)
    }

    @discardableResult
    func ensureHome(
        for id: UUID,
        authData: Data,
        seedFrom: URL?
    ) throws -> AccountHomePaths {
        let paths = paths(for: id)
        try PrivateFileWriter.ensureDirectory(paths.codexHome, fileManager: fileManager)
        try PrivateFileWriter.ensureDirectory(paths.userData, fileManager: fileManager)

        let authURL = paths.codexHome.appendingPathComponent("auth.json")
        if !fileManager.fileExists(atPath: authURL.path) {
            try PrivateFileWriter.write(authData, to: authURL, fileManager: fileManager)
        }

        if let seedFrom {
            for name in seedFiles {
                let source = seedFrom.appendingPathComponent(name)
                let destination = paths.codexHome.appendingPathComponent(name)
                guard fileManager.fileExists(atPath: source.path),
                      !fileManager.fileExists(atPath: destination.path) else {
                    continue
                }
                try? fileManager.copyItem(at: source, to: destination)
                try? fileManager.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: destination.path
                )
            }
        }
        return paths
    }

    func removeHome(for id: UUID) throws {
        let root = paths(for: id).root
        guard fileManager.fileExists(atPath: root.path) else { return }
        try fileManager.removeItem(at: root)
    }
}

final class AccountRepository {
    let paths: AccountPaths
    private let fileManager: FileManager

    init(paths: AccountPaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    func load() throws -> AccountEnvelope {
        guard fileManager.fileExists(atPath: paths.accountsFile.path) else {
            return AccountEnvelope()
        }
        let data = try Data(contentsOf: paths.accountsFile)
        return try Self.decoder.decode(AccountEnvelope.self, from: data)
    }

    func save(_ envelope: AccountEnvelope) throws {
        let data = try Self.encoder.encode(envelope)
        try PrivateFileWriter.write(data, to: paths.accountsFile, fileManager: fileManager)
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

/// Reads the legacy standalone switcher data so existing accounts can be
/// adopted without a new OAuth round trip.
struct LegacySwitcherReader {
    let root: URL
    private let fileManager: FileManager

    init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    var accountsFile: URL { root.appendingPathComponent("accounts.json") }
    var vaultDirectory: URL { root.appendingPathComponent("AuthVault", isDirectory: true) }

    var isAvailable: Bool {
        fileManager.fileExists(atPath: accountsFile.path)
    }

    func readAccounts() throws -> [AccountProfile] {
        let data = try Data(contentsOf: accountsFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AccountEnvelope.self, from: data).accounts
    }

    func authData(for id: UUID) -> Data? {
        let url = vaultDirectory
            .appendingPathComponent(id.uuidString.lowercased())
            .appendingPathExtension("authdata")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }
}
