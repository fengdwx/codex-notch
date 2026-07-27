import Foundation
import SQLite3

protocol ThreadTitleReading {
    func titles(for threadIDs: [String]) -> [String: String]
}

/// Reads Codex's own short thread summaries without opening rollout message bodies.
/// The state database is strictly read-only and no title is persisted by CodexNotch.
final class CodexThreadTitleReader: ThreadTitleReading {
    private static let queryBatchSize = 900
    private static let cacheLifetime: TimeInterval = 2
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private let databaseURL: URL
    private let fileManager: FileManager
    private var cachedModificationDates: [Date?] = []
    private var cacheExpiresAt: Date?
    private var cachedTitles: [String: String] = [:]
    private var queriedThreadIDs = Set<String>()

    convenience init(codexHomeURL: URL, fileManager: FileManager = .default) {
        self.init(
            databaseURL: codexHomeURL.appendingPathComponent("state_5.sqlite"),
            fileManager: fileManager
        )
    }

    init(databaseURL: URL, fileManager: FileManager = .default) {
        self.databaseURL = databaseURL
        self.fileManager = fileManager
    }

    func titles(for threadIDs: [String]) -> [String: String] {
        let requestedIDs = Array(Set(threadIDs.filter { !$0.isEmpty })).sorted()
        guard !requestedIDs.isEmpty, fileManager.fileExists(atPath: databaseURL.path) else {
            return [:]
        }

        let modificationDates = [
            modificationDate(for: databaseURL),
            modificationDate(for: databaseURL.appendingPathExtension("wal"))
        ]
        let now = Date()
        if modificationDates != cachedModificationDates
            || now >= (cacheExpiresAt ?? .distantPast) {
            cachedModificationDates = modificationDates
            cacheExpiresAt = now.addingTimeInterval(Self.cacheLifetime)
            cachedTitles.removeAll()
            queriedThreadIDs.removeAll()
        }

        let missingIDs = requestedIDs.filter { !queriedThreadIDs.contains($0) }
        if !missingIDs.isEmpty {
            let fetchedTitles = readTitles(for: missingIDs)
            cachedTitles.merge(fetchedTitles) { _, newer in newer }
            queriedThreadIDs.formUnion(missingIDs)
        }

        return Dictionary(uniqueKeysWithValues: requestedIDs.compactMap { threadID in
            cachedTitles[threadID].map { (threadID, $0) }
        })
    }

    private func modificationDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func readTitles(for threadIDs: [String]) -> [String: String] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX,
            nil
        ) == SQLITE_OK, let database else {
            if let database {
                sqlite3_close(database)
            }
            return [:]
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 25)

        var result: [String: String] = [:]
        for start in stride(from: 0, to: threadIDs.count, by: Self.queryBatchSize) {
            let end = min(start + Self.queryBatchSize, threadIDs.count)
            let batch = Array(threadIDs[start..<end])
            let placeholders = Array(repeating: "?", count: batch.count).joined(separator: ", ")
            let query = "SELECT id, title FROM threads WHERE id IN (\(placeholders))"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
                  let statement else {
                continue
            }
            defer { sqlite3_finalize(statement) }

            for (index, threadID) in batch.enumerated() {
                sqlite3_bind_text(
                    statement,
                    Int32(index + 1),
                    threadID,
                    -1,
                    Self.sqliteTransient
                )
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let rawID = sqlite3_column_text(statement, 0),
                      let rawTitle = sqlite3_column_text(statement, 1),
                      let title = ThreadSummaryTitle.normalized(String(cString: rawTitle)) else {
                    continue
                }
                result[String(cString: rawID)] = title
            }
        }
        return result
    }
}

enum ThreadSummaryTitle {
    static let maximumLength = 96

    static func normalized(_ value: String) -> String? {
        let collapsed = value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(maximumLength))
    }
}
