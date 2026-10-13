import AppKit
import Foundation
import XCTest
@testable import CodexNotch

@MainActor
final class ResetCreditRuntimeTests: XCTestCase {
    func testCancelCollapsesCardWithoutPostAndAllowsAnotherConfirmation() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        try await start(fixture)
        try await openConfirmation(fixture)

        XCTAssertTrue(fixture.model.isUsingResetCredit)
        XCTAssertTrue(fixture.model.isAwaitingResetConfirmation)
        XCTAssertFalse(isExpanded(fixture.model.state))
        XCTAssertFalse(fixture.model.isResetScheduleExpanded)
        XCTAssertEqual(fixture.backend.postCount, 0)
        try press("Cancel", in: fixture.dialogs)
        XCTAssertFalse(fixture.model.isUsingResetCredit)
        XCTAssertFalse(fixture.model.isAwaitingResetConfirmation)
        XCTAssertFalse(fixture.dialogs.isPresenting)

        try await openConfirmation(fixture)
        XCTAssertTrue(fixture.model.isAwaitingResetConfirmation)
        try XCTUnwrap(fixture.dialogs.window).performClose(nil)
        XCTAssertFalse(fixture.model.isUsingResetCredit)
        XCTAssertFalse(fixture.model.isAwaitingResetConfirmation)
        XCTAssertEqual(fixture.backend.postCount, 0)
    }

    func testConfirmationPostsOnceAndReadbackRemovesLastCreditBeforeResult() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        try await start(fixture)
        let selected = try XCTUnwrap(usage(fixture.model.state)?.resetCredits.first)
        fixture.backend.pauseNext(.postUsage)
        try await openConfirmation(fixture)
        let confirmationWindow = try XCTUnwrap(fixture.dialogs.window)
        confirmationWindow.orderOut(nil)
        fixture.model.onUseResetCredit(selected)
        fixture.model.onUseResetCredit(selected)
        try await waitUntil { confirmationWindow.isVisible }
        XCTAssertTrue(fixture.dialogs.window === confirmationWindow)
        XCTAssertTrue(fixture.model.isAwaitingResetConfirmation)
        XCTAssertEqual(fixture.backend.postCount, 0,
                       "Repeated actions while awaiting confirmation must not submit")
        try press("Use reset", in: fixture.dialogs)
        try await waitUntil { fixture.backend.hasHeldRequest }

        XCTAssertEqual(fixture.backend.postCount, 1)
        XCTAssertTrue(fixture.model.isUsingResetCredit)
        XCTAssertFalse(fixture.model.isAwaitingResetConfirmation)
        XCTAssertFalse(fixture.dialogs.isPresenting)
        XCTAssertEqual(usage(fixture.model.state)?.weeklyWindow?.usedPercent, 60,
                       "A POST result must not fabricate a quota value before readback")
        fixture.model.onUseResetCredit(selected)
        fixture.model.onUseResetCredit(selected)
        // Give the queued MainActor button callbacks time to run while the
        // controlled readback remains suspended, instead of racing its release.
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(fixture.backend.postCount, 1)
        XCTAssertTrue(fixture.model.isUsingResetCredit)
        XCTAssertFalse(fixture.dialogs.isPresenting,
                       "An in-flight redemption must not open another confirmation")
        fixture.backend.resumeHeldRequest()
        try await waitUntil { fixture.dialogs.isPresenting && !fixture.model.isUsingResetCredit }

        XCTAssertEqual(usage(fixture.model.state)?.weeklyWindow?.usedPercent, 5)
        XCTAssertEqual(usage(fixture.model.state)?.resetCreditsAvailable, 0)
        XCTAssertEqual(usage(fixture.model.state)?.resetCredits.count, 0)
        XCTAssertFalse(fixture.model.isAwaitingResetConfirmation)
        let resultWindow = try XCTUnwrap(fixture.dialogs.window)
        XCTAssertTrue(text(in: resultWindow.contentView).contains("confirmed that your usage was reset"))
        XCTAssertTrue(text(in: resultWindow.contentView).contains("have been fetched again"))

        // A click from a still-rendered row must recover the existing result,
        // even after the authoritative list has removed that credit.
        resultWindow.orderOut(nil)
        fixture.model.onUseResetCredit(selected)
        try await waitUntil { resultWindow.isVisible }
        XCTAssertTrue(fixture.dialogs.window === resultWindow)
        XCTAssertEqual(fixture.backend.postCount, 1)
        XCTAssertFalse(fixture.model.isAwaitingResetConfirmation)
        try press("OK", in: fixture.dialogs)
        XCTAssertFalse(fixture.dialogs.isPresenting)
    }

    func testAuthoritativeZeroAtPreflightRejectsStaleCreditWithoutPost() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        try await start(fixture)
        try await openConfirmation(fixture)
        fixture.backend.expireCreditsKeepingStaleRows()
        try press("Use reset", in: fixture.dialogs)
        try await waitUntil { fixture.dialogs.isPresenting && !fixture.model.isUsingResetCredit }

        XCTAssertEqual(fixture.backend.postCount, 0)
        XCTAssertEqual(usage(fixture.model.state)?.resetCreditsAvailable, 0)
        XCTAssertEqual(usage(fixture.model.state)?.resetCredits.count, 0)
        let resultWindow = try XCTUnwrap(fixture.dialogs.window)
        XCTAssertTrue(text(in: resultWindow.contentView).contains("unavailable. No reset was submitted"))
        try press("OK", in: fixture.dialogs)
    }

    func testAccountChangeDuringReadbackKeepsSnapshotAndReportsRefreshFailure() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        try await start(fixture)
        fixture.backend.pauseNext(.postUsage)
        try await openConfirmation(fixture)
        try press("Use reset", in: fixture.dialogs)
        try await waitUntil { fixture.backend.hasHeldRequest }
        try fixture.writeAuth(account: "other-fixture-account")
        fixture.backend.resumeHeldRequest()
        try await waitUntil { fixture.dialogs.isPresenting && !fixture.model.isUsingResetCredit }

        XCTAssertEqual(fixture.backend.postCount, 1)
        XCTAssertEqual(usage(fixture.model.state)?.weeklyWindow?.usedPercent, 60)
        let message = text(in: try XCTUnwrap(fixture.dialogs.window).contentView)
        XCTAssertTrue(message.contains("confirmed that your usage was reset"))
        XCTAssertTrue(message.contains("could not be refreshed"))
        XCTAssertFalse(fixture.model.isAwaitingResetConfirmation)
        try press("OK", in: fixture.dialogs)
    }

    func testStoppingDuringPreflightCancelsWithoutPostOrResultWindow() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        try await start(fixture)
        fixture.backend.pauseNext(.preflightCredits)
        try await openConfirmation(fixture)
        try press("Use reset", in: fixture.dialogs)
        try await waitUntil { fixture.backend.hasHeldRequest }
        fixture.runtime.stop()
        try await waitUntil { fixture.backend.heldRequestWasCancelled }
        fixture.backend.resumeHeldRequest()

        XCTAssertEqual(fixture.backend.postCount, 0)
        XCTAssertEqual(fixture.model.state, .hidden)
        XCTAssertFalse(fixture.model.isUsingResetCredit)
        XCTAssertFalse(fixture.model.isAwaitingResetConfirmation)
        XCTAssertFalse(fixture.dialogs.isPresenting)
    }

    private func start(_ fixture: Fixture) async throws {
        fixture.runtime.start()
        try await waitUntil { usage(fixture.model.state)?.resetCredits.count == 1 }
    }

    private func openConfirmation(_ fixture: Fixture) async throws {
        fixture.model.onHoverChanged(true)
        try await waitUntil { isExpanded(fixture.model.state) }
        fixture.model.onResetScheduleExpandedChanged(true)
        XCTAssertTrue(fixture.model.isResetScheduleExpanded)
        let credit = try XCTUnwrap(usage(fixture.model.state)?.resetCredits.first)
        fixture.model.onUseResetCredit(credit)
        try await waitUntil { fixture.dialogs.isPresenting }
    }

    private func waitUntil(_ condition: () -> Bool,
                           file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !condition() && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        _ = try XCTUnwrap(condition() ? true : nil, "Runtime did not reach the expected state", file: file, line: line)
    }

    private func isExpanded(_ state: NotchPresentationState) -> Bool {
        if case .expanded = state { return true }
        return false
    }

    private func usage(_ state: NotchPresentationState) -> UsageSnapshot? {
        switch state {
        case .hidden: return nil
        case .quotaCompact(let usage), .workingCompact(_, _, let usage), .completedCompact(_, let usage):
            return usage
        case .expanded(let content): return content.usage
        }
    }

    private func press(_ title: String, in presenter: ResetCreditDialogPresenter) throws {
        func buttons(_ view: NSView?) -> [NSButton] {
            guard let view else { return [] }
            return (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { buttons($0) }
        }
        let window = try XCTUnwrap(presenter.window)
        try XCTUnwrap(buttons(window.contentView).first { $0.title == title }).performClick(nil)
    }

    private func text(in view: NSView?) -> String {
        guard let view else { return "" }
        return (((view as? NSTextField).map { [$0.stringValue] } ?? [])
            + view.subviews.map { text(in: $0) }).joined(separator: "\n")
    }

    @MainActor
    private final class Fixture {
        let root: URL
        let defaults: UserDefaults
        let suiteName = "ResetCreditRuntimeTests.\(UUID().uuidString)"
        let backend = RuntimeResetBackend()
        let model = NotchViewModel()
        let dialogs = ResetCreditDialogPresenter()
        let windowController: NotchWindowController
        let session: URLSession
        let runtime: NotchRuntimeCoordinator

        init() throws {
            _ = NSApplication.shared
            windowController = NotchWindowController()
            root = FileManager.default.temporaryDirectory.appendingPathComponent(suiteName, isDirectory: true)
            try FileManager.default.createDirectory(at: root.appendingPathComponent("sessions"),
                                                    withIntermediateDirectories: true)
            defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
            defaults.set(AppLanguage.english.rawValue, forKey: AppLanguage.storageKey)
            defaults.set(false, forKey: AppAnimationPreference.storageKey)
            defaults.set(true, forKey: NotchDisplayPreference.storageKey)
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [RuntimeResetURLProtocol.self]
            configuration.urlCache = nil
            RuntimeResetURLProtocol.backend = backend
            session = URLSession(configuration: configuration)
            runtime = NotchRuntimeCoordinator(
                windowController: windowController,
                authReader: CodexAuthReader(environment: ["CODEX_HOME": root.path], homeDirectory: root),
                sessionStore: ActiveSessionStore(), urlSession: session,
                usageEndpoint: URL(string: "https://runtime-fixture.test/backend-api/wham/usage")!,
                nowProvider: { Date(timeIntervalSince1970: 1_790_000_000) }, userDefaults: defaults,
                viewModel: model, resetDialogs: dialogs
            )
            try writeAuth(account: "fixture-account")
        }

        func writeAuth(account: String) throws {
            let data = try JSONSerialization.data(withJSONObject: [
                "tokens": ["access_token": "fixture-token", "account_id": account]
            ])
            try data.write(to: root.appendingPathComponent("auth.json"), options: .atomic)
        }

        func close() {
            runtime.stop()
            dialogs.dismiss()
            windowController.close()
            session.invalidateAndCancel()
            RuntimeResetURLProtocol.backend = nil
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }
    }
}

/// All requests, including unexpected ones, are intercepted; this fixture never
/// falls through to the network or reads the actual Codex home directory.
private final class RuntimeResetURLProtocol: URLProtocol {
    static var backend: RuntimeResetBackend?
    private let lock = NSLock()
    private var cancelled = false
    var wasCancelled: Bool { lock.withLock { cancelled } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let backend = Self.backend else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        backend.receive(self)
    }
    override func stopLoading() { lock.withLock { cancelled = true } }
    func complete(_ data: Data) {
        guard !wasCancelled else { return }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

private final class RuntimeResetBackend {
    enum Pause { case preflightCredits, postUsage }
    private let lock = NSLock()
    private var posts = 0
    private var expired = false
    private var pause: Pause?
    private var held: (RuntimeResetURLProtocol, Data)?
    var postCount: Int { lock.withLock { posts } }
    var hasHeldRequest: Bool { lock.withLock { held != nil } }
    var heldRequestWasCancelled: Bool { lock.withLock { held?.0.wasCancelled == true } }

    func pauseNext(_ pause: Pause) { lock.withLock { self.pause = pause } }
    func expireCreditsKeepingStaleRows() { lock.withLock { expired = true } }
    func resumeHeldRequest() {
        let pending = lock.withLock { () -> (RuntimeResetURLProtocol, Data)? in
            defer { held = nil }
            return held
        }
        if let (request, data) = pending { request.complete(data) }
    }

    func receive(_ loader: RuntimeResetURLProtocol) {
        let request = loader.request
        XCTAssertEqual(request.url?.host, "runtime-fixture.test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-token")
        let response: Data? = lock.withLock {
            let body: String
            let shouldHold: Bool
            switch (request.httpMethod, request.url?.lastPathComponent) {
            case ("GET", "usage"):
                body = """
                {"primary_window":{"used_percent":\(posts == 0 ? 60 : 5),"limit_window_seconds":604800,"reset_at":1893456000},"rate_limit_reset_credits":{"available_count":1}}
                """
                shouldHold = pause == .postUsage && posts > 0
            case ("GET", "rate-limit-reset-credits"):
                let row = #"{"id":"fixture-credit","status":"available","expires_at":null}"#
                body = "{\"available_count\":\(posts > 0 || expired ? 0 : 1),\"credits\":[\(posts > 0 ? "" : row)]}"
                shouldHold = pause == .preflightCredits
            case ("POST", "consume"):
                posts += 1
                body = #"{"code":"reset","windows_reset":1}"#
                shouldHold = false
            default:
                XCTFail("Unexpected fixture request")
                body = "{}"
                shouldHold = false
            }
            let data = Data(body.utf8)
            if shouldHold {
                pause = nil
                held = (loader, data)
                return nil
            }
            return data
        }
        if let response { loader.complete(response) }
    }
}
