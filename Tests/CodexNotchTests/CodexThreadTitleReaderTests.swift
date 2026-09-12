import Foundation
import SQLite3
import XCTest
@testable import CodexNotch

final class CodexThreadTitleReaderTests: XCTestCase {
    func testReaderUsesCodexThreadSummaryInsteadOfFirstUserMessage() throws {
        let databaseURL = try makeDatabase(
            statements: [
                "CREATE TABLE threads (id TEXT PRIMARY KEY, title TEXT NOT NULL, first_user_message TEXT NOT NULL DEFAULT '')",
                "INSERT INTO threads (id, title, first_user_message) VALUES ('thread-1', '  Stable   thread title  ', 'must not be displayed')"
            ]
        )
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        let reader = CodexThreadTitleReader(databaseURL: databaseURL)

        let titles = reader.titles(for: ["thread-1", "missing-thread"])

        XCTAssertEqual(titles, ["thread-1": "Stable thread title"])
        XCTAssertNotEqual(titles["thread-1"], "must not be displayed")
    }

    func testReaderReturnsNoTitleWhenCodexStateDatabaseIsUnavailable() {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("state_5.sqlite")
        let reader = CodexThreadTitleReader(databaseURL: databaseURL)

        XCTAssertEqual(reader.titles(for: ["thread-1"]), [:])
    }

    func testLatestIndexedNameReplacesAttachmentWrapperInDatabase() throws {
        let databaseURL = try makeDatabase(statements: [
            "CREATE TABLE threads (id TEXT PRIMARY KEY, title TEXT NOT NULL)",
            "INSERT INTO threads VALUES ('thread-1', '# Files mentioned by the user: ## example.png')"
        ])
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        let indexURL = databaseURL.deletingLastPathComponent().appendingPathComponent("session_index.jsonl")
        let index = """
        {"id":"thread-1","thread_name":"Old name","updated_at":"2026-09-13T10:00:00Z"}
        {"id":"unrelated","thread_name":"Not requested"}
        {"id":"thread-1","thread_name":"  优化动画与图标  ","updated_at":"2026-09-12T10:00:00Z"}

        """
        try Data(index.utf8).write(to: indexURL)
        let originalDatabase = try Data(contentsOf: databaseURL)
        let reader = CodexThreadTitleReader(databaseURL: databaseURL)

        XCTAssertEqual(reader.titles(for: ["thread-1"]), ["thread-1": "优化动画与图标"])
        XCTAssertEqual(try Data(contentsOf: indexURL), Data(index.utf8))
        XCTAssertEqual(try Data(contentsOf: databaseURL), originalDatabase)
    }

    func testIndexWorksWithoutDatabaseAndRefreshesAfterRename() throws {
        let databaseURL = try makeDatabase(statements: [])
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        try FileManager.default.removeItem(at: databaseURL)
        let indexURL = databaseURL.deletingLastPathComponent().appendingPathComponent("session_index.jsonl")
        let first = "{\"id\":\"thread-1\",\"thread_name\":\"First name\"}\n"
        try Data(first.utf8).write(to: indexURL)
        let reader = CodexThreadTitleReader(databaseURL: databaseURL)
        XCTAssertEqual(reader.titles(for: ["thread-1"]), ["thread-1": "First name"])

        let renamed = first + "{\"id\":\"thread-1\",\"thread_name\":\"Renamed task\"}\n"
        try Data(renamed.utf8).write(to: indexURL)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: 5)], ofItemAtPath: indexURL.path)
        XCTAssertEqual(reader.titles(for: ["thread-1"]), ["thread-1": "Renamed task"])

        let invalid = renamed + "{\"id\":\"thread-1\",\"thread_name\":\"# Files mentioned by the user: ## example.png\"}\n"
        try Data(invalid.utf8).write(to: indexURL)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: 10)], ofItemAtPath: indexURL.path)
        XCTAssertEqual(reader.titles(for: ["thread-1"]), [:], "An invalid latest name must not resurrect the old name")
    }

    func testMalformedIndexLinesDoNotHideOtherNamesOrDatabaseFallback() throws {
        let databaseURL = try makeDatabase(statements: [
            "CREATE TABLE threads (id TEXT PRIMARY KEY, title TEXT NOT NULL)",
            "INSERT INTO threads VALUES ('database-only', '&#x20;修复&nbsp;布局 &amp; 字体')"
        ])
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        let indexURL = databaseURL.deletingLastPathComponent().appendingPathComponent("session_index.jsonl")
        let index = "{\"id\":\"indexed\",\"thread_name\":\"中文标题\"}\n"
            + String(repeating: "invalid", count: 20_000) + "\n"
            + "{\"id\":\"other\",\"thread_name\":\"Unfinished"
        try Data(index.utf8).write(to: indexURL)

        XCTAssertEqual(CodexThreadTitleReader(databaseURL: databaseURL).titles(for: ["indexed", "database-only"]),
                       ["indexed": "中文标题", "database-only": "修复 布局 & 字体"])
    }

    func testTransportWrappersAndLongPromptFallbacksAreNotDisplayed() throws {
        let databaseURL = try makeDatabase(statements: [
            "CREATE TABLE threads (id TEXT PRIMARY KEY, title TEXT NOT NULL)",
            "INSERT INTO threads VALUES ('thread-1', '# Files mentioned by the user: ## example.png')"
        ])
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        XCTAssertEqual(CodexThreadTitleReader(databaseURL: databaseURL).titles(for: ["thread-1"]), [:])
        XCTAssertNil(ThreadSummaryTitle.normalized("&#x23; Files mentioned by the user:\n## example.png"))
        XCTAssertNil(ThreadSummaryTitle.normalized("## My request:\nExample request"))
        XCTAssertNil(ThreadSummaryTitle.normalized(String(repeating: "A long initial prompt. ", count: 100)))
    }

    func testSummaryDecodesPlainTextEntitiesWithoutRenderingHTML() {
        XCTAssertEqual(ThreadSummaryTitle.normalized("&#32;修复&#x20;字体&#x1F680; &quot;预览&quot;"), "修复 字体🚀 \"预览\"")
        XCTAssertEqual(ThreadSummaryTitle.normalized("Use &lt;div&gt; &amp; &apos;title&apos;"), "Use <div> & 'title'")
        XCTAssertEqual(ThreadSummaryTitle.normalized("Keep &#x110000; &unknown;"), "Keep &#x110000; &unknown;")
    }

    private func makeDatabase(statements: [String]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let databaseURL = directory.appendingPathComponent("state_5.sqlite")
        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK, let database else {
            if let database {
                sqlite3_close(database)
            }
            throw NSError(domain: "CodexThreadTitleReaderTests", code: 1)
        }
        defer { sqlite3_close(database) }

        for statement in statements {
            guard sqlite3_exec(database, statement, nil, nil, nil) == SQLITE_OK else {
                throw NSError(domain: "CodexThreadTitleReaderTests", code: 2)
            }
        }
        return databaseURL
    }
}
