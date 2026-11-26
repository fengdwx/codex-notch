import AppKit
import Foundation
import XCTest
@testable import CodexNotch

@MainActor
final class SessionAuthSyncTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexnotch-auth-sync-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        SyncMockURLProtocol.handler = nil
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Option 1: AccountsService reconciliation with ~/.codex/auth.json

    func testStartupLoadReconcilesActiveAccountWhenSharedAuthChangedExternally() async throws {
        let sharedHome = root.appendingPathComponent("shared-codex", isDirectory: true)
        let accountsRoot = root.appendingPathComponent("Accounts", isDirectory: true)
        try FileManager.default.createDirectory(at: sharedHome, withIntermediateDirectories: true)

        let authA = makeAuthData(email: "alice@example.com", accountID: "acct-a", accessToken: "tok-a")
        let authB = makeAuthData(email: "bob@example.com", accountID: "acct-b", accessToken: "tok-b")

        let initial = AccountsService(
            paths: AccountPaths(root: accountsRoot),
            launcher: SyncFakeCodexLauncher(),
            defaultCodexHome: sharedHome
        )
        let acctA = try initial.importSession(authA)
        let acctB = try initial.importSession(authB)
        try await initial.switchTo(acctA.id)
        XCTAssertEqual(initial.activeAccountID, acctA.id)

        // External tool (e.g. magpie / codex login) overwrites ~/.codex/auth.json to acctB.
        try authB.write(to: sharedHome.appendingPathComponent("auth.json"), options: .atomic)

        let reloaded = AccountsService(
            paths: AccountPaths(root: accountsRoot),
            launcher: SyncFakeCodexLauncher(),
            defaultCodexHome: sharedHome
        )
        try reloaded.load()

        XCTAssertEqual(reloaded.activeAccountID, acctB.id)
    }

    func testStartupLoadClearsActiveAccountWhenSharedAuthIsUnimportedExternalAccount() async throws {
        let sharedHome = root.appendingPathComponent("shared-codex-ext", isDirectory: true)
        let accountsRoot = root.appendingPathComponent("Accounts-ext", isDirectory: true)
        try FileManager.default.createDirectory(at: sharedHome, withIntermediateDirectories: true)

        let authA = makeAuthData(email: "alice@example.com", accountID: "acct-a", accessToken: "tok-a")
        let authC = makeAuthData(email: "external@example.com", accountID: "acct-c", accessToken: "tok-c")

        let initial = AccountsService(
            paths: AccountPaths(root: accountsRoot),
            launcher: SyncFakeCodexLauncher(),
            defaultCodexHome: sharedHome
        )
        let acctA = try initial.importSession(authA)
        try await initial.switchTo(acctA.id)
        XCTAssertEqual(initial.activeAccountID, acctA.id)

        try authC.write(to: sharedHome.appendingPathComponent("auth.json"), options: .atomic)

        let reloaded = AccountsService(
            paths: AccountPaths(root: accountsRoot),
            launcher: SyncFakeCodexLauncher(),
            defaultCodexHome: sharedHome
        )
        try reloaded.load()

        XCTAssertNil(reloaded.activeAccountID)
    }

    func testRecordSharedAuthUsageSuccessReconcilesActiveAccountAndIsolatesUnimportedAccount() async throws {
        let sharedHome = root.appendingPathComponent("shared-codex-runtime", isDirectory: true)
        let accountsRoot = root.appendingPathComponent("Accounts-runtime", isDirectory: true)
        try FileManager.default.createDirectory(at: sharedHome, withIntermediateDirectories: true)

        let authA = makeAuthData(email: "alice@example.com", accountID: "acct-a", accessToken: "tok-a")
        let authB = makeAuthData(email: "bob@example.com", accountID: "acct-b", accessToken: "tok-b")
        let authC = makeAuthData(email: "other@example.com", accountID: "acct-c", accessToken: "tok-c")

        let service = AccountsService(
            paths: AccountPaths(root: accountsRoot),
            launcher: SyncFakeCodexLauncher(),
            defaultCodexHome: sharedHome
        )
        let acctA = try service.importSession(authA)
        let acctB = try service.importSession(authB)
        try await service.switchTo(acctA.id)

        let snapA = UsageSnapshot(
            windows: [UsageWindow(id: "secondary", kind: .weekly, usedPercent: 55, resetAt: Date(timeIntervalSince1970: 1_795_619_862))],
            fetchedAt: Date(timeIntervalSince1970: 1_795_500_000)
        )
        service.recordSharedAuthUsageSuccess(
            credentials: CodexCredentials(accessToken: "tok-a", accountID: "acct-a"),
            snapshot: snapA
        )
        XCTAssertEqual(service.activeAccountID, acctA.id)
        XCTAssertEqual(service.account(withID: acctA.id)?.quota?.secondaryUsedPercent, 55)

        // External rewrite to acctB: runtime usage sync must move activeAccountID to B
        // and update B without touching A.
        try authB.write(to: sharedHome.appendingPathComponent("auth.json"), options: .atomic)
        let snapB = UsageSnapshot(
            windows: [UsageWindow(id: "secondary", kind: .weekly, usedPercent: 44, resetAt: Date(timeIntervalSince1970: 1_795_678_183))],
            fetchedAt: Date(timeIntervalSince1970: 1_795_501_000)
        )
        service.recordSharedAuthUsageSuccess(
            credentials: CodexCredentials(accessToken: "tok-b", accountID: "acct-b"),
            snapshot: snapB
        )
        XCTAssertEqual(service.activeAccountID, acctB.id)
        XCTAssertEqual(service.account(withID: acctB.id)?.quota?.secondaryUsedPercent, 44)
        XCTAssertEqual(service.account(withID: acctA.id)?.quota?.secondaryUsedPercent, 55)

        // External rewrite to unimported acctC: activeAccountID clears and neither A nor B is overwritten.
        try authC.write(to: sharedHome.appendingPathComponent("auth.json"), options: .atomic)
        let snapC = UsageSnapshot(
            windows: [UsageWindow(id: "secondary", kind: .weekly, usedPercent: 90, resetAt: Date(timeIntervalSince1970: 1_795_700_000))],
            fetchedAt: Date(timeIntervalSince1970: 1_795_502_000)
        )
        service.recordSharedAuthUsageSuccess(
            credentials: CodexCredentials(accessToken: "tok-c", accountID: "acct-c"),
            snapshot: snapC
        )
        XCTAssertNil(service.activeAccountID)
        XCTAssertEqual(service.account(withID: acctA.id)?.quota?.secondaryUsedPercent, 55)
        XCTAssertEqual(service.account(withID: acctB.id)?.quota?.secondaryUsedPercent, 44)
    }

    func testRecordSharedAuthUsageFailureForUnimportedAccountDoesNotCorruptSavedAccountStatus() async throws {
        let sharedHome = root.appendingPathComponent("shared-codex-fail", isDirectory: true)
        let accountsRoot = root.appendingPathComponent("Accounts-fail", isDirectory: true)
        try FileManager.default.createDirectory(at: sharedHome, withIntermediateDirectories: true)

        let authA = makeAuthData(email: "alice@example.com", accountID: "acct-a", accessToken: "tok-a")
        let authC = makeAuthData(email: "other@example.com", accountID: "acct-c", accessToken: "tok-c")

        let service = AccountsService(
            paths: AccountPaths(root: accountsRoot),
            launcher: SyncFakeCodexLauncher(),
            defaultCodexHome: sharedHome
        )
        let acctA = try service.importSession(authA)
        try await service.switchTo(acctA.id)

        try authC.write(to: sharedHome.appendingPathComponent("auth.json"), options: .atomic)
        service.recordSharedAuthUsageFailure(
            credentials: CodexCredentials(accessToken: "tok-c", accountID: "acct-c"),
            error: CodexUsageError.reauthenticationRequired
        )

        XCTAssertNil(service.activeAccountID)
        XCTAssertEqual(service.account(withID: acctA.id)?.resolvedAvailabilityStatus, .available)
    }

    // MARK: - Option 2: Rollout rate_limits parsing & monitor tracking

    func testRolloutEventParserParsesCodexRateLimitsAndIgnoresOtherLimitIDs() {
        let codexLine = Data("""
        {"timestamp":"2026-11-24T07:08:54.184Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":11.0,"window_minutes":300,"resets_at":1795521582},"secondary":{"used_percent":55.0,"window_minutes":10080,"resets_at":1795619862},"plan_type":"plus"}}}
        """.utf8)

        XCTAssertNil(RolloutEventParser.parseLine(codexLine), "token_count must not emit a session lifecycle event")
        guard case let .rateLimit(observation) = RolloutEventParser.parseRecord(codexLine) else {
            return XCTFail("Expected parsed rateLimit observation")
        }
        XCTAssertEqual(observation.fiveHourWindow?.usedPercent, 11)
        XCTAssertEqual(observation.fiveHourWindow?.resetAt, Date(timeIntervalSince1970: 1_795_521_582))
        XCTAssertEqual(observation.weeklyWindow?.usedPercent, 55)
        XCTAssertEqual(observation.weeklyWindow?.resetAt, Date(timeIntervalSince1970: 1_795_619_862))
        XCTAssertEqual(observation.planType, "plus")

        let codeReviewLine = Data("""
        {"timestamp":"2026-11-24T07:09:00.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"code_review","primary":{"used_percent":99.0,"window_minutes":300,"resets_at":1795529999}}}}
        """.utf8)
        XCTAssertNil(RolloutEventParser.parseRecord(codeReviewLine))
    }

    func testRolloutActivityMonitorTracksLatestRateLimitAndIgnoresSubagentRollouts() async throws {
        let sessionsRoot = root.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsRoot, withIntermediateDirectories: true)

        let mainRollout = sessionsRoot.appendingPathComponent("main.jsonl")
        let mainLines = """
        {"timestamp":"2026-11-24T07:00:00Z","type":"session_meta","payload":{"id":"thread-main","cwd":"/tmp/app","originator":"Codex Desktop"}}
        {"timestamp":"2026-11-24T07:01:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":8,"window_minutes":300,"resets_at":1795521582},"secondary":{"used_percent":54,"window_minutes":10080,"resets_at":1795619862}}}}
        {"timestamp":"2026-11-24T07:05:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":11,"window_minutes":300,"resets_at":1795521582},"secondary":{"used_percent":55,"window_minutes":10080,"resets_at":1795619862}}}}

        """
        try Data(mainLines.utf8).write(to: mainRollout)

        let subagentRollout = sessionsRoot.appendingPathComponent("subagent.jsonl")
        let subagentLines = """
        {"timestamp":"2026-11-24T07:06:00Z","type":"session_meta","payload":{"id":"thread-sub","cwd":"/tmp/app","source":{"subagent":{"thread_spawn":{"parent_thread_id":"thread-main"}}}}}
        {"timestamp":"2026-11-24T07:07:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":99,"window_minutes":300,"resets_at":1795599999},"secondary":{"used_percent":99,"window_minutes":10080,"resets_at":1795699999}}}}

        """
        try Data(subagentLines.utf8).write(to: subagentRollout)

        let store = ActiveSessionStore()
        let monitor = RolloutActivityMonitor(rootURL: sessionsRoot, store: store)
        let ready = expectation(description: "Initial rollout scan completed")
        monitor.onInitialScanCompleted = { _ in ready.fulfill() }
        monitor.start()
        defer { monitor.stop() }
        await fulfillment(of: [ready], timeout: 3)

        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.latestRateLimit?.fiveHourWindow?.usedPercent, 11)
        XCTAssertEqual(snapshot.latestRateLimit?.weeklyWindow?.usedPercent, 55)
        XCTAssertEqual(snapshot.latestRateLimit?.weeklyWindow?.resetAt, Date(timeIntervalSince1970: 1_795_619_862))
    }

    // MARK: - Option 2: SessionAuthDriftResolver decision logic

    func testDriftResolverDetectsSplitBrainAndMatchesLiveAccountName() {
        let authModifiedAt = Date(timeIntervalSince1970: 1_795_500_838) // 14:13:58
        let codexLaunchDate = Date(timeIntervalSince1970: 1_795_497_120) // 13:12:00
        let rolloutObservedAt = Date(timeIntervalSince1970: 1_795_504_134) // 15:08:54

        let alpha = AccountProfile(
            displayName: "alpha",
            accountIdentifier: "acct-alpha",
            fingerprint: "fp-alpha",
            quota: AccountQuota(
                primaryUsedPercent: 10,
                primaryResetsAt: Date(timeIntervalSince1970: 1_795_521_582),
                secondaryUsedPercent: 55,
                secondaryResetsAt: Date(timeIntervalSince1970: 1_795_619_862),
                planType: "plus",
                checkedAt: authModifiedAt
            )
        )
        let beta = AccountProfile(
            displayName: "beta",
            accountIdentifier: "acct-beta",
            fingerprint: "fp-beta",
            quota: AccountQuota(
                primaryUsedPercent: 0,
                primaryResetsAt: Date(timeIntervalSince1970: 1_795_521_883),
                secondaryUsedPercent: 44,
                secondaryResetsAt: Date(timeIntervalSince1970: 1_795_678_183),
                planType: "plus",
                checkedAt: rolloutObservedAt
            )
        )

        let diskUsage = UsageSnapshot(
            windows: [
                UsageWindow(id: "primary", kind: .rolling(hours: 5), usedPercent: 0, resetAt: Date(timeIntervalSince1970: 1_795_521_883)),
                UsageWindow(id: "secondary", kind: .weekly, usedPercent: 44, resetAt: Date(timeIntervalSince1970: 1_795_678_183))
            ],
            resetCreditsAvailable: 3,
            resetCredits: [ResetCredit(id: "rc-1")],
            fetchedAt: rolloutObservedAt.addingTimeInterval(30)
        )
        let rollout = RolloutRateLimitObservation(
            observedAt: rolloutObservedAt,
            windows: [
                UsageWindow(id: "primary", kind: .rolling(hours: 5), usedPercent: 11, resetAt: Date(timeIntervalSince1970: 1_795_521_582)),
                UsageWindow(id: "secondary", kind: .weekly, usedPercent: 55, resetAt: Date(timeIntervalSince1970: 1_795_619_862))
            ],
            planType: "plus"
        )

        let result = SessionAuthDriftResolver.resolve(
            sharedAuthUsage: diskUsage,
            sharedAuthModifiedAt: authModifiedAt,
            diskAccount: beta,
            rolloutRateLimit: rollout,
            accounts: [alpha, beta],
            codexAppLaunchDate: codexLaunchDate
        )

        XCTAssertFalse(result.needsFreshAPIUsage)
        XCTAssertEqual(result.drift?.liveAccountID, alpha.id)
        XCTAssertEqual(result.drift?.liveAccountName, "alpha")
        XCTAssertEqual(result.drift?.diskAccountID, beta.id)
        XCTAssertEqual(result.drift?.diskAccountName, "beta")
        XCTAssertEqual(result.drift?.liveUsage.fiveHourWindow?.remainingPercent, 89)
        XCTAssertEqual(result.drift?.liveUsage.weeklyWindow?.remainingPercent, 45)
        XCTAssertEqual(result.drift?.liveUsage.resetCredits, [], "Drift live usage must never carry disk account reset credits")
        XCTAssertTrue(result.drift?.bannerText(language: .chinese).contains("alpha") == true)
        XCTAssertTrue(result.drift?.bannerText(language: .chinese).contains("beta") == true)
        XCTAssertTrue(result.drift?.bannerText(language: .english).contains("alpha") == true)
    }

    func testDriftResolverClearsWhenRolloutIsOlderThanAuthOrCodexRelaunchedAfterAuth() {
        let authModifiedAt = Date(timeIntervalSince1970: 1_795_500_838)
        let diskUsage = UsageSnapshot(
            windows: [UsageWindow(id: "secondary", kind: .weekly, usedPercent: 44, resetAt: Date(timeIntervalSince1970: 1_795_678_183))],
            fetchedAt: authModifiedAt.addingTimeInterval(30)
        )

        // 1. Pre-switch rollout (before auth.json mtime) must not trigger drift.
        let olderRollout = RolloutRateLimitObservation(
            observedAt: authModifiedAt.addingTimeInterval(-5),
            windows: [UsageWindow(id: "secondary", kind: .weekly, usedPercent: 55, resetAt: Date(timeIntervalSince1970: 1_795_619_862))],
            planType: "plus"
        )
        let beforeSwitch = SessionAuthDriftResolver.resolve(
            sharedAuthUsage: diskUsage,
            sharedAuthModifiedAt: authModifiedAt,
            diskAccount: nil,
            rolloutRateLimit: olderRollout,
            accounts: [],
            codexAppLaunchDate: authModifiedAt.addingTimeInterval(-3_600)
        )
        XCTAssertNil(beforeSwitch.drift)

        // 2. Post-switch rollout, followed by a Codex Desktop relaunch after auth.json mtime -> drift clears.
        let postSwitchRollout = RolloutRateLimitObservation(
            observedAt: authModifiedAt.addingTimeInterval(600),
            windows: [UsageWindow(id: "secondary", kind: .weekly, usedPercent: 55, resetAt: Date(timeIntervalSince1970: 1_795_619_862))],
            planType: "plus"
        )
        let afterRelaunch = SessionAuthDriftResolver.resolve(
            sharedAuthUsage: diskUsage,
            sharedAuthModifiedAt: authModifiedAt,
            diskAccount: nil,
            rolloutRateLimit: postSwitchRollout,
            accounts: [],
            codexAppLaunchDate: authModifiedAt.addingTimeInterval(900)
        )
        XCTAssertNil(afterRelaunch.drift)
    }

    func testDriftResolverIgnoresNaturalRolloverAndGuardsStaleZeroPercentPlaceholder() {
        let authModifiedAt = Date(timeIntervalSince1970: 1_795_500_000)

        // Natural rollover: API weekly window expired at T+100 and rollout rolled forward by 7d.
        let expiringAPI = UsageSnapshot(
            windows: [UsageWindow(id: "secondary", kind: .weekly, usedPercent: 80, resetAt: authModifiedAt.addingTimeInterval(100))],
            fetchedAt: authModifiedAt.addingTimeInterval(10)
        )
        let rolledRollout = RolloutRateLimitObservation(
            observedAt: authModifiedAt.addingTimeInterval(120),
            windows: [UsageWindow(id: "secondary", kind: .weekly, usedPercent: 1, resetAt: authModifiedAt.addingTimeInterval(100 + 604_800))],
            planType: "plus"
        )
        let rolloverResult = SessionAuthDriftResolver.resolve(
            sharedAuthUsage: expiringAPI,
            sharedAuthModifiedAt: authModifiedAt,
            diskAccount: nil,
            rolloutRateLimit: rolledRollout,
            accounts: []
        )
        XCTAssertNil(rolloverResult.drift)
        XCTAssertFalse(rolloverResult.needsFreshAPIUsage)

        // Stale 0% API placeholder fetched BEFORE the turn must ask for a fresh API poll instead of false-positiving.
        let staleZeroAPI = UsageSnapshot(
            windows: [UsageWindow(id: "secondary", kind: .weekly, usedPercent: 0, resetAt: authModifiedAt.addingTimeInterval(604_800))],
            fetchedAt: authModifiedAt.addingTimeInterval(10)
        )
        let firstTurnRollout = RolloutRateLimitObservation(
            observedAt: authModifiedAt.addingTimeInterval(300),
            windows: [UsageWindow(id: "secondary", kind: .weekly, usedPercent: 1, resetAt: authModifiedAt.addingTimeInterval(300 + 604_800))],
            planType: "plus"
        )
        let staleZeroResult = SessionAuthDriftResolver.resolve(
            sharedAuthUsage: staleZeroAPI,
            sharedAuthModifiedAt: authModifiedAt,
            diskAccount: nil,
            rolloutRateLimit: firstTurnRollout,
            accounts: []
        )
        XCTAssertNil(staleZeroResult.drift)
        XCTAssertTrue(staleZeroResult.needsFreshAPIUsage)

        // Once API is re-fetched AFTER the turn and STILL reports 0% with a different future reset -> genuine drift.
        let freshZeroAPI = UsageSnapshot(
            windows: [UsageWindow(id: "secondary", kind: .weekly, usedPercent: 0, resetAt: authModifiedAt.addingTimeInterval(500_000))],
            fetchedAt: authModifiedAt.addingTimeInterval(305)
        )
        let confirmedZeroDrift = SessionAuthDriftResolver.resolve(
            sharedAuthUsage: freshZeroAPI,
            sharedAuthModifiedAt: authModifiedAt,
            diskAccount: nil,
            rolloutRateLimit: firstTurnRollout,
            accounts: []
        )
        XCTAssertNotNil(confirmedZeroDrift.drift)
        XCTAssertFalse(confirmedZeroDrift.needsFreshAPIUsage)
    }

    func testDriftResolverDoesNotGuessAmbiguousLiveAccountName() {
        let authModifiedAt = Date(timeIntervalSince1970: 1_795_500_000)
        let sharedReset = Date(timeIntervalSince1970: 1_795_619_862)
        let acct1 = AccountProfile(
            displayName: "dup-1",
            accountIdentifier: "acct-1",
            fingerprint: "fp-1",
            quota: AccountQuota(secondaryUsedPercent: 55, secondaryResetsAt: sharedReset)
        )
        let acct2 = AccountProfile(
            displayName: "dup-2",
            accountIdentifier: "acct-2",
            fingerprint: "fp-2",
            quota: AccountQuota(secondaryUsedPercent: 55, secondaryResetsAt: sharedReset)
        )
        let disk = AccountProfile(displayName: "disk", accountIdentifier: "acct-disk", fingerprint: "fp-disk")

        let diskUsage = UsageSnapshot(
            windows: [UsageWindow(id: "secondary", kind: .weekly, usedPercent: 44, resetAt: Date(timeIntervalSince1970: 1_795_678_183))],
            fetchedAt: authModifiedAt.addingTimeInterval(30)
        )
        let rollout = RolloutRateLimitObservation(
            observedAt: authModifiedAt.addingTimeInterval(120),
            windows: [UsageWindow(id: "secondary", kind: .weekly, usedPercent: 55, resetAt: sharedReset)],
            planType: "plus"
        )

        let result = SessionAuthDriftResolver.resolve(
            sharedAuthUsage: diskUsage,
            sharedAuthModifiedAt: authModifiedAt,
            diskAccount: disk,
            rolloutRateLimit: rollout,
            accounts: [acct1, acct2, disk]
        )

        XCTAssertNotNil(result.drift)
        XCTAssertNil(result.drift?.liveAccountID)
        XCTAssertNil(result.drift?.liveAccountName)
        XCTAssertEqual(result.drift?.diskAccountName, "disk")
    }

    // MARK: - End-to-End Runtime Coordinator Integration

    func testRuntimeReconcilesAuthShowsLiveRolloutOnSplitBrainBlocksResetAndClearsOnRelaunch() async throws {
        _ = NSApplication.shared
        let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
        let sessionsDir = codexHome.appendingPathComponent("sessions", isDirectory: true)
        let accountsRoot = root.appendingPathComponent("accounts", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)

        let authAlpha = makeAuthData(email: "alpha@example.com", accountID: "acct-alpha", accessToken: "tok-alpha")
        let authBeta = makeAuthData(email: "beta@example.com", accountID: "acct-beta", accessToken: "tok-beta")

        let accountsService = AccountsService(
            paths: AccountPaths(root: accountsRoot),
            launcher: SyncFakeCodexLauncher(),
            defaultCodexHome: codexHome
        )
        let alpha = try accountsService.importSession(authAlpha)
        let beta = try accountsService.importSession(authBeta)
        try await accountsService.switchTo(alpha.id)
        let baseNow = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        let alphaPrimaryReset = baseNow.addingTimeInterval(17_382)
        let alphaWeeklyReset = baseNow.addingTimeInterval(115_662)
        let betaPrimaryReset = baseNow.addingTimeInterval(17_683)
        let betaWeeklyReset = baseNow.addingTimeInterval(173_983)
        let alphaPrimaryResetEpoch = Int(alphaPrimaryReset.timeIntervalSince1970)
        let alphaWeeklyResetEpoch = Int(alphaWeeklyReset.timeIntervalSince1970)
        let betaPrimaryResetEpoch = Int(betaPrimaryReset.timeIntervalSince1970)
        let betaWeeklyResetEpoch = Int(betaWeeklyReset.timeIntervalSince1970)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let turn1MetaTimestamp = isoFormatter.string(from: baseNow.addingTimeInterval(-66))
        let turn1EventTimestamp = isoFormatter.string(from: baseNow.addingTimeInterval(-65.816))
        let turn2EventTimestamp = isoFormatter.string(from: baseNow.addingTimeInterval(-30))

        // Seed alpha's cached quota so drift matching can resolve its display name.
        accountsService.recordSharedAuthUsageSuccess(
            credentials: CodexCredentials(accessToken: "tok-alpha", accountID: "acct-alpha"),
            snapshot: UsageSnapshot(
                windows: [
                    UsageWindow(id: "primary", kind: .rolling(hours: 5), usedPercent: 10, resetAt: alphaPrimaryReset),
                    UsageWindow(id: "secondary", kind: .weekly, usedPercent: 55, resetAt: alphaWeeklyReset)
                ],
                fetchedAt: baseNow.addingTimeInterval(-7_000)
            )
        )
        XCTAssertEqual(accountsService.activeAccountID, alpha.id)

        // External tool rewrites ~/.codex/auth.json to beta while Codex Desktop (launched earlier) stays on alpha.
        let authURL = codexHome.appendingPathComponent("auth.json")
        try authBeta.write(to: authURL, options: .atomic)
        let authModifiedAt = baseNow.addingTimeInterval(-3_362)
        try FileManager.default.setAttributes([.modificationDate: authModifiedAt], ofItemAtPath: authURL.path)

        var codexLaunchDate = baseNow.addingTimeInterval(-7_080) // before auth.json rewrite
        var resetPostCount = 0

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SyncMockURLProtocol.self]
        config.urlCache = nil
        let usageEndpoint = URL(string: "https://sync-fixture.test/backend-api/wham/usage")!
        SyncMockURLProtocol.handler = { request in
            let body: String
            switch (request.httpMethod, request.url?.lastPathComponent) {
            case ("GET", "usage"):
                body = """
                {
                  "rate_limit": {
                    "primary_window": {"used_percent": 0, "limit_window_seconds": 18000, "reset_at": \(betaPrimaryResetEpoch)},
                    "secondary_window": {"used_percent": 44, "limit_window_seconds": 604800, "reset_at": \(betaWeeklyResetEpoch)}
                  },
                  "rate_limit_reset_credits": {"available_count": 1}
                }
                """
            case ("GET", "rate-limit-reset-credits"):
                body = #"{"available_count":1,"credits":[{"id":"beta-credit","status":"available","expires_at":null}]}"#
            case ("POST", "consume"):
                resetPostCount += 1
                body = #"{"code":"reset"}"#
            default:
                body = "{}"
            }
            let response = HTTPURLResponse(
                url: request.url ?? usageEndpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(body.utf8))
        }
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        let suiteName = "SessionAuthSyncTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set(AppLanguage.chinese.rawValue, forKey: AppLanguage.storageKey)
        defaults.set(false, forKey: AppAnimationPreference.storageKey)
        defaults.set(true, forKey: NotchDisplayPreference.storageKey)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = NotchViewModel()
        let dialogs = ResetCreditDialogPresenter()
        let windowController = NotchWindowController()
        let coordinator = NotchRuntimeCoordinator(
            windowController: windowController,
            authReader: CodexAuthReader(codexHome: codexHome),
            sessionStore: ActiveSessionStore(),
            urlSession: session,
            usageEndpoint: usageEndpoint,
            nowProvider: { baseNow },
            codexAppLaunchDateProvider: { codexLaunchDate },
            userDefaults: defaults,
            viewModel: viewModel,
            resetDialogs: dialogs,
            accountsService: accountsService
        )
        defer {
            coordinator.stop()
            dialogs.dismiss()
            windowController.close()
        }

        coordinator.start()

        // 1. Option 1: activeAccountID immediately reconciles to beta matching auth.json.
        try await waitUntil {
            accountsService.activeAccountID == beta.id
                && self.usage(in: viewModel.state)?.weeklyWindow?.remainingPercent == 56
        }
        XCTAssertNil(viewModel.sessionAuthDrift)

        // 2. Option 2: Codex (still running alpha) emits a rollout token_count after auth.json mtime.
        let rolloutFile = sessionsDir.appendingPathComponent("live.jsonl")
        let turn1 = """
        {"timestamp":"\(turn1MetaTimestamp)","type":"session_meta","payload":{"id":"t-live","cwd":"/tmp/app","originator":"Codex Desktop"}}
        {"timestamp":"\(turn1EventTimestamp)","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":11,"window_minutes":300,"resets_at":\(alphaPrimaryResetEpoch)},"secondary":{"used_percent":55,"window_minutes":10080,"resets_at":\(alphaWeeklyResetEpoch)},"plan_type":"plus"}}}

        """
        try Data(turn1.utf8).write(to: rolloutFile, options: .atomic)

        try await waitUntil {
            viewModel.sessionAuthDrift != nil
                && self.usage(in: viewModel.state)?.fiveHourWindow?.remainingPercent == 89
                && self.usage(in: viewModel.state)?.weeklyWindow?.remainingPercent == 45
        }
        XCTAssertEqual(viewModel.sessionAuthDrift?.liveAccountName, "alpha")
        XCTAssertEqual(viewModel.sessionAuthDrift?.diskAccountName, "beta")
        XCTAssertEqual(usage(in: viewModel.state)?.resetCredits, [])

        // Reset credit redemption must be blocked during split-brain so beta's credit cannot be redeemed by mistake.
        viewModel.onUseResetCredit(ResetCredit(id: "beta-credit"))
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertFalse(dialogs.isPresenting)
        XCTAssertEqual(resetPostCount, 0)

        // 3. Another rollout turn drops alpha's quota further -> notch updates live without waiting for 60s poll.
        let handle = try FileHandle(forWritingTo: rolloutFile)
        try handle.seekToEnd()
        let turn2 = """
        {"timestamp":"\(turn2EventTimestamp)","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":15,"window_minutes":300,"resets_at":\(alphaPrimaryResetEpoch)},"secondary":{"used_percent":56,"window_minutes":10080,"resets_at":\(alphaWeeklyResetEpoch)},"plan_type":"plus"}}}

        """
        try handle.write(contentsOf: Data(turn2.utf8))
        try handle.close()

        try await waitUntil {
            self.usage(in: viewModel.state)?.fiveHourWindow?.remainingPercent == 85
                && self.usage(in: viewModel.state)?.weeklyWindow?.remainingPercent == 44
        }

        // 4. User restarts Codex Desktop (launchDate > rollout) -> hovering clears drift and restores beta's quota & reset credits.
        codexLaunchDate = baseNow.addingTimeInterval(300)
        viewModel.onHoverChanged(true)
        try await waitUntil {
            viewModel.sessionAuthDrift == nil
                && self.usage(in: viewModel.state)?.fiveHourWindow?.remainingPercent == 100
                && self.usage(in: viewModel.state)?.weeklyWindow?.remainingPercent == 56
                && self.usage(in: viewModel.state)?.resetCredits.count == 1
        }
    }

    // MARK: - Helpers

    private func usage(in state: NotchPresentationState) -> UsageSnapshot? {
        switch state {
        case .hidden: return nil
        case let .quotaCompact(usage), let .workingCompact(_, _, usage), let .completedCompact(_, usage):
            return usage
        case let .expanded(content):
            return content.usage
        }
    }

    private func waitUntil(
        _ condition: () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let deadline = Date().addingTimeInterval(4)
        while !condition() && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        _ = try XCTUnwrap(condition() ? true : nil, "Timed out waiting for expected runtime state", file: file, line: line)
    }

    private func makeAuthData(
        email: String,
        accountID: String,
        accessToken: String,
        plan: String = "plus",
        lastRefresh: String = "2026-11-18T16:09:36Z"
    ) -> Data {
        let header = base64URL(#"{"alg":"none","typ":"JWT"}"#)
        let payloadJSON = """
        {"email":"\(email)","https://api.openai.com/auth":{"chatgpt_account_id":"\(accountID)","chatgpt_plan_type":"\(plan)"}}
        """
        let idToken = "\(header).\(base64URL(payloadJSON)).sig"
        let rootObject: [String: Any] = [
            "auth_mode": "chatgpt",
            "last_refresh": lastRefresh,
            "tokens": [
                "id_token": idToken,
                "access_token": accessToken,
                "account_id": accountID
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: rootObject, options: [.sortedKeys])
    }

    private func base64URL(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private final class SyncFakeCodexLauncher: CodexLaunching {
    func quit() async {}
    func launchShared() async throws {}
}

private final class SyncMockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
