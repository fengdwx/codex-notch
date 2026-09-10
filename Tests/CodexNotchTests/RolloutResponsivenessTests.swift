import Foundation
import XCTest
@testable import CodexNotch

final class RolloutResponsivenessTests: XCTestCase {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-notch-responsive-\(UUID().uuidString)")
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func started(thread: String = "responsive", turn: String = "turn") -> Data {
        Data("""
        {"timestamp":"2026-09-06T01:00:00Z","type":"session_meta","payload":{"id":"\(thread)","source":"vscode"}}
        {"timestamp":"2026-09-06T01:00:01Z","type":"event_msg","payload":{"type":"task_started","turn_id":"\(turn)"}}

        """.utf8)
    }

    private func completed(turn: String = "turn") -> Data {
        Data("{\"timestamp\":\"2026-09-06T01:00:02Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_complete\",\"turn_id\":\"\(turn)\"}}\n".utf8)
    }

    private func append(_ data: Data, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    private func eventually(_ condition: @escaping () async -> Bool) async throws {
        for _ in 0..<200 {
            if await condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("The filesystem update did not reach the session store within two seconds")
    }

    func testRealFilesystemStartAndCompletionNotifyWithoutAnyRecoveryOrUITimer() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ActiveSessionStore()
        let monitor = RolloutActivityMonitor(rootURL: root, store: store)
        let active = expectation(description: "file creation publishes running")
        let done = expectation(description: "append publishes completed")
        let observations = TransitionObservations()
        monitor.onChange = {
            Task {
                let snapshot = await store.snapshot()
                if !snapshot.activeSessions.isEmpty {
                    if await observations.recordStart() { active.fulfill() }
                } else if !snapshot.recentCompletions.isEmpty {
                    if await observations.recordCompletion() { done.fulfill() }
                }
            }
        }
        monitor.start()
        defer { monitor.stop() }
        // Let the real FSEvent stream subscribe before creating a new rollout.
        try await Task.sleep(nanoseconds: 200_000_000)
        let file = root.appendingPathComponent("new.jsonl")
        let startedAt = Date()
        try started().write(to: file)
        await fulfillment(of: [active], timeout: 2)
        let completedAt = Date()
        try append(completed(), to: file)
        await fulfillment(of: [done], timeout: 2)
        let snapshot = await store.snapshot()
        XCTAssertTrue(snapshot.activeSessions.isEmpty)
        XCTAssertEqual(snapshot.recentCompletions.first?.session.threadID, "responsive")
        let times = await observations.times()
        print("Filesystem-to-notification: start \(Int(try XCTUnwrap(times.0).timeIntervalSince(startedAt) * 1000)) ms, completion \(Int(try XCTUnwrap(times.1).timeIntervalSince(completedAt) * 1000)) ms")
    }

    func testRecoverySkipsUnchangedLogsAndAnEventReadsOnlyItsChangedFile() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let files = (0..<3).map { root.appendingPathComponent("\($0).jsonl") }
        for (index, file) in files.enumerated() {
            try started(thread: "thread-\(index)").write(to: file)
        }
        let reader = CountingRolloutReader()
        let store = ActiveSessionStore()
        let monitor = RolloutActivityMonitor(rootURL: root, store: store, reader: reader)
        monitor.start()
        defer { monitor.stop() }
        try await eventually { await store.snapshot().activeSessions.count == 3 }
        monitor.rescan()
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(reader.totalReads, 3, "Recovery must only stat unchanged logs")
        try append(completed(), to: files[0])
        monitor.filesDidChange([files[0]])
        try await eventually { await store.snapshot().activeSessions.count == 2 }
        XCTAssertEqual(reader.reads(at: files[0]), 2)
        XCTAssertEqual(reader.reads(at: files[1]), 1)
        XCTAssertEqual(reader.reads(at: files[2]), 1)
    }

    func testAtomicReplacementAndRemovalCannotKeepAnOldTaskRunning() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("replace.jsonl")
        try started(thread: "old").write(to: file)
        let store = ActiveSessionStore()
        let monitor = RolloutActivityMonitor(rootURL: root, store: store)
        monitor.start()
        defer { monitor.stop() }
        try await eventually { await store.snapshot().activeSessions.first?.threadID == "old" }
        try (started(thread: "replacement-longer") + completed()).write(to: file, options: .atomic)
        monitor.filesDidChange([file])
        try await eventually { await store.snapshot().recentCompletions.first?.session.threadID == "replacement-longer" }
        let replaced = await store.snapshot()
        XCTAssertTrue(replaced.activeSessions.isEmpty)
        XCTAssertFalse(replaced.recentCompletions.contains { $0.session.threadID == "old" })
        try FileManager.default.removeItem(at: file)
        monitor.filesDidChange([file])
        try await eventually { await store.snapshot().recentCompletions.isEmpty }
    }

    func testPartialTerminalLineWaitsForNewlineAndStopIgnoresLaterChanges() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("partial.jsonl")
        try started().write(to: file)
        let reader = CountingRolloutReader()
        let store = ActiveSessionStore()
        let monitor = RolloutActivityMonitor(rootURL: root, store: store, reader: reader)
        monitor.start()
        defer { monitor.stop() }
        try await eventually { await store.snapshot().activeSessions.count == 1 }
        try append(Data(completed().dropLast()), to: file)
        monitor.filesDidChange([file])
        try await eventually { reader.totalReads >= 2 }
        let partial = await store.snapshot()
        XCTAssertEqual(partial.activeSessions.count, 1)
        try append(Data([0x0A]), to: file)
        monitor.filesDidChange([file])
        try await eventually { await store.snapshot().activeSessions.isEmpty }
        monitor.stop()
        let readsBeforeStop = reader.totalReads
        try append(started(thread: "later"), to: file)
        monitor.filesDidChange([file])
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(reader.totalReads, readsBeforeStop)
        let stopped = await store.snapshot()
        XCTAssertTrue(stopped.activeSessions.isEmpty)
    }
}

private actor TransitionObservations {
    private var start: Date?
    private var completion: Date?
    func recordStart() -> Bool {
        guard start == nil else { return false }
        start = Date()
        return true
    }
    func recordCompletion() -> Bool {
        guard completion == nil else { return false }
        completion = Date()
        return true
    }
    func times() -> (Date?, Date?) { (start, completion) }
}

private final class CountingRolloutReader: IncrementalReading, @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [URL: Int] = [:]
    var totalReads: Int {
        lock.lock()
        defer { lock.unlock() }
        return counts.values.reduce(0, +)
    }
    func reads(at url: URL) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return counts[url, default: 0]
    }
    func readNewLines(at url: URL, cursor: inout FileCursor) throws -> [Data] {
        lock.lock()
        counts[url, default: 0] += 1
        lock.unlock()
        return try IncrementalJSONLReader().readNewLines(at: url, cursor: &cursor)
    }
}
