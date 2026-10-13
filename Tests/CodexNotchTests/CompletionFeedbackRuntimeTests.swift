import AppKit
import Foundation
import XCTest
@testable import CodexNotch

@MainActor
final class CompletionFeedbackRuntimeTests: XCTestCase {
    func testRealRuntimeTickExpiresFeedbackWithUnchangedSnapshotAndZeroHistoryLimit() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        try fixture.writeInitialRollout()
        fixture.runtime.start()
        try await waitUntil {
            if case let .workingCompact(session, _, _) = fixture.model.state { return session.turnID == "initial" }
            return false
        }

        // This post-start append is published after the monitor's ordered
        // initial-scan marker, so subsequent endings are observed live events.
        fixture.clock.now = fixture.clock.now.addingTimeInterval(1)
        try fixture.append(type: "task_started", turn: "live")
        try await waitUntil {
            if case let .workingCompact(session, _, _) = fixture.model.state { return session.turnID == "live" }
            return false
        }
        fixture.clock.now = fixture.clock.now.addingTimeInterval(1)
        try fixture.append(type: "task_complete", turn: "live")
        try await waitUntil {
            if case let .completedCompact(session, _) = fixture.model.state { return session.turnID == "live" }
            return false
        }
        let completedSnapshot = await fixture.store.snapshot(now: fixture.clock.now)
        XCTAssertEqual(completedSnapshot.recentCompletions.first?.session.termination, .completed)
        XCTAssertEqual(fixture.defaults.integer(forKey: RecentConversationLimit.storageKey), 0)

        fixture.clock.now = fixture.clock.now.addingTimeInterval(6)
        // No file, preference or usage changes: only the real scheduled
        // one-second runtime timer can retire this feedback.
        try await waitUntil {
            if case .quotaCompact = fixture.model.state { return true }
            return false
        }
        let afterExpiry = await fixture.store.snapshot(now: fixture.clock.now)
        XCTAssertEqual(afterExpiry, completedSnapshot, "Expiration must not mutate completion history")

        fixture.model.onHoverChanged(true)
        try await waitUntil {
            if case .expanded = fixture.model.state { return true }
            return false
        }
        guard case let .expanded(content) = fixture.model.state else { return XCTFail("Expected expanded card") }
        XCTAssertTrue(content.conversations.isEmpty)
        XCTAssertNil(content.completionFeedback)
        fixture.model.onHoverChanged(false)
        try await waitUntil {
            if case .quotaCompact = fixture.model.state { return true }
            return false
        }
    }

    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = Date().addingTimeInterval(4)
        while !condition() && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), "Runtime did not reach the expected state", file: file, line: line)
        if !condition() { throw RuntimeFixtureError.timeout }
    }

    private enum RuntimeFixtureError: Error { case timeout }
    private final class Clock { var now = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down)) }

    private final class Fixture {
        let root: URL
        let log: URL
        let defaults: UserDefaults
        let suite = "CompletionFeedbackRuntimeTests.\(UUID().uuidString)"
        let clock = Clock()
        let store = ActiveSessionStore()
        let model = NotchViewModel()
        let controller: NotchWindowController
        let runtime: NotchRuntimeCoordinator

        init() throws {
            _ = NSApplication.shared
            controller = NotchWindowController()
            root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
            let sessions = root.appendingPathComponent("sessions", isDirectory: true)
            try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
            log = sessions.appendingPathComponent("feedback.jsonl")
            defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defaults.set(false, forKey: AppAnimationPreference.storageKey)
            defaults.set(true, forKey: NotchDisplayPreference.storageKey)
            defaults.set(0, forKey: RecentConversationLimit.storageKey)
            let clock = self.clock
            // The temporary Codex home contains no credentials; no actual
            // account, usage API or user rollout can be accessed by this test.
            runtime = NotchRuntimeCoordinator(
                windowController: controller,
                authReader: CodexAuthReader(environment: ["CODEX_HOME": root.path], homeDirectory: root),
                sessionStore: store, nowProvider: { clock.now }, userDefaults: defaults, viewModel: model
            )
        }

        func writeInitialRollout() throws {
            let timestamp = ISO8601DateFormatter().string(from: clock.now)
            let data = """
            {"timestamp":"\(timestamp)","type":"session_meta","payload":{"id":"feedback-thread"}}
            {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"task_started","turn_id":"initial"}}

            """
            try Data(data.utf8).write(to: log)
        }

        func append(type: String, turn: String) throws {
            let timestamp = ISO8601DateFormatter().string(from: clock.now)
            let line = "{\"timestamp\":\"\(timestamp)\",\"type\":\"event_msg\",\"payload\":{\"type\":\"\(type)\",\"turn_id\":\"\(turn)\"}}\n"
            let handle = try FileHandle(forWritingTo: log)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
        }

        func close() {
            runtime.stop()
            controller.close()
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
    }
}
