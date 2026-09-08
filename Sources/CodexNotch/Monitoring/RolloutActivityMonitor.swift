import Foundation

final class RolloutActivityMonitor {
    static let eventScanCoalescingInterval: TimeInterval = 0.1

    // Delivered on the main queue after the ordered store update has committed.
    var onChange: (() -> Void)?

    private let rootURL: URL
    private let store: ActiveSessionStore
    private let reader: IncrementalReading
    private let changeSource: FSEventChangeSource
    private let scanQueue = DispatchQueue(label: "com.david.codexnotch.rollout-scan")
    private let fileManager = FileManager.default

    private var cursors: [URL: FileCursor] = [:]
    private var eventsByFile: [URL: [RolloutEvent]] = [:]
    private var pendingScan: DispatchWorkItem?
    private var pendingURLs: Set<URL> = []
    private var needsFullScan = false
    private var running = false
    private var publicationTask: Task<Void, Never>?
    private var fingerprints: [URL: FileFingerprint] = [:]

    private struct FileFingerprint: Equatable {
        let size: UInt64
        let modifiedAt: Date
        let inode: UInt64
    }

    init(
        rootURL: URL,
        store: ActiveSessionStore = ActiveSessionStore(),
        reader: IncrementalReading = IncrementalJSONLReader()
    ) {
        self.rootURL = rootURL.resolvingSymlinksInPath()
        self.store = store
        self.reader = reader
        self.changeSource = FSEventChangeSource(rootURL: self.rootURL)
        self.changeSource.onChange = { [weak self] urls in
            self?.filesDidChange(urls)
        }
    }

    func start() {
        scanQueue.async { [weak self] in self?.running = true }
        scheduleScan(urls: nil, after: 0)
        changeSource.start()
    }

    func rescan() {
        // Also retry a stream that could not start before the directory existed.
        changeSource.start()
        scheduleScan(urls: nil, after: Self.eventScanCoalescingInterval)
    }

    func filesDidChange(_ urls: [URL]) {
        scheduleScan(urls: urls, after: Self.eventScanCoalescingInterval)
    }

    func stop() {
        changeSource.stop()
        scanQueue.async { [weak self] in
            self?.running = false
            self?.pendingScan?.cancel()
            self?.pendingScan = nil
            self?.pendingURLs.removeAll()
            self?.needsFullScan = false
        }
    }

    private func scheduleScan(urls: [URL]?, after delay: TimeInterval) {
        scanQueue.async { [weak self] in
            guard let self, self.running else { return }
            if let urls {
                for url in urls {
                    let resolved = url.resolvingSymlinksInPath()
                    if resolved == self.rootURL {
                        self.needsFullScan = true
                    } else if resolved.path.hasPrefix(self.rootURL.path + "/") {
                        if resolved.pathExtension == "jsonl" {
                            self.pendingURLs.insert(resolved)
                        } else if resolved.pathExtension.isEmpty {
                            self.needsFullScan = true
                        }
                    }
                }
            } else {
                self.needsFullScan = true
            }
            guard self.pendingScan == nil,
                  self.needsFullScan || !self.pendingURLs.isEmpty else { return }
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, self.running else { return }
                self.pendingScan = nil
                let fullScan = self.needsFullScan
                let changedURLs = self.pendingURLs
                self.needsFullScan = false
                self.pendingURLs.removeAll()
                if fullScan {
                    self.scanRecentRollouts()
                } else {
                    for url in changedURLs { self.process(url: url) }
                }
            }
            self.pendingScan = workItem
            self.scanQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    private func scanRecentRollouts() {
        guard fileManager.fileExists(atPath: rootURL.path) else {
            for url in Array(eventsByFile.keys) { remove(url: url) }
            return
        }

        let cutoff = Date().addingTimeInterval(-(24 * 60 * 60))
        let files = recentRolloutFiles(cutoff: cutoff)
        let currentURLs = Set(files)

        for knownURL in Array(eventsByFile.keys) where !currentURLs.contains(knownURL) {
            remove(url: knownURL)
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

        let files: [(URL, Date)] = enumerator.compactMap { item in
            guard let url = item as? URL,
                  url.pathExtension == "jsonl",
                  let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate,
                  modifiedAt >= cutoff else {
                return nil
            }
            return (url.resolvingSymlinksInPath(), modifiedAt)
        }
        // Publish the newest task before parsing older, potentially large logs.
        return files.sorted { $0.1 > $1.1 }.map(\.0)
    }

    private func process(url: URL) {
        do {
            guard fileManager.fileExists(atPath: url.path) else {
                remove(url: url)
                return
            }
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  let modifiedAt = attributes[.modificationDate] as? Date,
                  modifiedAt >= Date().addingTimeInterval(-24 * 60 * 60) else {
                remove(url: url)
                return
            }
            let fingerprint = FileFingerprint(
                size: (attributes[.size] as? NSNumber)?.uint64Value ?? 0,
                modifiedAt: modifiedAt,
                inode: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
            )
            guard fingerprint != fingerprints[url] else { return }
            var cursor = cursors[url] ?? FileCursor()
            if fingerprint.size < cursor.offset
                || (fingerprints[url].map { $0.inode != fingerprint.inode } ?? false) {
                eventsByFile[url] = []
                cursor = FileCursor()
            }

            let lines = try reader.readNewLines(at: url, cursor: &cursor)
            cursors[url] = cursor
            fingerprints[url] = fingerprint
            if !lines.isEmpty {
                eventsByFile[url, default: []].append(contentsOf: lines.compactMap(RolloutEventParser.parseLine))
            }

            let reduction = ActiveSessionReducer.reduce(eventsByFile[url, default: []])
            let previous = publicationTask
            let store = store
            let notify = onChange
            publicationTask = Task {
                await previous?.value
                await store.replace(rolloutID: url.path, reduction: reduction, lastModifiedAt: modifiedAt)
                DispatchQueue.main.async { notify?() }
            }
        } catch {
            // A rollout may be rotated or partially written while Codex is appending.
            // A later filesystem event or recovery scan retries it.
        }
    }

    private func remove(url: URL) {
        guard eventsByFile.removeValue(forKey: url) != nil else { return }
        cursors.removeValue(forKey: url)
        fingerprints.removeValue(forKey: url)
        let previous = publicationTask
        let store = store
        let notify = onChange
        publicationTask = Task {
            await previous?.value
            await store.remove(rolloutID: url.path)
            DispatchQueue.main.async { notify?() }
        }
    }
}
