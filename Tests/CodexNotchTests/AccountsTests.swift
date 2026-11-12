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

    func testSwitchWritesSharedAuthAndRelaunches() async throws {
        let data = makeAuthData(email: "a@example.com", accountID: "acct-a")
        let profile = try service.importSession(data)

        try await service.switchTo(profile.id)

        let sharedAuth = root
            .appendingPathComponent("DefaultCodex", isDirectory: true)
            .appendingPathComponent("auth.json")
        XCTAssertEqual(try Data(contentsOf: sharedAuth), data)
        XCTAssertEqual(launcher.quitCalls, 1)
        XCTAssertEqual(launcher.launchCalls, 1)
        XCTAssertEqual(service.activeAccountID, profile.id)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Accounts/Homes").path
        ))
    }

    func testSwitchCapturesRefreshedSharedAuthIntoTheVault() async throws {
        let original = makeAuthData(email: "a@example.com", accountID: "acct-a", accessToken: "original")
        let profile = try service.importSession(original)
        let refreshed = makeAuthData(email: "a@example.com", accountID: "acct-a", accessToken: "refreshed")

        // Simulate Codex refreshing the token inside the shared home.
        let defaultHome = root.appendingPathComponent("DefaultCodex", isDirectory: true)
        try FileManager.default.createDirectory(at: defaultHome, withIntermediateDirectories: true)
        try refreshed.write(to: defaultHome.appendingPathComponent("auth.json"))

        let other = try service.importSession(
            makeAuthData(email: "b@example.com", accountID: "acct-b")
        )
        try await service.switchTo(other.id)

        XCTAssertEqual(try service.vault.retrieve(profile.id), refreshed)
        XCTAssertEqual(try service.vault.retrieve(other.id), try service.exportSession(other.id))
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

    func testDeleteRemovesVaultAndAccount() async throws {
        let profile = try service.importSession(
            makeAuthData(email: "a@example.com", accountID: "acct-a")
        )
        try await service.switchTo(profile.id)

        try service.delete(profile.id)

        XCTAssertTrue(service.accounts.isEmpty)
        XCTAssertFalse(service.vault.contains(profile.id))
    }

    func testSharedRelaunchDoesNotSetCodexHome() {
        let appURL = URL(fileURLWithPath: "/Applications/Codex.app")
        let args = LiveCodexLauncher.openArguments(appURL: appURL)

        XCTAssertEqual(args, ["-n", appURL.path])
        XCTAssertFalse(args.contains { $0.hasPrefix("CODEX_HOME=") })
    }

    func testAccountListHeightOnlyAppliesWhenThereAreMultipleAccounts() {
        XCTAssertEqual(NotchExpandedLayout.accountListHeight(accountCount: 0), 0)
        XCTAssertEqual(NotchExpandedLayout.accountListHeight(accountCount: 1), 0)
        XCTAssertEqual(NotchExpandedLayout.accountListHeight(accountCount: 4), 140)
    }

    func testExpandedCardReservesRoomForTheAccountList() {
        let withoutAccounts = NotchExpandedLayout.taskContentHeight(conversationCount: 2)
        let withAccounts = NotchExpandedLayout.taskContentHeight(
            conversationCount: 2,
            accountCount: 4
        )
        XCTAssertEqual(withAccounts - withoutAccounts, 140)
    }

    func testSidebarProjectSynchronizerCopiesPoolToEveryAccount() throws {
        let stateURL = root.appendingPathComponent("global-state.json")
        let document: [String: Any] = [
            "local-projects": ["p1": ["name": "skillops"]],
            "project-order": ["p1"],
            "thread-project-assignments": ["t1": ["projectId": "p1"]],
            "electron-account-renderer-state-v1": [
                "owner": "owner-hash",
                "atoms": ["local-document-identity": ["accountId": "a"]],
                "inactive": [
                    "hash-b": ["atoms": ["local-document-identity": ["accountId": "b"]]]
                ]
            ]
        ]
        try JSONSerialization.data(withJSONObject: document).write(to: stateURL)

        let original = try Data(contentsOf: stateURL)
        let updated = try SidebarProjectSynchronizer.synchronize(globalStateURL: stateURL)

        XCTAssertEqual(updated, 2)
        let backupURL = stateURL.appendingPathExtension("pre-sync")
        XCTAssertEqual(try Data(contentsOf: backupURL), original)
        let result = try JSONSerialization.jsonObject(
            with: Data(contentsOf: stateURL)
        ) as? [String: Any]
        let state = result?["electron-account-renderer-state-v1"] as? [String: Any]
        let ownerGlobals = state?["globals"] as? [String: Any]
        XCTAssertEqual((ownerGlobals?["local-projects"] as? [String: Any])?.count, 1)
        let inactive = state?["inactive"] as? [String: [String: Any]]
        let otherGlobals = inactive?["hash-b"]?["globals"] as? [String: Any]
        XCTAssertNotNil(otherGlobals?["thread-project-assignments"])
        XCTAssertEqual((result?["project-order"] as? [String])?.first, "p1")
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
    private(set) var quitCalls = 0
    private(set) var launchCalls = 0

    func quit() async {
        quitCalls += 1
    }

    func launchShared() async throws {
        launchCalls += 1
    }
}
