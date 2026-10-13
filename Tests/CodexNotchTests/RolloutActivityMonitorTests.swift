import Foundation
import XCTest
@testable import CodexNotch

final class RolloutActivityMonitorTests: XCTestCase {
    @MainActor
    func testRestartCannotDeliverOldScanCompletionThroughTheNewStartHandler() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("feedback-restart-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("history.jsonl")
        let data = """
        {"timestamp":"2026-10-01T01:00:00Z","type":"session_meta","payload":{"id":"old-history"}}
        {"timestamp":"2026-10-01T01:00:01Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn"}}
        {"timestamp":"2026-10-01T01:00:02Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn"}}

        """
        try Data(data.utf8).write(to: file)
        let reader = RestartBlockingReader()
        let monitor = RolloutActivityMonitor(rootURL: root, reader: reader)
        defer {
            reader.firstGate.signal()
            reader.secondGate.signal()
            monitor.stop()
        }
        var oldCallbacks = 0
        var newCallbacks = 0
        monitor.onInitialScanCompleted = { _ in oldCallbacks += 1 }
        monitor.start()
        try await waitFor { reader.calls == 1 }
        monitor.stop()
        monitor.onInitialScanCompleted = { _ in newCallbacks += 1 }
        monitor.start()
        // The changed size forces another read on the new scan. It changes no
        // task lifecycle and lets this test hold each startup independently.
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"type\":\"ignored\"}\n".utf8))
        try handle.close()
        reader.firstGate.signal()
        try await waitFor { reader.calls == 2 && oldCallbacks == 1 }
        XCTAssertEqual(newCallbacks, 0, "The old scan must not announce that the new blocked scan is ready")
        reader.secondGate.signal()
        try await waitFor { newCallbacks == 1 }
        XCTAssertEqual(oldCallbacks, 1)
    }

    @MainActor
    private func waitFor(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !condition() && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        _ = try XCTUnwrap(condition() ? true : nil, "Timed out waiting for the controlled scan")
    }

    @MainActor
    func testInitialScanCompletionFollowsAllHistoryPublicationsAndDoesNotRepeatOnRescan() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("feedback-initial-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for index in 0..<2 {
            let data = """
            {"timestamp":"2026-10-01T01:00:00Z","type":"session_meta","payload":{"id":"history-\(index)"}}
            {"timestamp":"2026-10-01T01:00:01Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn"}}
            {"timestamp":"2026-10-01T01:00:02Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn"}}

            """
            try Data(data.utf8).write(to: root.appendingPathComponent("\(index).jsonl"))
        }
        let store = ActiveSessionStore()
        let monitor = RolloutActivityMonitor(rootURL: root, store: store)
        var publishedChanges = 0
        var initialCallbacks = 0
        let initialized = expectation(description: "Initial history fully committed")
        initialized.assertForOverFulfill = true
        monitor.onChange = { publishedChanges += 1 }
        monitor.onInitialScanCompleted = { snapshot in
            initialCallbacks += 1
            XCTAssertEqual(publishedChanges, 2, "The readiness event must follow the per-file main-queue publications")
            XCTAssertEqual(snapshot.recentCompletions.count, 2, "Readiness cannot precede ordered store commits")
            initialized.fulfill()
        }
        monitor.start()
        defer { monitor.stop() }
        await fulfillment(of: [initialized], timeout: 3)
        monitor.rescan()
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(initialCallbacks, 1)
        XCTAssertEqual(publishedChanges, 2, "Unchanged recovery must not republish history")
    }

    func testMonitorPublishesActiveSessionWithParsedTimestamp() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-notch-monitor-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("rollout-active.jsonl")
        let rolloutURL = rootURL.appendingPathComponent("live.jsonl")
        try FileManager.default.copyItem(at: fixtureURL, to: rolloutURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: rolloutURL.path
        )

        let store = ActiveSessionStore()
        let monitor = RolloutActivityMonitor(rootURL: rootURL, store: store)
        monitor.start()
        defer { monitor.stop() }

        var snapshot = await store.snapshot()
        for _ in 0..<20 where snapshot.activeSessions.isEmpty {
            try await Task.sleep(nanoseconds: 50_000_000)
            snapshot = await store.snapshot()
        }

        XCTAssertEqual(snapshot.activeSessions.count, 1)
        XCTAssertEqual(snapshot.activeSessions.first?.threadID, "thread-live")
        XCTAssertEqual(snapshot.activeSessions.first?.cwd, "/tmp/codex-notch-live")
        XCTAssertEqual(
            snapshot.activeSessions.first?.startedAt,
            Date(timeIntervalSince1970: 1_784_192_401)
        )
    }

    func testRescanPicksUpSessionsDirectoryCreatedAfterStart() async throws {
        let codexHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-notch-late-\(UUID().uuidString)", isDirectory: true)
        let sessionsURL = codexHome.appendingPathComponent("sessions", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: codexHome)
        }

        let store = ActiveSessionStore()
        let monitor = RolloutActivityMonitor(rootURL: sessionsURL, store: store)
        monitor.start()
        defer { monitor.stop() }

        try FileManager.default.createDirectory(at: sessionsURL, withIntermediateDirectories: true)
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("rollout-active.jsonl")
        let rolloutURL = sessionsURL.appendingPathComponent("live.jsonl")
        try FileManager.default.copyItem(
            at: fixtureURL,
            to: rolloutURL
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: rolloutURL.path
        )
        monitor.rescan()

        var snapshot = await store.snapshot()
        for _ in 0..<20 where snapshot.activeSessions.isEmpty {
            try await Task.sleep(nanoseconds: 50_000_000)
            snapshot = await store.snapshot()
        }

        XCTAssertEqual(snapshot.activeSessions.first?.threadID, "thread-live")
    }
}

private final class RestartBlockingReader: IncrementalReading, @unchecked Sendable {
    private let reader = IncrementalJSONLReader()
    private let lock = NSLock()
    private var count = 0
    let firstGate = DispatchSemaphore(value: 0)
    let secondGate = DispatchSemaphore(value: 0)
    var calls: Int { lock.withLock { count } }

    func readNewLines(at url: URL, cursor: inout FileCursor) throws -> [Data] {
        let call = lock.withLock { count += 1; return count }
        if call == 1 { _ = firstGate.wait(timeout: .now() + 5) }
        if call == 2 { _ = secondGate.wait(timeout: .now() + 5) }
        return try reader.readNewLines(at: url, cursor: &cursor)
    }
}
