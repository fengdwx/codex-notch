import Foundation
import SQLite3

protocol ThreadTitleReading {
    func titles(for threadIDs: [String]) -> [String: String]
}

/// Reads Codex's current names, then legacy short title metadata, without opening
/// rollout message bodies. Both sources are read-only; no title is persisted.
final class CodexThreadTitleReader: ThreadTitleReading {
    private static let queryBatchSize = 900
    private static let cacheLifetime: TimeInterval = 2
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private let databaseURL: URL
    private let sessionIndexURL: URL
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
        self.sessionIndexURL = databaseURL.deletingLastPathComponent()
            .appendingPathComponent("session_index.jsonl")
        self.fileManager = fileManager
    }

    func titles(for threadIDs: [String]) -> [String: String] {
        let requestedIDs = Array(Set(threadIDs.filter { !$0.isEmpty })).sorted()
        guard !requestedIDs.isEmpty else {
            return [:]
        }

        let modificationDates = [
            modificationDate(for: databaseURL),
            modificationDate(for: URL(fileURLWithPath: databaseURL.path + "-wal")),
            modificationDate(for: sessionIndexURL)
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
            var fetchedTitles = readIndexedTitles(for: missingIDs)
            let fallbackIDs = missingIDs.filter { fetchedTitles[$0] == nil }
            fetchedTitles.merge(readTitles(for: fallbackIDs)) { current, _ in current }
            cachedTitles.merge(fetchedTitles) { _, newer in newer }
            queriedThreadIDs.formUnion(missingIDs)
        }

        return Dictionary(uniqueKeysWithValues: requestedIDs.compactMap { threadID in
            cachedTitles[threadID].map { (threadID, $0) }
        })
    }

    private func modificationDate(for url: URL) -> Date? {
        // URL resource values may be cached across reads of the same URL.
        // Poll fresh attributes so an appended name invalidates the title cache.
        (try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }

    private struct IndexEntry: Decodable {
        let id: String
        let thread_name: String
    }

    private func readIndexedTitles(for threadIDs: [String]) -> [String: String] {
        guard let handle = try? FileHandle(forReadingFrom: sessionIndexURL) else { return [:] }
        defer { try? handle.close() }
        guard var offset = try? handle.seekToEnd() else { return [:] }
        let decoder = JSONDecoder()
        var remainingIDs = Set(threadIDs)
        var result: [String: String] = [:]
        var reversedLine: [UInt8] = []
        var oversizedLine = false

        func consumeLine() {
            defer { reversedLine.removeAll(keepingCapacity: true); oversizedLine = false }
            guard !oversizedLine,
                  let entry = try? decoder.decode(IndexEntry.self, from: Data(reversedLine.reversed())),
                  remainingIDs.remove(entry.id) != nil else { return }
            // Last appended entry wins, even if its timestamp predates an older
            // line. An invalid latest name must not resurrect an obsolete name.
            result[entry.id] = ThreadSummaryTitle.normalized(entry.thread_name)
        }

        // Scan from the tail so recent visible tasks do not require loading a
        // complete historical index. Bound memory even for malformed huge lines.
        do {
            while offset > 0, !remainingIDs.isEmpty {
                let count = Int(min(offset, 65_536))
                offset -= UInt64(count)
                try handle.seek(toOffset: offset)
                guard let chunk = try handle.read(upToCount: count), chunk.count == count else { break }
                for byte in chunk.reversed() {
                    if byte == 0x0A {
                        consumeLine()
                        if remainingIDs.isEmpty { return result }
                    } else if reversedLine.count < 16_384 {
                        reversedLine.append(byte)
                    } else {
                        oversizedLine = true
                    }
                }
            }
            if offset == 0 { consumeLine() }
        } catch {
            // A concurrent rewrite or unavailable file may still leave useful
            // names already read; unresolved IDs use the database/project label.
        }
        return result
    }

    private func readTitles(for threadIDs: [String]) -> [String: String] {
        guard !threadIDs.isEmpty else { return [:] }
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
    private static let entityPattern = try! NSRegularExpression(
        pattern: "&(#(?:[xX][0-9a-fA-F]+|[0-9]+)|amp|lt|gt|quot|apos|nbsp);"
    )
    private static let namedEntities = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " "
    ]

    static func normalized(_ value: String) -> String? {
        guard value.utf8.count <= 16_384 else { return nil }
        let collapsed = decodingEntities(in: value)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard !collapsed.isEmpty, collapsed.count <= maximumLength else { return nil }
        let header = collapsed.drop(while: { $0 == "#" || $0.isWhitespace }).lowercased()
        guard !["files mentioned by the user:", "my request:", "agents.md instructions for ",
                "<environment_context>", "<image name="].contains(where: header.hasPrefix) else { return nil }
        return collapsed
    }

    private static func decodingEntities(in value: String) -> String {
        var result = value
        let matches = entityPattern.matches(in: value, range: NSRange(value.startIndex..., in: value))
        for match in matches.reversed() {
            guard let bodyRange = Range(match.range(at: 1), in: value),
                  let fullRange = Range(match.range, in: result) else { continue }
            let entity = String(value[bodyRange])
            let replacement: String?
            if entity.hasPrefix("#") {
                let hex = entity.dropFirst().hasPrefix("x") || entity.dropFirst().hasPrefix("X")
                let digits = entity.dropFirst(hex ? 2 : 1)
                if let code = UInt32(digits, radix: hex ? 16 : 10),
                   let scalar = UnicodeScalar(code),
                   code >= 0x20 || [9, 10, 13].contains(code) {
                    replacement = String(scalar)
                } else {
                    replacement = nil
                }
            } else {
                replacement = namedEntities[entity]
            }
            if let replacement { result.replaceSubrange(fullRange, with: replacement) }
        }
        return result
    }
}
