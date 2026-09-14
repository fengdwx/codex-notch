import Foundation
import XCTest
@testable import CodexNotch

final class RecentConversationHistoryTests: XCTestCase {
    func testRestartLoadsHistoryAcrossWeeksAndAppliesEveryConfiguredLimit() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        for index in 0..<5 {
            try writeRollout(root: root, name: "history-\(index)", thread: "thread-\(index)", daysAgo: 3 + index * 7)
        }
        // These newer files must not consume the five top-level history slots.
        try writeRollout(root: root, name: "child", thread: "child", daysAgo: 1, subagent: true)
        try writeRollout(root: root, name: "unfinished", thread: "unfinished", daysAgo: 2, complete: false)
        try writeRollout(root: root, name: "duplicate", thread: "thread-0", daysAgo: 4)

        let suite = "RecentConversationHistoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        for _ in 0..<2 {
            let store = ActiveSessionStore()
            let monitor = RolloutActivityMonitor(rootURL: root, store: store)
            monitor.start()
            defer { monitor.stop() }
            let loaded = await waitForHistory(store, count: 5)
            XCTAssertTrue(loaded.activeSessions.isEmpty, "Old unfinished work must not appear running")
            XCTAssertEqual(loaded.recentCompletions.map(\.session.threadID), (0..<5).map { "thread-\($0)" })

            for limit in [5, 1, 0, 3, 2, 4, 5] {
                defaults.set(limit, forKey: RecentConversationLimit.storageKey)
                let state = NotchPresentationReducer.reduce(NotchPresentationInput(
                    now: .now, isChatGPTFrontmost: false,
                    activeSessions: loaded.activeSessions, recentCompletions: loaded.recentCompletions,
                    usage: nil, isHovered: true
                )).limitingRecentConversations(to: NotchRuntimePreferences.read(from: defaults).recentConversationLimit)
                guard case let .expanded(content) = state else { return XCTFail("Expected expanded history") }
                XCTAssertEqual(content.conversations.map(\.threadID), (0..<limit).map { "thread-\($0)" })
            }
            monitor.stop()
        }
    }

    func testDiscoveryStopsAfterEnoughHistoryAndBackfillsDeletedRecords() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var files: [URL] = []
        for index in 0..<8 {
            files.append(try writeRollout(root: root, name: "history-\(index)", thread: "thread-\(index)", daysAgo: 3 + index))
        }
        let reader = HistoryCountingReader()
        let store = ActiveSessionStore()
        let monitor = RolloutActivityMonitor(rootURL: root, store: store, reader: reader)
        monitor.start()
        defer { monitor.stop() }
        _ = await waitForHistory(store, count: 5)
        monitor.rescan()
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(reader.reads, 5, "Do not parse older logs or reread unchanged history")

        try FileManager.default.removeItem(at: files[0])
        monitor.filesDidChange([files[0]])
        monitor.rescan()
        var snapshot = await store.snapshot()
        for _ in 0..<100 where snapshot.recentCompletions.last?.session.threadID != "thread-5" {
            try await Task.sleep(nanoseconds: 20_000_000)
            snapshot = await store.snapshot()
        }
        XCTAssertEqual(snapshot.recentCompletions.map(\.session.threadID), (1...5).map { "thread-\($0)" })
        XCTAssertEqual(reader.reads, 6, "Backfill should only read the next older rollout")
    }

    func testRecentlyTouchedOldLogDoesNotDisplaceNewerConversations() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        for index in 0..<6 {
            try writeRollout(root: root, name: "history-\(index)", thread: "thread-\(index)", daysAgo: 3 + index)
        }
        let oldLog = try writeRollout(root: root, name: "touched", thread: "ancient", daysAgo: 365)
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: oldLog.path)
        let store = ActiveSessionStore()
        let reader = HistoryCountingReader()
        let monitor = RolloutActivityMonitor(rootURL: root, store: store, reader: reader)
        monitor.start()
        defer { monitor.stop() }
        let snapshot = await waitForHistory(store, count: 6)
        let state = NotchPresentationReducer.reduce(NotchPresentationInput(
            now: .now, isChatGPTFrontmost: false, activeSessions: snapshot.activeSessions,
            recentCompletions: snapshot.recentCompletions, usage: nil, isHovered: true
        )).limitingRecentConversations(to: .five)
        guard case let .expanded(content) = state else { return XCTFail("Expected expanded history") }
        XCTAssertEqual(content.conversations.map(\.threadID), (0..<5).map { "thread-\($0)" })
        XCTAssertEqual(reader.reads, 6)
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-notch-history-\(UUID().uuidString)")
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @discardableResult
    private func writeRollout(
        root: URL, name: String, thread: String, daysAgo: Int,
        complete: Bool = true, subagent: Bool = false
    ) throws -> URL {
        let finishedAt = Date().addingTimeInterval(-Double(daysAgo * 86_400))
        let formatter = ISO8601DateFormatter()
        let start = formatter.string(from: finishedAt.addingTimeInterval(-60))
        let end = formatter.string(from: finishedAt)
        let parent = subagent ? ",\"parent_thread_id\":\"parent\"" : ""
        var log = """
        {"timestamp":"\(start)","type":"session_meta","payload":{"id":"\(thread)","source":"vscode"\(parent)}}
        {"timestamp":"\(start)","type":"event_msg","payload":{"type":"task_started","turn_id":"turn"}}

        """
        if complete {
            log += "{\"timestamp\":\"\(end)\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_complete\",\"turn_id\":\"turn\"}}\n"
        }
        let file = root.appendingPathComponent("\(name).jsonl")
        try Data(log.utf8).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: finishedAt], ofItemAtPath: file.path)
        return file
    }

    private func waitForHistory(_ store: ActiveSessionStore, count: Int) async -> ActiveSessionStoreSnapshot {
        var snapshot = await store.snapshot()
        for _ in 0..<100 where snapshot.recentCompletions.count < count {
            try? await Task.sleep(nanoseconds: 20_000_000)
            snapshot = await store.snapshot()
        }
        XCTAssertEqual(snapshot.recentCompletions.count, count)
        return snapshot
    }
}

private final class HistoryCountingReader: IncrementalReading, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var reads: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
    func readNewLines(at url: URL, cursor: inout FileCursor) throws -> [Data] {
        lock.lock()
        count += 1
        lock.unlock()
        return try IncrementalJSONLReader().readNewLines(at: url, cursor: &cursor)
    }
}
