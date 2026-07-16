import Foundation

final class RolloutActivityMonitor {
    private let rootURL: URL
    private let store: ActiveSessionStore
    private let reader = IncrementalJSONLReader()
    private let changeSource: FSEventChangeSource
    private let scanQueue = DispatchQueue(label: "com.david.codexnotch.rollout-scan")
    private let fileManager = FileManager.default

    private var cursors: [URL: FileCursor] = [:]
    private var eventsByFile: [URL: [RolloutEvent]] = [:]

    init(rootURL: URL, store: ActiveSessionStore = ActiveSessionStore()) {
        self.rootURL = rootURL
        self.store = store
        self.changeSource = FSEventChangeSource(rootURL: rootURL)
        self.changeSource.onChange = { [weak self] _ in
            self?.scanQueue.async { [weak self] in
                self?.scanRecentRollouts()
            }
        }
    }

    func start() {
        // Historical rollout files can be very large on a long-lived Codex
        // installation. Do not block the main thread before the quota badge
        // has a chance to render; the serial scan queue also preserves the
        // ordering relative to later FSEvents callbacks.
        scanQueue.async { [weak self] in
            self?.scanRecentRollouts()
        }
        changeSource.start()
    }

    func rescan() {
        scanQueue.async { [weak self] in
            self?.scanRecentRollouts()
        }
    }

    func stop() {
        changeSource.stop()
    }

    private func scanRecentRollouts() {
        guard fileManager.fileExists(atPath: rootURL.path) else { return }

        let cutoff = Date().addingTimeInterval(-(24 * 60 * 60))
        let files = recentRolloutFiles(cutoff: cutoff)
        let currentURLs = Set(files)

        for knownURL in Array(eventsByFile.keys) where !currentURLs.contains(knownURL) {
            eventsByFile.removeValue(forKey: knownURL)
            cursors.removeValue(forKey: knownURL)
            Task { await store.remove(rolloutID: knownURL.path) }
        }

        for url in files {
            process(url: url)
        }
    }

    private func recentRolloutFiles(cutoff: Date) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL,
                  url.pathExtension == "jsonl",
                  let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate,
                  modifiedAt >= cutoff else {
                return nil
            }
            return url
        }
    }

    private func process(url: URL) {
        do {
            var cursor = cursors[url] ?? FileCursor()
            let previousOffset = cursor.offset
            let fileSize = try fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber
            if let fileSize, UInt64(truncating: fileSize) < previousOffset {
                eventsByFile[url] = []
            }

            let lines = try reader.readNewLines(at: url, cursor: &cursor)
            cursors[url] = cursor
            if !lines.isEmpty {
                eventsByFile[url, default: []].append(contentsOf: lines.compactMap(RolloutEventParser.parseLine))
            }

            let reduction = ActiveSessionReducer.reduce(eventsByFile[url, default: []])
            let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? Date()
            Task {
                await store.replace(
                    rolloutID: url.path,
                    reduction: reduction,
                    lastModifiedAt: modifiedAt
                )
            }
        } catch {
            // A rollout may be rotated or partially written while Codex is appending.
            // The next FSEvents callback will retry the file.
        }
    }
}
