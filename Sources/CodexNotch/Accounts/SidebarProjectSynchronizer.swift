import Foundation

/// Codex stores the project pool (projects, ordering, thread assignments) as
/// per-account UI state: the current account's copy lives at the root of
/// `.codex-global-state.json`, and other accounts keep theirs inside
/// `electron-account-renderer-state-v1`. Switching accounts therefore swaps the
/// project pool, which made accounts that never had one show an empty sidebar.
///
/// Before relaunching we copy the current pool into every account entry so the
/// same projects are restored no matter which account signs in.
enum SidebarProjectSynchronizer {
    static let projectKeys = [
        "local-projects",
        "project-order",
        "thread-project-assignments",
        "thread-project-membership-host-ids",
        "thread-workspace-root-hints",
        "thread-projectless-output-directories",
        "projectless-thread-ids",
        "project-appearances",
        "sidebar-project-thread-orders",
        "app-server-project-id-by-legacy-project-id-by-host",
        "app-server-projects-migration-by-host"
    ]

    @discardableResult
    static func synchronize(
        globalStateURL: URL,
        fileManager: FileManager = .default
    ) throws -> Int {
        guard fileManager.fileExists(atPath: globalStateURL.path) else { return 0 }
        let data = try Data(contentsOf: globalStateURL)
        guard var document = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return 0
        }

        let template = projectTemplate(in: document)
        guard let projects = template["local-projects"] as? [String: Any], !projects.isEmpty else {
            return 0
        }

        var updated = 0
        if var state = document["electron-account-renderer-state-v1"] as? [String: Any] {
            if state["atoms"] != nil {
                var ownerGlobals = state["globals"] as? [String: Any] ?? [:]
                for (key, value) in template {
                    ownerGlobals[key] = value
                }
                state["globals"] = ownerGlobals
            }
            if var inactive = state["inactive"] as? [String: [String: Any]] {
                for (id, entry) in inactive {
                    inactive[id] = mergeProjectKeys(
                        into: entry,
                        template: template
                    )
                }
                state["inactive"] = inactive
            }
            document["electron-account-renderer-state-v1"] = state
            updated = (state["inactive"] as? [String: Any])?.count ?? 0
            if state["atoms"] != nil { updated += 1 }
        }

        for (key, value) in template {
            document[key] = value
        }

        // Keep one rollback copy of the state that existed before this sync, so
        // a bad merge can be undone without touching Codex itself.
        let backupURL = globalStateURL.appendingPathExtension("pre-sync")
        try? fileManager.removeItem(at: backupURL)
        try? fileManager.copyItem(at: globalStateURL, to: backupURL)

        let output = try JSONSerialization.data(
            withJSONObject: document,
            options: [.sortedKeys]
        )
        try PrivateFileWriter.write(output, to: globalStateURL, fileManager: fileManager)
        return updated
    }

    private static func mergeProjectKeys(
        into entry: [String: Any],
        template: [String: Any]
    ) -> [String: Any] {
        var updated = entry
        var globals = updated["globals"] as? [String: Any] ?? [:]
        for (key, value) in template {
            globals[key] = value
        }
        updated["globals"] = globals
        return updated
    }

    private static func projectTemplate(in document: [String: Any]) -> [String: Any] {
        if let projects = document["local-projects"] as? [String: Any], !projects.isEmpty {
            return projectKeys.reduce(into: [String: Any]()) { result, key in
                if let value = document[key] { result[key] = value }
            }
        }

        guard let state = document["electron-account-renderer-state-v1"] as? [String: Any] else {
            return [:]
        }
        var entries: [[String: Any]] = []
        if state["atoms"] != nil { entries.append(state) }
        if let inactive = state["inactive"] as? [String: [String: Any]] {
            entries.append(contentsOf: inactive.values)
        }

        var best: [String: Any] = [:]
        var bestCount = 0
        for entry in entries {
            guard let globals = entry["globals"] as? [String: Any],
                  let projects = globals["local-projects"] as? [String: Any],
                  projects.count > bestCount else {
                continue
            }
            bestCount = projects.count
            best = projectKeys.reduce(into: [String: Any]()) { result, key in
                if let value = globals[key] { result[key] = value }
            }
        }
        return best
    }
}
