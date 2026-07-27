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
