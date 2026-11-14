import CryptoKit
import Foundation
import SQLite3
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
        XCTAssertEqual(NotchExpandedLayout.accountListHeight(accountCount: 4), 44)
    }

    func testExpandedCardReservesRoomForTheAccountAnchorAndDrawer() {
        let withoutAccounts = NotchExpandedLayout.taskContentHeight(conversationCount: 2)
        let withAccountsCollapsed = NotchExpandedLayout.taskContentHeight(
            conversationCount: 2,
            accountCount: 4
        )
        let withAccountsExpanded = NotchExpandedLayout.taskContentHeight(
            conversationCount: 2,
            accountCount: 4,
            isAccountDrawerExpanded: true,
            displayedAccountCount: 4
        )
        XCTAssertEqual(withAccountsCollapsed - withoutAccounts, 44)
        XCTAssertEqual(withAccountsExpanded - withoutAccounts, 263)
    }

    func testBeginSwitchTransitionsPhaseGuardsConcurrencyAndSanitizesErrors() async throws {
        let a = try service.importSession(makeAuthData(email: "a@example.com", accountID: "acct-a"))
        let b = try service.importSession(makeAuthData(email: "b@example.com", accountID: "acct-b"))
        let c = try service.importSession(makeAuthData(email: "c@example.com", accountID: "acct-c"))

        let gatedLauncher = GatedCodexLauncher()
        let gatedService = AccountsService(
            paths: AccountPaths(root: root.appendingPathComponent("GatedAccounts", isDirectory: true)),
            launcher: gatedLauncher,
            defaultCodexHome: root.appendingPathComponent("GatedDefaultCodex", isDirectory: true),
            legacyRoot: root.appendingPathComponent("GatedLegacy", isDirectory: true)
        )
        let gA = try gatedService.importSession(makeAuthData(email: "ga@example.com", accountID: "acct-ga"))
        let gB = try gatedService.importSession(makeAuthData(email: "gb@example.com", accountID: "acct-gb"))
        let gC = try gatedService.importSession(makeAuthData(email: "gc@example.com", accountID: "acct-gc"))
        try await gatedService.switchTo(gA.id)

        // Start a slow switch and verify phase becomes .switching and concurrent beginSwitch is ignored.
        await gatedLauncher.setGateQuit(true)
        let task = gatedService.beginSwitch(to: gB.id, language: .chinese)
        XCTAssertNotNil(task)
        XCTAssertEqual(gatedService.switchPhase, .switching(targetID: gB.id))

        await gatedLauncher.waitUntilQuitEntered()
        let duplicate = gatedService.beginSwitch(to: gC.id, language: .chinese)
        XCTAssertNil(duplicate)

        await gatedLauncher.resume()
        await task?.value

        XCTAssertEqual(gatedService.switchPhase, .idle)
        XCTAssertEqual(gatedService.activeAccountID, gB.id)
        XCTAssertNotNil(gatedService.recentSwitchCompletedAt)

        // Trigger a launch failure containing sensitive secret/path text and ensure sanitized UI error.
        await gatedLauncher.setNextError(AccountError.launchFailed("/Users/alice/.codex/auth.json secret_token_xyz"))
        let failedTask = gatedService.beginSwitch(to: gA.id, language: .english)
        await failedTask?.value

        guard case let .failed(targetID, message) = gatedService.switchPhase else {
            return XCTFail("Expected .failed phase after launch failure")
        }
        XCTAssertEqual(targetID, gA.id)
        XCTAssertFalse(message.contains("/Users"))
        XCTAssertFalse(message.contains("auth.json"))
        XCTAssertFalse(message.contains("secret_token_xyz"))

        gatedService.dismissSwitchError()
        XCTAssertEqual(gatedService.switchPhase, .idle)
        _ = (a, b, c)
    }

    func testPickerFilterModesSortLowQuotaCueAndEmptyGuard() throws {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let p1 = AccountProfile(
            displayName: "main",
            email: "main@studio.dev",
            fingerprint: "f1",
            lastUsedAt: now.addingTimeInterval(-300),
            quota: AccountQuota(primaryUsedPercent: 85, secondaryUsedPercent: 85, checkedAt: now) // 15% remaining
        )
        let p2 = AccountProfile(
            displayName: "reserve-high",
            fingerprint: "f2",
            lastUsedAt: now.addingTimeInterval(-7200),
            quota: AccountQuota(primaryUsedPercent: 4, secondaryUsedPercent: 12, checkedAt: now) // 88% min
        )
        let p3 = AccountProfile(
            displayName: "exhausted",
            fingerprint: "f3",
            lastUsedAt: now.addingTimeInterval(-60),
            quota: AccountQuota(primaryUsedPercent: 95, secondaryUsedPercent: 92, checkedAt: now) // 5% min -> hidden
        )
        let p4 = AccountProfile(
            displayName: "fresh-standby",
            fingerprint: "f4",
            lastUsedAt: now.addingTimeInterval(-1800),
            quota: AccountQuota(primaryUsedPercent: 4, secondaryUsedPercent: 4, checkedAt: now) // 96% min -> best!
        )
        let p5 = AccountProfile(
            displayName: "mid",
            fingerprint: "f5",
            quota: AccountQuota(primaryUsedPercent: 30, secondaryUsedPercent: 50, checkedAt: now) // 50% min
        )

        let accounts = [p1, p2, p3, p4, p5]
        let availableSnapshot = AccountPickerLogic.snapshot(
            accounts: accounts,
            activeAccountID: p1.id,
            filter: .availableFirst
        )
        XCTAssertEqual(availableSnapshot.totalCount, 5)
        XCTAssertEqual(availableSnapshot.availableCount, 4)
        XCTAssertEqual(availableSnapshot.displayedAccounts.map(\.id), [p4.id, p2.id, p5.id, p1.id])
        XCTAssertTrue(availableSnapshot.shouldShowLowQuotaCue)
        XCTAssertEqual(availableSnapshot.bestStandbyAccount?.id, p4.id)
        XCTAssertEqual(availableSnapshot.bestStandbyRemainingPercent ?? 0, 96, accuracy: 0.1)

        let recentSnapshot = AccountPickerLogic.snapshot(
            accounts: accounts,
            activeAccountID: p1.id,
            filter: .recentUsed
        )
        XCTAssertEqual(recentSnapshot.displayedAccounts.map(\.id), [p3.id, p1.id, p4.id, p2.id, p5.id])

        let allSnapshot = AccountPickerLogic.snapshot(
            accounts: accounts,
            activeAccountID: p1.id,
            filter: .all
        )
        XCTAssertEqual(allSnapshot.displayedAccounts.map(\.id), [p1.id, p2.id, p3.id, p4.id, p5.id])

        // Empty available pool guard: all accounts <= 10% left.
        let exhaustedPool = accounts.map { profile in
            var copy = profile
            copy.quota = AccountQuota(primaryUsedPercent: 94, secondaryUsedPercent: 96, checkedAt: now)
            return copy
        }
        let emptyAvailable = AccountPickerLogic.snapshot(
            accounts: exhaustedPool,
            activeAccountID: p1.id,
            filter: .availableFirst
        )
        XCTAssertEqual(emptyAvailable.availableCount, 0)
        XCTAssertTrue(emptyAvailable.displayedAccounts.isEmpty)

        // Persistence check using isolated defaults suite.
        let suiteName = "AccountPickerFilterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        AccountPickerFilter.recentUsed.save(to: defaults)
        XCTAssertEqual(AccountPickerFilter.read(from: defaults), .recentUsed)
    }

    func testHoverPreviewResolverLocksConfirmationAndPreservesFiveHourSlotRule() {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let credit = ResetCredit(id: "cred-1", expiresAt: now.addingTimeInterval(3600))
        let activeWithFiveHour = UsageSnapshot(
            windows: [
                UsageWindow(id: "primary", kind: .rolling(hours: 5), usedPercent: 60, resetAt: now.addingTimeInterval(1800)),
                UsageWindow(id: "secondary", kind: .weekly, usedPercent: 80, resetAt: now.addingTimeInterval(86400))
            ],
            resetCreditsAvailable: 1,
            resetCredits: [credit],
            fetchedAt: now
        )
        let activeWeeklyOnly = UsageSnapshot(
            windows: [
                UsageWindow(id: "secondary", kind: .weekly, usedPercent: 75, resetAt: now.addingTimeInterval(86400))
            ],
            resetCreditsAvailable: 2,
            resetCredits: [credit],
            fetchedAt: now
        )

        let activeProfile = AccountProfile(displayName: "active", fingerprint: "a")
        let standbyNoFiveHour = AccountProfile(
            displayName: "pro-no-5h",
            fingerprint: "b",
            quota: AccountQuota(primaryUsedPercent: nil, secondaryUsedPercent: 10, checkedAt: now)
        )
        let standbyWithFiveHour = AccountProfile(
            displayName: "plus-with-5h",
            fingerprint: "c",
            quota: AccountQuota(primaryUsedPercent: 18, secondaryUsedPercent: 12, checkedAt: now)
        )
        let pool = [activeProfile, standbyNoFiveHour, standbyWithFiveHour]

        // Active with 5h hovering standby without 5h keeps 5h row height locked and keeps active's reset credits.
        let lockHeightState = AccountPreviewResolver.resolve(
            activeUsage: activeWithFiveHour,
            accounts: pool,
            activeAccountID: activeProfile.id,
            hoveredAccountID: standbyNoFiveHour.id,
            selectedAccountIDForSwitch: nil,
            isDrawerExpanded: true
        )
        XCTAssertEqual(lockHeightState.previewAccount?.id, standbyNoFiveHour.id)
        XCTAssertTrue(lockHeightState.locksFiveHourRow)
        XCTAssertNil(lockHeightState.displayedUsage?.fiveHourWindow)
        XCTAssertEqual(lockHeightState.displayedUsage?.weeklyWindow?.remainingPercent ?? 0, 90, accuracy: 0.1)
        XCTAssertEqual(lockHeightState.displayedUsage?.resetCredits, [credit])
        XCTAssertFalse(lockHeightState.isLockedConfirmation)

        // Active without 5h hovering standby with 5h keeps row count intact and exposes inline 5h cue.
        let inlineFiveHourState = AccountPreviewResolver.resolve(
            activeUsage: activeWeeklyOnly,
            accounts: pool,
            activeAccountID: activeProfile.id,
            hoveredAccountID: standbyWithFiveHour.id,
            selectedAccountIDForSwitch: nil,
            isDrawerExpanded: true
        )
        XCTAssertFalse(inlineFiveHourState.locksFiveHourRow)
        XCTAssertEqual(inlineFiveHourState.inlineFiveHourPercent ?? 0, 82, accuracy: 0.1)

        // Selection locks preview until another card is hovered or drawer closes.
        let lockedSelection = AccountPreviewResolver.resolve(
            activeUsage: activeWithFiveHour,
            accounts: pool,
            activeAccountID: activeProfile.id,
            hoveredAccountID: nil,
            selectedAccountIDForSwitch: standbyWithFiveHour.id,
            isDrawerExpanded: true
        )
        XCTAssertEqual(lockedSelection.previewAccount?.id, standbyWithFiveHour.id)
        XCTAssertTrue(lockedSelection.isLockedConfirmation)

        let collapsedReset = AccountPreviewResolver.resolve(
            activeUsage: activeWithFiveHour,
            accounts: pool,
            activeAccountID: activeProfile.id,
            hoveredAccountID: standbyWithFiveHour.id,
            selectedAccountIDForSwitch: standbyWithFiveHour.id,
            isDrawerExpanded: false
        )
        XCTAssertNil(collapsedReset.previewAccount)
        XCTAssertEqual(collapsedReset.displayedUsage, activeWithFiveHour)
    }

    func testProfileMonogramSubtitleDedupAndStaleness() {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let profile = AccountProfile(
            displayName: "work",
            email: "work",
            accountIdentifier: "acct-work",
            fingerprint: "fp-1",
            note: "主账号",
            lastCheckedAt: now.addingTimeInterval(-3_601),
            lastUsedAt: now.addingTimeInterval(-180),
            quota: AccountQuota(primaryUsedPercent: 10, secondaryUsedPercent: 10, checkedAt: now.addingTimeInterval(-3_601))
        )

        XCTAssertEqual(profile.monogramCharacter, "W")
        XCTAssertTrue((0..<6).contains(profile.monogramPaletteIndex))
        XCTAssertEqual(
            profile.monogramPaletteIndex,
            AccountProfile(displayName: "other", accountIdentifier: "acct-work", fingerprint: "fp-1").monogramPaletteIndex
        )
        XCTAssertEqual(profile.subtitleText, "主账号")
        XCTAssertTrue(profile.isStaleQuota(at: now))

        let supportProfile = AccountProfile(
            displayName: "support",
            email: "support@example.com",
            fingerprint: "fp-support",
            lastUsedAt: now.addingTimeInterval(-2 * 86_400)
        )
        XCTAssertEqual(supportProfile.subtitleText, "support@example.com")

        var fresh = profile
        fresh.quota?.checkedAt = now.addingTimeInterval(-120)
        fresh.lastCheckedAt = now.addingTimeInterval(-120)
        XCTAssertFalse(fresh.isStaleQuota(at: now))
        XCTAssertTrue(fresh.isStaleQuota(at: now, failedIDs: [fresh.id]))
    }

    func testQuotaConciseResetTextRevealsFiveHourResetOnlyWhenConsumed() {
        let gmt = TimeZone(secondsFromGMT: 0)!
        let primaryReset = ISO8601DateFormatter().date(from: "2026-11-15T02:30:00Z")!
        let weeklyReset = ISO8601DateFormatter().date(from: "2026-11-21T15:00:00Z")!

        // Full 100% (even 99.8 rounded to 100%) suppresses rolling 5h placeholder and shows full 7d reset
        let fullFiveHourQuota = AccountQuota(
            primaryUsedPercent: 0.2,
            primaryResetsAt: primaryReset,
            secondaryUsedPercent: 15,
            secondaryResetsAt: weeklyReset
        )
        XCTAssertEqual(fullFiveHourQuota.conciseResetText(language: .chinese, timeZone: gmt), "11-21 15:00 重置")
        XCTAssertEqual(fullFiveHourQuota.conciseResetText(language: .english, timeZone: gmt), "Resets 11-21 15:00")

        // Consumed 5h (< 100%) reveals compact side-by-side 5h HH:mm and 7d MM-dd
        let consumedFiveHourQuota = AccountQuota(
            primaryUsedPercent: 40,
            primaryResetsAt: primaryReset,
            secondaryUsedPercent: 15,
            secondaryResetsAt: weeklyReset
        )
        XCTAssertEqual(consumedFiveHourQuota.conciseResetText(language: .chinese, timeZone: gmt), "5h 02:30 · 7d 11-21")
        XCTAssertEqual(consumedFiveHourQuota.conciseResetText(language: .english, timeZone: gmt), "5h 02:30 · 7d 11-21")

        // Single-window consumed 5h shows 5h HH:mm reset
        let fiveHourOnlyConsumed = AccountQuota(
            primaryUsedPercent: 60,
            primaryResetsAt: primaryReset
        )
        XCTAssertEqual(fiveHourOnlyConsumed.conciseResetText(language: .chinese, timeZone: gmt), "5h 02:30 重置")
        XCTAssertEqual(fiveHourOnlyConsumed.conciseResetText(language: .english, timeZone: gmt), "Resets 5h 02:30")

        // Weekly-only (e.g. support) keeps 7d date-time reset
        let weeklyOnlyQuota = AccountQuota(
            secondaryUsedPercent: 20,
            secondaryResetsAt: weeklyReset
        )
        XCTAssertEqual(weeklyOnlyQuota.conciseResetText(language: .chinese, timeZone: gmt), "11-21 15:00 重置")
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

    func testAccountIdentityComputesCodexCompatibleOwnerHash() throws {
        let authData = makeAuthData(
            email: "alice@example.com",
            accountID: "acct/1",
            userID: "user-1"
        )
        let identity = try AccountIdentityParser.parse(authData)

        let expectedInput = "[\"user-1\",\"acct/1\"]"
        let expectedHash = SHA256.hash(data: Data(expectedInput.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        XCTAssertEqual(identity.userIdentifier, "user-1")
        XCTAssertEqual(identity.ownerHash, expectedHash)
    }

    func testSidebarProjectSynchronizerPropagatesModernOwnerContinuationAndNewTaskProject() throws {
        let codexHome = root.appendingPathComponent("ModernCodex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        let stateURL = codexHome.appendingPathComponent(".codex-global-state.json")

        let sourceID = try AccountIdentityParser.parse(
            makeAuthData(email: "a@example.com", accountID: "acct-a", userID: "user-a")
        )
        let existingOtherID = try AccountIdentityParser.parse(
            makeAuthData(email: "b@example.com", accountID: "acct-b", userID: "user-b")
        )
        let brandNewTargetID = try AccountIdentityParser.parse(
            makeAuthData(email: "c@example.com", accountID: "acct-c", userID: "user-c")
        )

        let ownerA = try XCTUnwrap(sourceID.ownerHash)
        let ownerB = try XCTUnwrap(existingOtherID.ownerHash)
        let ownerC = try XCTUnwrap(brandNewTargetID.ownerHash)

        let sourceTupleKey = try XCTUnwrap(AccountIdentity.jsonTupleKey(["acct-a", "user-a", "local"]))
        let otherTupleKey = try XCTUnwrap(AccountIdentity.jsonTupleKey(["acct-b", "user-b", "local"]))
        let targetTupleKey = try XCTUnwrap(AccountIdentity.jsonTupleKey(["acct-c", "user-c", "local"]))

        let document: [String: Any] = [
            "electron-renderer-content-owner": ownerA,
            "local-projects": ["open-science": ["path": "/work/open-science"]],
            "electron-owner-value:selected-project:\(ownerA)": [
                "projectId": "open-science",
                "type": "local"
            ],
            "electron-owner-value:active-workspace-roots:\(ownerA)": ["/work/open-science"],
            "electron-owner-value:electron-saved-workspace-roots:\(ownerA)": ["/work/open-science"],
            "electron-owner-value:app-server-pending-project-deletions-by-host:\(ownerA)": ["secret-delete"],
            "electron-owner-atoms:\(ownerA)": [
                "new-task-project-by-computer": [
                    sourceTupleKey: "open-science"
                ],
                "sidebar-width": 280,
                "sidebar-project-expanded-v1-codex:open-science": true,
                "cloud-aeon-profiles-v1:a": ["private-a"]
            ],
            "electron-owner-value:selected-project:\(ownerB)": [
                "projectId": "skillops",
                "type": "local"
            ],
            "electron-account-remote-preference:active-remote-project-id:\(ownerB)": "stale-remote-project",
            "electron-owner-atoms:\(ownerB)": [
                "new-task-project-by-computer": [
                    otherTupleKey: "skillops"
                ],
                "space-page-pin-projection-owners-v1": ["keep-b-pin"],
                "cloud-aeon-profiles-v1:b": ["private-b"]
            ]
        ]
        try JSONSerialization.data(withJSONObject: document).write(to: stateURL)
        let original = try Data(contentsOf: stateURL)

        let updated = try SidebarProjectSynchronizer.synchronizeCodexHome(
            codexHome,
            sourceIdentity: sourceID,
            targetIdentity: brandNewTargetID
        )

        XCTAssertEqual(updated, 2)
        XCTAssertEqual(try Data(contentsOf: stateURL.appendingPathExtension("pre-sync")), original)

        let result = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: stateURL)) as? [String: Any]
        )
        // Must leave active owner intact for Codex's confirmContentOwner transition.
        XCTAssertEqual(result["electron-renderer-content-owner"] as? String, ownerA)

        for destOwner in [ownerB, ownerC] {
            let selected = result["electron-owner-value:selected-project:\(destOwner)"] as? [String: Any]
            XCTAssertEqual(selected?["projectId"] as? String, "open-science")
            XCTAssertEqual(selected?["type"] as? String, "local")
            XCTAssertEqual(
                result["electron-owner-value:active-workspace-roots:\(destOwner)"] as? [String],
                ["/work/open-science"]
            )
            XCTAssertEqual(
                result["electron-owner-value:electron-saved-workspace-roots:\(destOwner)"] as? [String],
                ["/work/open-science"]
            )
            XCTAssertNil(result["electron-owner-value:app-server-pending-project-deletions-by-host:\(destOwner)"])
        }

        XCTAssertNil(result["electron-account-remote-preference:active-remote-project-id:\(ownerB)"])

        let atomsB = result["electron-owner-atoms:\(ownerB)"] as? [String: Any]
        let newTaskB = atomsB?["new-task-project-by-computer"] as? [String: Any]
        XCTAssertEqual(newTaskB?[otherTupleKey] as? String, "open-science")
        XCTAssertEqual(atomsB?["sidebar-width"] as? Int, 280)
        XCTAssertEqual(atomsB?["sidebar-project-expanded-v1-codex:open-science"] as? Bool, true)
        XCTAssertEqual(atomsB?["space-page-pin-projection-owners-v1"] as? [String], ["keep-b-pin"])
        XCTAssertEqual(atomsB?["cloud-aeon-profiles-v1:b"] as? [String], ["private-b"])
        XCTAssertNil(atomsB?["cloud-aeon-profiles-v1:a"])

        let atomsC = result["electron-owner-atoms:\(ownerC)"] as? [String: Any]
        let newTaskC = atomsC?["new-task-project-by-computer"] as? [String: Any]
        XCTAssertEqual(newTaskC?[targetTupleKey] as? String, "open-science")
        XCTAssertEqual(atomsC?["sidebar-width"] as? Int, 280)
        XCTAssertNil(atomsC?["cloud-aeon-profiles-v1:a"])
    }

    func testSidebarProjectSynchronizerBackfillsMissingWorkspaceRoots() throws {
        let codexHome = root.appendingPathComponent("BackfillCodex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        let stateURL = codexHome.appendingPathComponent(".codex-global-state.json")

        let sourceID = try AccountIdentityParser.parse(
            makeAuthData(email: "a@example.com", accountID: "acct-a", userID: "user-a")
        )
        let targetID = try AccountIdentityParser.parse(
            makeAuthData(email: "b@example.com", accountID: "acct-b", userID: "user-b")
        )
        let ownerA = try XCTUnwrap(sourceID.ownerHash)
        let ownerB = try XCTUnwrap(targetID.ownerHash)

        let document: [String: Any] = [
            "electron-renderer-content-owner": ownerA,
            "electron-owner-value:selected-project:\(ownerA)": [
                "projectId": "open-science",
                "type": "local"
            ],
            "electron-owner-value:selected-project:\(ownerB)": [
                "projectId": "skillops",
                "type": "local"
            ],
            "electron-owner-value:active-workspace-roots:\(ownerB)": ["/work/open-science"],
            "electron-owner-value:electron-saved-workspace-roots:\(ownerB)": ["/work/open-science"]
        ]
        try JSONSerialization.data(withJSONObject: document).write(to: stateURL)

        let updated = try SidebarProjectSynchronizer.synchronizeCodexHome(
            codexHome,
            sourceIdentity: sourceID,
            targetIdentity: targetID
        )

        XCTAssertEqual(updated, 1)
        let result = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: stateURL)) as? [String: Any]
        )
        XCTAssertEqual(
            result["electron-owner-value:electron-saved-workspace-roots:\(ownerA)"] as? [String],
            ["/work/open-science"]
        )
        XCTAssertEqual(
            result["electron-owner-value:electron-saved-workspace-roots:\(ownerB)"] as? [String],
            ["/work/open-science"]
        )
        XCTAssertEqual(
            (result["electron-owner-value:selected-project:\(ownerB)"] as? [String: Any])?["projectId"] as? String,
            "open-science"
        )
    }

    func testSwitchAccountSynchronizesProjectContinuationBetweenAccounts() async throws {
        let authA = makeAuthData(email: "a@example.com", accountID: "acct-a", userID: "user-a", accessToken: "tok-a")
        let authB = makeAuthData(email: "b@example.com", accountID: "acct-b", userID: "user-b", accessToken: "tok-b")
        let idA = try AccountIdentityParser.parse(authA)
        let idB = try AccountIdentityParser.parse(authB)
        let ownerA = try XCTUnwrap(idA.ownerHash)
        let ownerB = try XCTUnwrap(idB.ownerHash)

        _ = try service.importSession(authA)
        let acctB = try service.importSession(authB)

        let codexHome = root.appendingPathComponent("DefaultCodex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try authA.write(to: codexHome.appendingPathComponent("auth.json"))

        let sourceTupleKey = try XCTUnwrap(AccountIdentity.jsonTupleKey(["acct-a", "user-a", "local"]))
        let targetTupleKey = try XCTUnwrap(AccountIdentity.jsonTupleKey(["acct-b", "user-b", "local"]))
        let initialState: [String: Any] = [
            "electron-renderer-content-owner": ownerA,
            "electron-owner-value:selected-project:\(ownerA)": [
                "projectId": "codex-notch",
                "type": "local"
            ],
            "electron-owner-value:electron-saved-workspace-roots:\(ownerA)": ["/work/codex-notch"],
            "electron-owner-atoms:\(ownerA)": [
                "new-task-project-by-computer": [
                    sourceTupleKey: "codex-notch"
                ]
            ]
        ]
        let stateURL = codexHome.appendingPathComponent(".codex-global-state.json")
        try JSONSerialization.data(withJSONObject: initialState).write(to: stateURL)

        try await service.switchTo(acctB.id)

        let updatedState = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: stateURL)) as? [String: Any]
        )
        let selectedB = updatedState["electron-owner-value:selected-project:\(ownerB)"] as? [String: Any]
        XCTAssertEqual(selectedB?["projectId"] as? String, "codex-notch")
        let atomsB = updatedState["electron-owner-atoms:\(ownerB)"] as? [String: Any]
        let mapB = atomsB?["new-task-project-by-computer"] as? [String: Any]
        XCTAssertEqual(mapB?[targetTupleKey] as? String, "codex-notch")
    }

    func testSidebarProjectSynchronizerUpdatesActiveSQLiteStore() throws {
        let codexHome = root.appendingPathComponent("SQLiteCodex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        let dbURL = codexHome.appendingPathComponent(".codex-global-state.sqlite")

        let sourceID = try AccountIdentityParser.parse(
            makeAuthData(email: "a@example.com", accountID: "acct-a", userID: "user-a")
        )
        let targetID = try AccountIdentityParser.parse(
            makeAuthData(email: "b@example.com", accountID: "acct-b", userID: "user-b")
        )
        let ownerA = try XCTUnwrap(sourceID.ownerHash)
        let ownerB = try XCTUnwrap(targetID.ownerHash)

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(
            sqlite3_exec(
                db,
                """
                PRAGMA user_version = 1;
                CREATE TABLE settings (scope TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY (scope, key));
                """,
                nil,
                nil,
                nil
            ),
            SQLITE_OK
        )

        let sourceTupleKey = try XCTUnwrap(AccountIdentity.jsonTupleKey(["acct-a", "user-a", "local"]))
        let escapedSeedRows: [(String, String, String)] = [
            ("global", "electron-renderer-content-owner", "\"\(ownerA)\""),
            ("global", "electron-owner-value:selected-project:\(ownerA)", "{\"projectId\":\"open-science\",\"type\":\"local\"}"),
            ("global", "electron-account-remote-preference:active-remote-project-id:\(ownerB)", "\"stale-remote\""),
            (
                "electron-owner-atoms:\(ownerA)",
                "new-task-project-by-computer",
                String(
                    data: try JSONSerialization.data(
                        withJSONObject: [sourceTupleKey: "open-science"],
                        options: [.withoutEscapingSlashes]
                    ),
                    encoding: .utf8
                )!
            )
        ]

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var insertStmt: OpaquePointer?
        XCTAssertEqual(
            sqlite3_prepare_v2(db, "INSERT INTO settings(scope, key, value) VALUES (?, ?, ?)", -1, &insertStmt, nil),
            SQLITE_OK
        )
        for (scope, key, value) in escapedSeedRows {
            sqlite3_reset(insertStmt)
            sqlite3_bind_text(insertStmt, 1, scope, -1, transient)
            sqlite3_bind_text(insertStmt, 2, key, -1, transient)
            sqlite3_bind_text(insertStmt, 3, value, -1, transient)
            XCTAssertEqual(sqlite3_step(insertStmt), SQLITE_DONE)
        }
        sqlite3_finalize(insertStmt)
        sqlite3_close(db)
        db = nil

        let updated = try SidebarProjectSynchronizer.synchronizeCodexHome(
            codexHome,
            sourceIdentity: sourceID,
            targetIdentity: targetID
        )
        XCTAssertEqual(updated, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbURL.appendingPathExtension("pre-sync").path))

        var readDB: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(dbURL.path, &readDB, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(readDB) }

        var queryStmt: OpaquePointer?
        XCTAssertEqual(
            sqlite3_prepare_v2(readDB, "SELECT scope, key, value FROM settings", -1, &queryStmt, nil),
            SQLITE_OK
        )
        defer { sqlite3_finalize(queryStmt) }

        var rows: [String: String] = [:]
        while sqlite3_step(queryStmt) == SQLITE_ROW {
            let scope = String(cString: sqlite3_column_text(queryStmt, 0))
            let key = String(cString: sqlite3_column_text(queryStmt, 1))
            let value = String(cString: sqlite3_column_text(queryStmt, 2))
            rows["\(scope)|\(key)"] = value
        }

        XCTAssertNil(rows["global|electron-account-remote-preference:active-remote-project-id:\(ownerB)"])
        let selectedBRaw = try XCTUnwrap(rows["global|electron-owner-value:selected-project:\(ownerB)"])
        let selectedB = try JSONSerialization.jsonObject(with: Data(selectedBRaw.utf8)) as? [String: Any]
        XCTAssertEqual(selectedB?["projectId"] as? String, "open-science")

        let targetTupleKey = try XCTUnwrap(AccountIdentity.jsonTupleKey(["acct-b", "user-b", "local"]))
        let atomsBRaw = try XCTUnwrap(rows["electron-owner-atoms:\(ownerB)|new-task-project-by-computer"])
        let mapB = try JSONSerialization.jsonObject(with: Data(atomsBRaw.utf8)) as? [String: Any]
        XCTAssertEqual(mapB?[targetTupleKey] as? String, "open-science")
    }

    // MARK: - Fixtures

    private func makeAuthData(
        email: String,
        accountID: String,
        userID: String? = nil,
        plan: String = "plus",
        accessToken: String = "access-token"
    ) -> Data {
        var auth: [String: Any] = [
            "chatgpt_account_id": accountID,
            "chatgpt_plan_type": plan
        ]
        if let userID {
            auth["chatgpt_user_id"] = userID
        }
        let payload: [String: Any] = [
            "email": email,
            "https://api.openai.com/auth": auth
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

    @MainActor
    func testRefreshQuotaDetectsSignedOutUnavailableTransientAndRecovery() async throws {
        defer { AccountMockURLProtocol.requestHandler = nil }

        let subRoot = root.appendingPathComponent("mock-availability", isDirectory: true)
        let customHome = subRoot.appendingPathComponent("shared-codex", isDirectory: true)
        try FileManager.default.createDirectory(at: customHome, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AccountMockURLProtocol.self]
        let mockEndpoint = URL(string: "https://example.test/wham/usage")!

        let mockService = AccountsService(
            paths: AccountPaths(root: subRoot),
            launcher: FakeCodexLauncher(),
            defaultCodexHome: customHome,
            legacyRoot: subRoot.appendingPathComponent("no-legacy", isDirectory: true),
            urlSession: URLSession(configuration: config),
            usageEndpoint: mockEndpoint
        )
        try mockService.load()

        let acctA = try mockService.importSession(
            makeAuthData(email: "alice@example.com", accountID: "acct_a", accessToken: "tok-a")
        )
        let acctB = try mockService.importSession(
            makeAuthData(email: "bob@example.com", accountID: "acct_b", accessToken: "tok-b")
        )
        let acctC = try mockService.importSession(
            makeAuthData(email: "carol@example.com", accountID: "acct_c", accessToken: "tok-c")
        )

        let healthyJSON = Data("""
        {
          "plan_type": "plus",
          "primary_window": { "used_percent": 20, "limit_window_seconds": 18000, "reset_at": 1893456000 },
          "secondary_window": { "used_percent": 5, "limit_window_seconds": 604800, "reset_at": 1893456000 }
        }
        """.utf8)

        var statusByToken: [String: Int] = [
            "tok-a": 200,
            "tok-b": 200,
            "tok-c": 200
        ]
        AccountMockURLProtocol.requestHandler = { request in
            let token = request.value(forHTTPHeaderField: "Authorization")?
                .replacingOccurrences(of: "Bearer ", with: "") ?? ""
            let code = statusByToken[token] ?? 500
            let response = HTTPURLResponse(
                url: mockEndpoint,
                statusCode: code,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, code == 200 ? healthyJSON : Data())
        }

        try await mockService.refreshQuota(for: acctA.id)
        try await mockService.refreshQuota(for: acctB.id)
        try await mockService.refreshQuota(for: acctC.id)
        XCTAssertEqual(mockService.account(withID: acctA.id)?.resolvedAvailabilityStatus, .available)
        XCTAssertEqual(mockService.account(withID: acctA.id)?.quota?.secondaryRemainingPercent, 95)

        // 401 -> signed out (.reauthRequired), cached quota kept, not tagged as transient stale failure
        statusByToken["tok-a"] = 401
        do {
            try await mockService.refreshQuota(for: acctA.id)
            XCTFail("Expected 401 to throw")
        } catch {}
        let after401 = try XCTUnwrap(mockService.account(withID: acctA.id))
        XCTAssertEqual(after401.resolvedAvailabilityStatus, .reauthRequired)
        XCTAssertFalse(after401.isUsableAccount)
        XCTAssertFalse(after401.isAvailableForPool)
        XCTAssertEqual(after401.quota?.secondaryRemainingPercent, 95)
        XCTAssertFalse(mockService.failedQuotaAccountIDs.contains(acctA.id))
        XCTAssertFalse(after401.isStaleQuota(at: .now, failedIDs: mockService.failedQuotaAccountIDs))

        // 403 -> disabled/unavailable (.unavailable)
        statusByToken["tok-b"] = 403
        do {
            try await mockService.refreshQuota(for: acctB.id)
            XCTFail("Expected 403 to throw")
        } catch {}
        let after403 = try XCTUnwrap(mockService.account(withID: acctB.id))
        XCTAssertEqual(after403.resolvedAvailabilityStatus, .unavailable)
        XCTAssertFalse(after403.isUsableAccount)
        XCTAssertFalse(after403.isAvailableForPool)
        XCTAssertFalse(mockService.failedQuotaAccountIDs.contains(acctB.id))

        // 500 -> transient failure keeps .available and records failedQuotaAccountIDs ("旧")
        statusByToken["tok-c"] = 500
        do {
            try await mockService.refreshQuota(for: acctC.id)
            XCTFail("Expected 500 to throw")
        } catch {}
        let after500 = try XCTUnwrap(mockService.account(withID: acctC.id))
        XCTAssertEqual(after500.resolvedAvailabilityStatus, .available)
        XCTAssertTrue(after500.isUsableAccount)
        XCTAssertTrue(mockService.failedQuotaAccountIDs.contains(acctC.id))
        XCTAssertTrue(after500.isStaleQuota(at: .now, failedIDs: mockService.failedQuotaAccountIDs))

        // Re-importing fresh session clears unusable status back to .available
        let reimported = try mockService.importSession(
            makeAuthData(email: "alice@example.com", accountID: "acct_a", accessToken: "tok-a-fresh")
        )
        XCTAssertEqual(reimported.resolvedAvailabilityStatus, .available)
        XCTAssertTrue(mockService.account(withID: acctA.id)?.isUsableAccount == true)
    }

    @MainActor
    func testSharedAuthFailureAndUnusableExclusionFromAvailablePool() async throws {
        defer { AccountMockURLProtocol.requestHandler = nil }

        let subRoot = root.appendingPathComponent("shared-failure", isDirectory: true)
        let customHome = subRoot.appendingPathComponent("shared-codex", isDirectory: true)
        try FileManager.default.createDirectory(at: customHome, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AccountMockURLProtocol.self]
        let mockEndpoint = URL(string: "https://example.test/wham/usage")!
        let healthyJSON = Data("""
        {
          "plan_type": "plus",
          "secondary_window": { "used_percent": 10, "limit_window_seconds": 604800, "reset_at": 1893456000 }
        }
        """.utf8)
        AccountMockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: mockEndpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, healthyJSON)
        }

        let mockService = AccountsService(
            paths: AccountPaths(root: subRoot),
            launcher: FakeCodexLauncher(),
            defaultCodexHome: customHome,
            legacyRoot: subRoot.appendingPathComponent("no-legacy", isDirectory: true),
            urlSession: URLSession(configuration: config),
            usageEndpoint: mockEndpoint
        )
        try mockService.load()

        let acctA = try mockService.importSession(
            makeAuthData(email: "alice@example.com", accountID: "acct_a", accessToken: "tok-a")
        )
        try await mockService.switchTo(acctA.id)
        XCTAssertEqual(mockService.activeAccountID, acctA.id)

        // Simulate user signing out inside Codex (removes ~/.codex/auth.json)
        try FileManager.default.removeItem(at: mockService.sharedAuthURL)
        mockService.recordSharedAuthUsageFailure(credentials: nil, error: CodexAuthError.authFileUnavailable)
        XCTAssertEqual(mockService.account(withID: acctA.id)?.resolvedAvailabilityStatus, .reauthRequired)

        // Drawer open refresh must not falsely mark signed-out active account healthy via stale vault copy
        try? await mockService.refreshQuota(for: acctA.id)
        XCTAssertEqual(mockService.account(withID: acctA.id)?.resolvedAvailabilityStatus, .reauthRequired)

        // When signed back in and live usage fetch succeeds, status recovers to .available
        let freshSnapshot = UsageSnapshot(
            windows: [UsageWindow(id: "secondary", kind: .weekly, usedPercent: 12, resetAt: nil)],
            resetCreditsAvailable: nil,
            resetCredits: [],
            fetchedAt: .now
        )
        mockService.recordSharedAuthUsageSuccess(
            credentials: CodexCredentials(accessToken: "tok-a-2", accountID: "acct_a"),
            snapshot: freshSnapshot
        )
        XCTAssertEqual(mockService.account(withID: acctA.id)?.resolvedAvailabilityStatus, .available)
        XCTAssertEqual(mockService.account(withID: acctA.id)?.quota?.secondaryRemainingPercent, 88)

        // Picker pool exclusion & standby selection
        let activeSignedOut = AccountProfile(
            displayName: "ActiveSignedOut",
            fingerprint: "fp-a",
            quota: AccountQuota(secondaryUsedPercent: 10, checkedAt: .now),
            availabilityStatus: .reauthRequired
        )
        let standbyHealthy = AccountProfile(
            displayName: "StandbyHealthy",
            fingerprint: "fp-b",
            quota: AccountQuota(secondaryUsedPercent: 60, checkedAt: .now),
            availabilityStatus: .available
        )
        let standbySignedOut = AccountProfile(
            displayName: "StandbySignedOut",
            fingerprint: "fp-c",
            quota: AccountQuota(secondaryUsedPercent: 1, checkedAt: .now),
            availabilityStatus: .reauthRequired
        )

        // Under filterThresholdCount (< 5), all accounts remain visible so signed-out rows are never hidden without filter pills
        let smallSnap = AccountPickerLogic.snapshot(
            accounts: [activeSignedOut, standbyHealthy, standbySignedOut],
            activeAccountID: activeSignedOut.id,
            filter: .availableFirst
        )
        XCTAssertEqual(smallSnap.availableCount, 1)
        XCTAssertEqual(smallSnap.unusableCount, 2)
        XCTAssertEqual(smallSnap.bestStandbyAccount?.id, standbyHealthy.id)
        XCTAssertTrue(smallSnap.shouldShowLowQuotaCue)
        XCTAssertEqual(smallSnap.displayedAccounts.count, 3)

        // With 5+ accounts, `.availableFirst` excludes unusable accounts and ranks remaining healthy accounts
        let standbyHealthyBest = AccountProfile(
            displayName: "StandbyHealthyBest",
            fingerprint: "fp-d",
            quota: AccountQuota(secondaryUsedPercent: 20, checkedAt: .now),
            availabilityStatus: .available
        )
        let standbyUnavailable = AccountProfile(
            displayName: "StandbyUnavailable",
            fingerprint: "fp-e",
            quota: AccountQuota(secondaryUsedPercent: 5, checkedAt: .now),
            availabilityStatus: .unavailable
        )
        let fiveAccounts = [
            activeSignedOut,
            standbyHealthy,
            standbySignedOut,
            standbyHealthyBest,
            standbyUnavailable
        ]

        let availableSnap = AccountPickerLogic.snapshot(
            accounts: fiveAccounts,
            activeAccountID: activeSignedOut.id,
            filter: .availableFirst
        )
        XCTAssertEqual(availableSnap.availableCount, 2)
        XCTAssertEqual(availableSnap.unusableCount, 3)
        XCTAssertEqual(availableSnap.bestStandbyAccount?.id, standbyHealthyBest.id)
        XCTAssertTrue(availableSnap.shouldShowLowQuotaCue)
        XCTAssertEqual(availableSnap.displayedAccounts.map(\.id), [standbyHealthyBest.id, standbyHealthy.id])

        let allSnap = AccountPickerLogic.snapshot(
            accounts: fiveAccounts,
            activeAccountID: activeSignedOut.id,
            filter: .all
        )
        XCTAssertEqual(allSnap.displayedAccounts.count, 5)
        XCTAssertEqual(allSnap.unusableCount, 3)
    }

    @MainActor
    func testWeeklyOnlyPrimaryWindowMapsToWeeklyQuotaAndMigratesLegacyCache() async throws {
        defer { AccountMockURLProtocol.requestHandler = nil }

        // 1. Direct snapshot mapping when API puts a 604800s weekly window in `primary_window`
        let resetAt = Date().addingTimeInterval(5 * 86_400)
        let weeklyOnlySnapshot = UsageSnapshot(
            windows: [
                UsageWindow(id: "primary", kind: .weekly, usedPercent: 25, resetAt: resetAt)
            ],
            fetchedAt: .now
        )
        let quota = AccountQuota(snapshot: weeklyOnlySnapshot, planType: "free")
        XCTAssertNil(quota.primaryUsedPercent)
        XCTAssertNil(quota.primaryResetsAt)
        XCTAssertEqual(quota.secondaryRemainingPercent, 75)
        XCTAssertEqual(quota.secondaryResetsAt, resetAt)
        XCTAssertEqual(quota.windowLayoutVersion, AccountQuota.currentWindowLayoutVersion)

        let previewSnapshot = quota.previewUsageSnapshot(preservingResetCreditsFrom: nil)
        XCTAssertNil(previewSnapshot.fiveHourWindow)
        XCTAssertEqual(previewSnapshot.weeklyWindow?.remainingPercent, 75)

        // 2. Legacy accounts.json migration + refreshStaleQuotas forced re-check when windowLayoutVersion is missing
        let subRoot = root.appendingPathComponent("weekly-only-migration", isDirectory: true)
        let customHome = subRoot.appendingPathComponent("shared-codex", isDirectory: true)
        try FileManager.default.createDirectory(at: customHome, withIntermediateDirectories: true)
        let paths = AccountPaths(root: subRoot)
        try PrivateFileWriter.ensureDirectory(paths.root)

        let checkedAt = Date().addingTimeInterval(-20) // < 120s TTL
        let legacyResetAt = checkedAt.addingTimeInterval(4 * 86_400)
        let legacyJSON = """
        {
          "version": 1,
          "accounts": [
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "displayName": "support",
              "email": "support@example.com",
              "accountIdentifier": "acct_support",
              "planType": "free",
              "fingerprint": "fp-support",
              "importedAt": "2026-11-14T00:00:00Z",
              "lastCheckedAt": "\(ISO8601DateFormatter().string(from: checkedAt))",
              "quota": {
                "checkedAt": "\(ISO8601DateFormatter().string(from: checkedAt))",
                "planType": "free",
                "primaryResetsAt": "\(ISO8601DateFormatter().string(from: legacyResetAt))",
                "primaryUsedPercent": 30
              }
            }
          ]
        }
        """
        try Data(legacyJSON.utf8).write(to: paths.accountsFile)

        let vault = AccountVault(directory: paths.vaultDirectory)
        try vault.store(
            makeAuthData(email: "support@example.com", accountID: "acct_support", plan: "free", accessToken: "tok-support"),
            for: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        )

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AccountMockURLProtocol.self]
        let mockEndpoint = URL(string: "https://example.test/wham/usage")!
        let weeklyOnlyAPI = Data("""
        {
          "plan_type": "free",
          "rate_limit": {
            "primary_window": { "used_percent": 15, "limit_window_seconds": 604800, "reset_at": 1893456000 },
            "secondary_window": null
          }
        }
        """.utf8)
        var usageRequestsSeen = 0
        AccountMockURLProtocol.requestHandler = { request in
            if request.url == mockEndpoint {
                usageRequestsSeen += 1
            }
            let response = HTTPURLResponse(
                url: request.url ?? mockEndpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, request.url == mockEndpoint ? weeklyOnlyAPI : Data("{}".utf8))
        }

        let migratedService = AccountsService(
            paths: paths,
            launcher: FakeCodexLauncher(),
            defaultCodexHome: customHome,
            legacyRoot: subRoot.appendingPathComponent("no-legacy", isDirectory: true),
            urlSession: URLSession(configuration: config),
            usageEndpoint: mockEndpoint
        )
        try migratedService.load()

        let supportID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let loaded = try XCTUnwrap(migratedService.account(withID: supportID))
        XCTAssertNil(loaded.quota?.primaryRemainingPercent)
        XCTAssertEqual(loaded.quota?.secondaryRemainingPercent, 70)

        // Drawer open refreshes legacy-format quota even within the 120s TTL window
        await migratedService.refreshStaleQuotas(ttl: 120)
        XCTAssertEqual(usageRequestsSeen, 1)
        let refreshed = try XCTUnwrap(migratedService.account(withID: supportID))
        XCTAssertNil(refreshed.quota?.primaryRemainingPercent)
        XCTAssertEqual(refreshed.quota?.secondaryRemainingPercent, 85)
        XCTAssertEqual(refreshed.quota?.windowLayoutVersion, AccountQuota.currentWindowLayoutVersion)

        // Subsequent drawer open within 120s skips re-fetch once upgraded
        await migratedService.refreshStaleQuotas(ttl: 120)
        XCTAssertEqual(usageRequestsSeen, 1)
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

actor GatedCodexLauncher: CodexLaunching {
    private var shouldGateQuit = false
    private var nextError: Error?
    private var didEnterQuit = false
    private var quitEnteredContinuation: CheckedContinuation<Void, Never>?
    private var resumeContinuation: CheckedContinuation<Void, Never>?

    func setGateQuit(_ gate: Bool) {
        shouldGateQuit = gate
        didEnterQuit = false
    }

    func setNextError(_ error: Error?) {
        nextError = error
        shouldGateQuit = false
    }

    func waitUntilQuitEntered() async {
        if didEnterQuit { return }
        await withCheckedContinuation { continuation in
            quitEnteredContinuation = continuation
        }
    }

    func quit() async {
        guard shouldGateQuit, nextError == nil else { return }
        await withCheckedContinuation { continuation in
            didEnterQuit = true
            resumeContinuation = continuation
            quitEnteredContinuation?.resume()
            quitEnteredContinuation = nil
        }
    }

    func launchShared() async throws {
        if let nextError {
            throw nextError
        }
    }

    func resume() {
        resumeContinuation?.resume()
        resumeContinuation = nil
    }
}

private final class AccountMockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.requestHandler else {
                throw URLError(.badServerResponse)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
