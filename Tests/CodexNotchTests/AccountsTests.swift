import Foundation
import XCTest
@testable import CodexNotch

@MainActor
final class AccountsTests: XCTestCase {
    private var root: URL!
    private var service: AccountsService!
    private var launcher: FakeCodexLauncher!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexnotch-accounts-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        launcher = FakeCodexLauncher()
        service = AccountsService(
            paths: AccountPaths(root: root.appendingPathComponent("Accounts", isDirectory: true)),
            launcher: launcher,
            defaultCodexHome: root.appendingPathComponent("DefaultCodex", isDirectory: true),
            legacyRoot: root.appendingPathComponent("Legacy", isDirectory: true)
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testImportSessionCreatesAccountAndStoresVault() throws {
        let data = makeAuthData(email: "a@example.com", accountID: "acct-a", plan: "plus")

        let profile = try service.importSession(data)

        XCTAssertEqual(service.accounts.count, 1)
        XCTAssertEqual(profile.email, "a@example.com")
        XCTAssertEqual(profile.planType, "plus")
        XCTAssertTrue(service.vault.contains(profile.id))
        XCTAssertEqual(try service.vault.retrieve(profile.id), data)
    }

    func testImportSameAccountUpdatesInsteadOfDuplicating() throws {
        let first = makeAuthData(email: "a@example.com", accountID: "acct-a", accessToken: "one")
        let second = makeAuthData(email: "a@example.com", accountID: "acct-a", accessToken: "two")

        _ = try service.importSession(first)
        let updated = try service.importSession(second)

        XCTAssertEqual(service.accounts.count, 1)
        XCTAssertEqual(try service.vault.retrieve(updated.id), second)
    }

    func testSwitchSeedsHomeAndLaunchesWithIsolation() async throws {
        let data = makeAuthData(email: "a@example.com", accountID: "acct-a")
        let profile = try service.importSession(data)

        try await service.switchTo(profile.id)

        let home = service.homeStore.paths(for: profile.id)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: home.codexHome.appendingPathComponent("auth.json").path
        ))
        XCTAssertEqual(launcher.calls.count, 1)
        XCTAssertEqual(launcher.calls[0].home, home.codexHome)
        XCTAssertEqual(launcher.calls[0].userData, home.userData)
        XCTAssertEqual(service.activeAccountID, profile.id)
    }

    func testSwitchPrefersRefreshedHomeTokenOverVault() async throws {
        let original = makeAuthData(email: "a@example.com", accountID: "acct-a", accessToken: "original")
        let profile = try service.importSession(original)
        let refreshed = makeAuthData(email: "a@example.com", accountID: "acct-a", accessToken: "refreshed")

        // Simulate Codex refreshing the token inside its own home.
        let home = try service.homeStore.ensureHome(
            for: profile.id,
            authData: original,
            seedFrom: nil
        )
        try service.homeStore.storeAuthData(refreshed, for: profile.id)

        try await service.switchTo(profile.id)

        let launchedArgs = FakeCodexLauncher.lastArguments
        XCTAssertTrue(launchedArgs.contains("CODEX_HOME=\(home.codexHome.path)"))
        XCTAssertTrue(launchedArgs.contains("CODEX_ELECTRON_USER_DATA_PATH=\(home.userData.path)"))
        XCTAssertEqual(try service.exportSession(profile.id), refreshed)
    }

    func testLoadImportsLegacySwitcherData() throws {
        let legacyID = UUID()
        let legacyRoot = root.appendingPathComponent("Legacy", isDirectory: true)
        let vault = legacyRoot.appendingPathComponent("AuthVault", isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)

        let data = makeAuthData(email: "legacy@example.com", accountID: "acct-legacy")
        try data.write(to: vault
            .appendingPathComponent(legacyID.uuidString.lowercased())
            .appendingPathExtension("authdata"))

        let accounts = AccountEnvelope(
            accounts: [
                AccountProfile(
                    id: legacyID,
                    displayName: "legacy",
                    email: "legacy@example.com",
                    accountIdentifier: "acct-legacy",
                    planType: "pro",
                    fingerprint: AccountIdentityParser.fingerprint("legacy")
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(accounts).write(to: legacyRoot.appendingPathComponent("accounts.json"))

        try service.load()

        XCTAssertEqual(service.accounts.count, 1)
        XCTAssertEqual(service.accounts.first?.id, legacyID)
        XCTAssertEqual(try service.vault.retrieve(legacyID), data)
    }

    func testActiveAccountResolvesFromDefaultAuthFile() throws {
        let data = makeAuthData(email: "a@example.com", accountID: "acct-a")
        let profile = try service.importSession(data)

        let defaultHome = root.appendingPathComponent("DefaultCodex", isDirectory: true)
        try FileManager.default.createDirectory(at: defaultHome, withIntermediateDirectories: true)
        try data.write(to: defaultHome.appendingPathComponent("auth.json"))

        try service.load()

        XCTAssertEqual(service.activeAccountID, profile.id)
    }

    func testDeleteRemovesVaultAndHome() async throws {
        let profile = try service.importSession(
            makeAuthData(email: "a@example.com", accountID: "acct-a")
        )
        try await service.switchTo(profile.id)
        let home = service.homeStore.paths(for: profile.id)

        try service.delete(profile.id)

        XCTAssertTrue(service.accounts.isEmpty)
        XCTAssertFalse(service.vault.contains(profile.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.root.path))
    }

    func testOpenArgumentsCarryBothIsolationVariables() {
        let appURL = URL(fileURLWithPath: "/Applications/Codex.app")
        let home = URL(fileURLWithPath: "/tmp/home")
        let userData = URL(fileURLWithPath: "/tmp/userdata")

        let args = LiveCodexLauncher.openArguments(appURL: appURL, home: home, userData: userData)

        XCTAssertTrue(args.contains("CODEX_HOME=/tmp/home"))
        XCTAssertTrue(args.contains("CODEX_ELECTRON_USER_DATA_PATH=/tmp/userdata"))
        XCTAssertTrue(args.contains("--user-data-dir=/tmp/userdata"))
        XCTAssertEqual(args.first, "-n")
    }

    func testAccountListHeightOnlyAppliesWhenThereAreMultipleAccounts() {
        XCTAssertEqual(NotchExpandedLayout.accountListHeight(accountCount: 1), 0)
        XCTAssertEqual(
            NotchExpandedLayout.accountListHeight(accountCount: 4),
            12 + NotchExpandedLayout.accountListHeaderHeight
                + 4 * NotchExpandedLayout.accountRowHeight
        )
    }

    func testExpandedCardReservesRoomForTheAccountList() {
        let withoutAccounts = NotchExpandedLayout.taskContentHeight(conversationCount: 2)
        let withAccounts = NotchExpandedLayout.taskContentHeight(
            conversationCount: 2,
            accountCount: 4
        )
        XCTAssertEqual(
            withAccounts - withoutAccounts,
            NotchExpandedLayout.accountListHeight(accountCount: 4)
        )
    }

    // MARK: - Fixtures

    private func makeAuthData(
        email: String,
        accountID: String,
        plan: String = "plus",
        accessToken: String = "access-token"
    ) -> Data {
        let payload: [String: Any] = [
            "email": email,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": accountID,
                "chatgpt_plan_type": plan
            ]
        ]
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        let payloadSegment = payloadData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let idToken = "e30.\(payloadSegment).signature"
        let object: [String: Any] = [
            "auth_mode": "chatgpt",
            "tokens": [
                "id_token": idToken,
                "access_token": accessToken,
                "refresh_token": "refresh-token",
                "account_id": accountID
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: object)
    }
}

final class FakeCodexLauncher: CodexLaunching {
    struct Call: Equatable {
        let home: URL
        let userData: URL
    }

    private(set) var calls: [Call] = []
    static var lastArguments: [String] = []

    func restart(home: URL, userData: URL) async throws {
        calls.append(Call(home: home, userData: userData))
        Self.lastArguments = LiveCodexLauncher.openArguments(
            appURL: URL(fileURLWithPath: "/Applications/Codex.app"),
            home: home,
            userData: userData
        )
    }
}
