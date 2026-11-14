import Foundation
import SQLite3

/// Synchronizes Codex Desktop's shared project pool, active project selection,
/// workspace roots, and New Chat project mapping across accounts stored in
/// `~/.codex`.
///
/// Modern Codex Desktop builds isolate continuation state per account owner hash
/// (`electron-renderer-content-owner`, `electron-owner-value:<key>:<ownerHash>`,
/// `electron-account-remote-preference:<key>:<ownerHash>`, and
/// `electron-owner-atoms:<ownerHash>`). Legacy builds used
/// `electron-account-renderer-state-v1` alongside top-level keys. Both stores
/// (as well as future `.codex-global-state.sqlite` when activated with
/// `PRAGMA user_version != 0`) are kept aligned while preserving private
/// per-account credentials and UI caches.
enum SidebarProjectSynchronizer {
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private static let ownerContentKey = "electron-renderer-content-owner"
    private static let ownerValuePrefix = "electron-owner-value:"
    private static let remotePreferencePrefix = "electron-account-remote-preference:"
    private static let ownerAtomsPrefix = "electron-owner-atoms:"
    private static let legacyRendererStateKey = "electron-account-renderer-state-v1"
    private static let persistedAtomsKey = "electron-persisted-atom-state"
    private static let newTaskProjectByComputerKey = "new-task-project-by-computer"
    private static let selectedProjectKey = "selected-project"
    private static let activeWorkspaceRootsKey = "active-workspace-roots"
    private static let savedWorkspaceRootsKey = "electron-saved-workspace-roots"
    private static let workspaceRootLabelsKey = "electron-workspace-root-labels"
    private static let selectedRemoteHostKey = "selected-remote-host-id"
    private static let activeRemoteProjectKey = "active-remote-project-id"
    private static let sidebarProjectExpandedPrefix = "sidebar-project-expanded-v1-codex:"

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

    static let continuationGlobalKeys = [
        selectedProjectKey,
        activeWorkspaceRootsKey,
        savedWorkspaceRootsKey,
        workspaceRootLabelsKey
    ]

    static let ownerContinuationKeys = [
        selectedProjectKey,
        activeWorkspaceRootsKey,
        savedWorkspaceRootsKey,
        workspaceRootLabelsKey,
        "project-writable-roots",
        "thread-writable-roots",
        "thread-workspace-root-hints",
        "thread-projectless-output-directories",
        "open-in-target-preferences",
        "worktree-repository-preferences",
        "app-server-migrated-pinned-thread-ids-by-host",
        "app-server-projects-migration-by-host"
    ]

    static let remoteContinuationKeys = [
        selectedRemoteHostKey,
        activeRemoteProjectKey,
        "connection-group-order",
        "remote-cwds-by-host-and-workspace",
        "host-id-remote-control-allowed",
        "added-remote-control-env-ids",
        "remote-connection-auto-connect-by-host-id",
        "remote-project-connection-backfill-completed"
    ]

    static let sharedAtomKeys: Set<String> = [
        "flat-project-sidebar-preferences-v1",
        "unified-sidebar-project-order-v1",
        "unified-sidebar-pinned-order-v1",
        "sidebar-project-list-expanded-v1",
        "sidebar-collapsed-sections-v1",
        "sidebar-width",
        "composer-shell-mode-v1",
        "composer-selected-files-v1",
        "recent-file-open-targets-v1"
    ]

    @discardableResult
    static func synchronizeCodexHome(
        _ codexHome: URL,
        sourceIdentity: AccountIdentity? = nil,
        targetIdentity: AccountIdentity? = nil,
        fileManager: FileManager = .default
    ) throws -> Int {
        let jsonURL = codexHome.appendingPathComponent(".codex-global-state.json")
        let jsonUpdated = try synchronize(
            globalStateURL: jsonURL,
            sourceIdentity: sourceIdentity,
            targetIdentity: targetIdentity,
            fileManager: fileManager
        )

        let sqliteURL = codexHome.appendingPathComponent(".codex-global-state.sqlite")
        let sqliteUpdated = try synchronizeSQLiteIfActive(
            databaseURL: sqliteURL,
            sourceIdentity: sourceIdentity,
            targetIdentity: targetIdentity,
            fileManager: fileManager
        )

        return jsonUpdated + sqliteUpdated
    }

    @discardableResult
    static func synchronize(
        globalStateURL: URL,
        sourceIdentity: AccountIdentity? = nil,
        targetIdentity: AccountIdentity? = nil,
        fileManager: FileManager = .default
    ) throws -> Int {
        guard fileManager.fileExists(atPath: globalStateURL.path) else { return 0 }
        let data = try Data(contentsOf: globalStateURL)
        guard let document = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return 0
        }

        guard let result = synchronizeDocument(
            document,
            sourceIdentity: sourceIdentity,
            targetIdentity: targetIdentity
        ) else {
            return 0
        }

        // Keep one rollback copy of the state that existed before this sync, so
        // a bad merge can be undone without touching Codex itself.
        let backupURL = globalStateURL.appendingPathExtension("pre-sync")
        try? fileManager.removeItem(at: backupURL)
        try? fileManager.copyItem(at: globalStateURL, to: backupURL)

        let output = try JSONSerialization.data(
            withJSONObject: result.document,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        try PrivateFileWriter.write(output, to: globalStateURL, fileManager: fileManager)
        return result.updatedCount
    }

    static func synchronizeDocument(
        _ input: [String: Any],
        sourceIdentity: AccountIdentity? = nil,
        targetIdentity: AccountIdentity? = nil
    ) -> (document: [String: Any], updatedCount: Int)? {
        var document = input
        var totalUpdated = 0
        var didModify = false

        let legacyUpdated = applyLegacySync(to: &document)
        if legacyUpdated.didModify {
            didModify = true
            totalUpdated += legacyUpdated.updatedCount
        }

        let ownerUpdated = applyOwnerContinuationSync(
            to: &document,
            sourceIdentity: sourceIdentity,
            targetIdentity: targetIdentity
        )
        if ownerUpdated.didModify {
            didModify = true
            totalUpdated += ownerUpdated.updatedCount
        }

        guard didModify || totalUpdated > 0 else {
            return nil
        }
        return (document, totalUpdated)
    }

    // MARK: - Legacy renderer state

    private static func applyLegacySync(
        to document: inout [String: Any]
    ) -> (didModify: Bool, updatedCount: Int) {
        let template = legacyTemplate(in: document)
        guard let projects = template["local-projects"] as? [String: Any], !projects.isEmpty else {
            return (false, 0)
        }

        var updated = 0
        if var state = document[legacyRendererStateKey] as? [String: Any] {
            if state["atoms"] != nil {
                var ownerGlobals = state["globals"] as? [String: Any] ?? [:]
                for (key, value) in template {
                    ownerGlobals[key] = value
                }
                state["globals"] = ownerGlobals
            }
            if var inactive = state["inactive"] as? [String: [String: Any]] {
                for (id, entry) in inactive {
                    inactive[id] = mergeGlobals(into: entry, template: template)
                }
                state["inactive"] = inactive
            }
            document[legacyRendererStateKey] = state
            updated = (state["inactive"] as? [String: Any])?.count ?? 0
            if state["atoms"] != nil { updated += 1 }
        }

        for (key, value) in template {
            document[key] = value
        }
        return (true, updated)
    }

    private static func mergeGlobals(
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

    private static func legacyTemplate(in document: [String: Any]) -> [String: Any] {
        let keysToCopy = projectKeys + continuationGlobalKeys
        if let projects = document["local-projects"] as? [String: Any], !projects.isEmpty {
            return keysToCopy.reduce(into: [String: Any]()) { result, key in
                if let value = document[key] { result[key] = value }
            }
        }

        guard let state = document[legacyRendererStateKey] as? [String: Any] else {
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
            best = keysToCopy.reduce(into: [String: Any]()) { result, key in
                if let value = globals[key] { result[key] = value }
            }
        }
        return best
    }

    // MARK: - Modern owner-scoped continuation state

    private static func applyOwnerContinuationSync(
        to document: inout [String: Any],
        sourceIdentity: AccountIdentity?,
        targetIdentity: AccountIdentity?
    ) -> (didModify: Bool, updatedCount: Int) {
        let discoveredOwners = discoverOwnerHashes(in: document)
        guard !discoveredOwners.isEmpty else {
            return (false, 0)
        }

        guard let sourceOwner = resolveSourceOwner(
            in: document,
            discoveredOwners: discoveredOwners,
            sourceIdentity: sourceIdentity
        ) else {
            return (false, 0)
        }

        var destinations = discoveredOwners
        if let targetHash = targetIdentity?.ownerHash, isValidOwnerHash(targetHash) {
            destinations.insert(targetHash)
        }
        destinations.remove(sourceOwner)

        // Backfill missing workspace roots on the source owner first if another
        // owner already holds saved folders and the source owner omitted them.
        var didModify = backfillMissingWorkspaceRoots(
            for: sourceOwner,
            discoveredOwners: discoveredOwners,
            in: &document
        )

        let sourceAtoms = document["\(ownerAtomsPrefix)\(sourceOwner)"] as? [String: Any] ?? [:]
        let selectedProject = document["\(ownerValuePrefix)\(selectedProjectKey):\(sourceOwner)"]
        let remoteHostId = document["\(remotePreferencePrefix)\(selectedRemoteHostKey):\(sourceOwner)"] as? String
        let activeRemoteProjectId = document["\(remotePreferencePrefix)\(activeRemoteProjectKey):\(sourceOwner)"]
        let sourceIsLocalSelection =
            ((selectedProject as? [String: Any])?["type"] as? String == "local") &&
            (activeRemoteProjectId == nil || activeRemoteProjectId is NSNull)

        let projectByHost = resolveNewTaskProjectsByHost(
            sourceAtoms: sourceAtoms,
            selectedProject: selectedProject,
            remoteHostId: remoteHostId,
            sourceIdentity: sourceIdentity
        )

        var updatedDestinations = 0
        for destOwner in destinations.sorted() {
            copyOwnerValues(
                from: sourceOwner,
                to: destOwner,
                discoveredOwners: discoveredOwners,
                in: &document
            )
            copyRemotePreferences(
                from: sourceOwner,
                to: destOwner,
                clearActiveRemoteProject: sourceIsLocalSelection,
                in: &document
            )
            syncOwnerAtoms(
                sourceAtoms: sourceAtoms,
                to: destOwner,
                projectByHost: projectByHost,
                targetIdentity: targetIdentity,
                in: &document
            )
            updatedDestinations += 1
            didModify = true
        }

        return (didModify, updatedDestinations)
    }

    private static func discoverOwnerHashes(in document: [String: Any]) -> Set<String> {
        var owners = Set<String>()

        if let current = document[ownerContentKey] as? String, isValidOwnerHash(current) {
            owners.insert(current)
        }

        for key in document.keys {
            if key.hasPrefix(ownerAtomsPrefix) {
                let owner = String(key.dropFirst(ownerAtomsPrefix.count))
                if isValidOwnerHash(owner) {
                    owners.insert(owner)
                }
            } else if key.hasPrefix(ownerValuePrefix) || key.hasPrefix(remotePreferencePrefix),
                      let owner = ownerSuffix(fromScopedKey: key),
                      isValidOwnerHash(owner) {
                owners.insert(owner)
            }
        }

        return owners
    }

    private static func ownerSuffix(fromScopedKey key: String) -> String? {
        guard let lastColon = key.lastIndex(of: ":") else { return nil }
        let suffix = String(key[key.index(after: lastColon)...])
        return suffix
    }

    private static func isValidOwnerHash(_ owner: String) -> Bool {
        !owner.isEmpty && owner != "signed-out"
    }

    private static func resolveSourceOwner(
        in document: [String: Any],
        discoveredOwners: Set<String>,
        sourceIdentity: AccountIdentity?
    ) -> String? {
        if let current = document[ownerContentKey] as? String, isValidOwnerHash(current) {
            return current
        }

        if let sourceHash = sourceIdentity?.ownerHash, discoveredOwners.contains(sourceHash) {
            return sourceHash
        }

        let sortedOwners = discoveredOwners.sorted()
        if let ownerWithSelection = sortedOwners.first(where: { owner in
            let selected = document["\(ownerValuePrefix)\(selectedProjectKey):\(owner)"]
            return selected != nil && !(selected is NSNull)
        }) {
            return ownerWithSelection
        }

        if let ownerWithRoots = sortedOwners.first(where: { owner in
            if let roots = document["\(ownerValuePrefix)\(savedWorkspaceRootsKey):\(owner)"] as? [Any],
               !roots.isEmpty {
                return true
            }
            if let active = document["\(ownerValuePrefix)\(activeWorkspaceRootsKey):\(owner)"] as? [Any],
               !active.isEmpty {
                return true
            }
            return false
        }) {
            return ownerWithRoots
        }

        return sortedOwners.first
    }

    private static func backfillMissingWorkspaceRoots(
        for owner: String,
        discoveredOwners: Set<String>,
        in document: inout [String: Any]
    ) -> Bool {
        var modified = false
        for key in [savedWorkspaceRootsKey, activeWorkspaceRootsKey] {
            let scopedKey = "\(ownerValuePrefix)\(key):\(owner)"
            let current = document[scopedKey] as? [Any]
            if current == nil || current?.isEmpty == true {
                if let fallback = firstNonEmptyArrayValue(for: key, across: discoveredOwners, in: document) {
                    document[scopedKey] = fallback
                    modified = true
                }
            }
        }

        let labelsKey = "\(ownerValuePrefix)\(workspaceRootLabelsKey):\(owner)"
        let currentLabels = document[labelsKey] as? [String: Any]
        if currentLabels == nil || currentLabels?.isEmpty == true {
            if let fallbackLabels = firstNonEmptyDictionaryValue(
                for: workspaceRootLabelsKey,
                across: discoveredOwners,
                in: document
            ) {
                document[labelsKey] = fallbackLabels
                modified = true
            }
        }
        return modified
    }

    private static func copyOwnerValues(
        from sourceOwner: String,
        to destOwner: String,
        discoveredOwners: Set<String>,
        in document: inout [String: Any]
    ) {
        for key in ownerContinuationKeys {
            let sourceScopedKey = "\(ownerValuePrefix)\(key):\(sourceOwner)"
            let destScopedKey = "\(ownerValuePrefix)\(key):\(destOwner)"

            if let value = document[sourceScopedKey] {
                document[destScopedKey] = value
                continue
            }

            // If source lacks a workspace root key altogether, keep existing
            // destination value or seed from another discovered owner so folders
            // remain selectable.
            if key == savedWorkspaceRootsKey || key == activeWorkspaceRootsKey {
                if document[destScopedKey] == nil,
                   let fallback = firstNonEmptyArrayValue(for: key, across: discoveredOwners, in: document) {
                    document[destScopedKey] = fallback
                }
            } else if key == workspaceRootLabelsKey {
                if document[destScopedKey] == nil,
                   let fallback = firstNonEmptyDictionaryValue(for: key, across: discoveredOwners, in: document) {
                    document[destScopedKey] = fallback
                }
            }
        }
    }

    private static func copyRemotePreferences(
        from sourceOwner: String,
        to destOwner: String,
        clearActiveRemoteProject: Bool,
        in document: inout [String: Any]
    ) {
        for key in remoteContinuationKeys {
            let sourceScopedKey = "\(remotePreferencePrefix)\(key):\(sourceOwner)"
            let destScopedKey = "\(remotePreferencePrefix)\(key):\(destOwner)"
            if let value = document[sourceScopedKey] {
                document[destScopedKey] = value
            }
        }

        if clearActiveRemoteProject {
            document.removeValue(forKey: "\(remotePreferencePrefix)\(activeRemoteProjectKey):\(destOwner)")
        }
    }

    private static func syncOwnerAtoms(
        sourceAtoms: [String: Any],
        to destOwner: String,
        projectByHost: [String: Any],
        targetIdentity: AccountIdentity?,
        in document: inout [String: Any]
    ) {
        let destAtomsKey = "\(ownerAtomsPrefix)\(destOwner)"
        var destAtoms = document[destAtomsKey] as? [String: Any] ?? [:]

        for (atomKey, atomValue) in sourceAtoms {
            if isSharedAtomKey(atomKey) {
                destAtoms[atomKey] = atomValue
            }
        }

        if !projectByHost.isEmpty {
            var destNewTaskMap = destAtoms[newTaskProjectByComputerKey] as? [String: Any] ?? [:]

            for (rawKey, _) in destNewTaskMap {
                guard let parts = parseJSONTupleKey(rawKey), parts.count == 3 else { continue }
                let host = parts[2]
                if let syncedProject = projectByHost[host] {
                    destNewTaskMap[rawKey] = syncedProject
                }
            }

            if destOwner == targetIdentity?.ownerHash,
               let targetAccount = targetIdentity?.accountIdentifier,
               let targetUser = targetIdentity?.userIdentifier {
                for (host, syncedProject) in projectByHost {
                    if let targetTupleKey = AccountIdentity.jsonTupleKey([targetAccount, targetUser, host]) {
                        destNewTaskMap[targetTupleKey] = syncedProject
                    }
                }
            }

            destAtoms[newTaskProjectByComputerKey] = destNewTaskMap
        }

        if !destAtoms.isEmpty {
            document[destAtomsKey] = destAtoms
        }
    }

    private static func resolveNewTaskProjectsByHost(
        sourceAtoms: [String: Any],
        selectedProject: Any?,
        remoteHostId: String?,
        sourceIdentity: AccountIdentity?
    ) -> [String: Any] {
        var byHost: [String: Any] = [:]

        if let rawMap = sourceAtoms[newTaskProjectByComputerKey] as? [String: Any] {
            if let sourceAccount = sourceIdentity?.accountIdentifier,
               let sourceUser = sourceIdentity?.userIdentifier {
                for key in rawMap.keys.sorted() {
                    guard let parts = parseJSONTupleKey(key), parts.count == 3 else { continue }
                    if parts[0] == sourceAccount && parts[1] == sourceUser {
                        byHost[parts[2]] = rawMap[key]
                    }
                }
            }
            for key in rawMap.keys.sorted() {
                guard let parts = parseJSONTupleKey(key), parts.count == 3 else { continue }
                if byHost[parts[2]] == nil {
                    byHost[parts[2]] = rawMap[key]
                }
            }
        }

        if let selectedDict = selectedProject as? [String: Any],
           let projectId = selectedDict["projectId"] as? String,
           !projectId.isEmpty {
            let type = selectedDict["type"] as? String ?? "local"
            if type == "remote" {
                let host = (selectedDict["hostId"] as? String)
                    ?? remoteHostId
                    ?? "local"
                byHost[host] = projectId
            } else {
                byHost["local"] = projectId
            }
        } else if selectedProject is NSNull, byHost["local"] == nil {
            byHost["local"] = NSNull()
        }

        return byHost
    }

    private static func isSharedAtomKey(_ key: String) -> Bool {
        sharedAtomKeys.contains(key) || key.hasPrefix(sidebarProjectExpandedPrefix)
    }

    private static func parseJSONTupleKey(_ raw: String) -> [String]? {
        guard let data = raw.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String]
        else {
            return nil
        }
        return parsed
    }

    private static func firstNonEmptyArrayValue(
        for key: String,
        across owners: Set<String>,
        in document: [String: Any]
    ) -> [Any]? {
        for owner in owners.sorted() {
            if let array = document["\(ownerValuePrefix)\(key):\(owner)"] as? [Any], !array.isEmpty {
                return array
            }
        }
        return nil
    }

    private static func firstNonEmptyDictionaryValue(
        for key: String,
        across owners: Set<String>,
        in document: [String: Any]
    ) -> [String: Any]? {
        for owner in owners.sorted() {
            if let dict = document["\(ownerValuePrefix)\(key):\(owner)"] as? [String: Any], !dict.isEmpty {
                return dict
            }
        }
        return nil
    }

    // MARK: - Future Codex Desktop SQLite global state

    private struct SQLiteRow {
        let scope: String
        let key: String
        let rawValue: String
        let decodedValue: Any
    }

    @discardableResult
    private static func synchronizeSQLiteIfActive(
        databaseURL: URL,
        sourceIdentity: AccountIdentity?,
        targetIdentity: AccountIdentity?,
        fileManager: FileManager
    ) throws -> Int {
        guard fileManager.fileExists(atPath: databaseURL.path) else { return 0 }

        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let db
        else {
            if let db { sqlite3_close(db) }
            return 0
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 2000)

        guard readSQLiteUserVersion(db) != 0, sqliteSettingsTableExists(db) else {
            return 0
        }

        let rows = try readSQLiteSettingsRows(db)
        var document: [String: Any] = [:]
        var originalRawByIdentifier: [String: String] = [:]

        for row in rows {
            originalRawByIdentifier[sqliteIdentifier(scope: row.scope, key: row.key)] = row.rawValue
            if row.scope == "global" {
                document[row.key] = row.decodedValue
            } else if row.scope == "atom" {
                var atoms = document[persistedAtomsKey] as? [String: Any] ?? [:]
                atoms[row.key] = row.decodedValue
                document[persistedAtomsKey] = atoms
            } else if row.scope.hasPrefix(ownerAtomsPrefix) {
                var ownerAtoms = document[row.scope] as? [String: Any] ?? [:]
                ownerAtoms[row.key] = row.decodedValue
                document[row.scope] = ownerAtoms
            }
        }

        guard let result = synchronizeDocument(
            document,
            sourceIdentity: sourceIdentity,
            targetIdentity: targetIdentity
        ) else {
            return 0
        }

        let backupURL = databaseURL.appendingPathExtension("pre-sync")
        try? fileManager.removeItem(at: backupURL)
        try? fileManager.copyItem(at: databaseURL, to: backupURL)

        var desiredRows: [(scope: String, key: String, encoded: String)] = []
        var desiredIdentifiers = Set<String>()

        for (rootKey, rootValue) in result.document {
            if rootKey == persistedAtomsKey, let atoms = rootValue as? [String: Any] {
                for (atomKey, atomValue) in atoms {
                    guard let encoded = encodeJSONValue(atomValue) else { continue }
                    desiredRows.append(("atom", atomKey, encoded))
                    desiredIdentifiers.insert(sqliteIdentifier(scope: "atom", key: atomKey))
                }
            } else if rootKey.hasPrefix(ownerAtomsPrefix), let ownerAtoms = rootValue as? [String: Any] {
                for (atomKey, atomValue) in ownerAtoms {
                    guard let encoded = encodeJSONValue(atomValue) else { continue }
                    desiredRows.append((rootKey, atomKey, encoded))
                    desiredIdentifiers.insert(sqliteIdentifier(scope: rootKey, key: atomKey))
                }
            } else if let encoded = encodeJSONValue(rootValue) {
                desiredRows.append(("global", rootKey, encoded))
                desiredIdentifiers.insert(sqliteIdentifier(scope: "global", key: rootKey))
            }
        }

        try writeSQLiteChanges(
            db: db,
            originalRows: rows,
            originalRawByIdentifier: originalRawByIdentifier,
            desiredRows: desiredRows,
            desiredIdentifiers: desiredIdentifiers
        )
        return result.updatedCount
    }

    private static func sqliteIdentifier(scope: String, key: String) -> String {
        "\(scope)\u{0000}\(key)"
    }

    private static func readSQLiteUserVersion(_ db: OpaquePointer) -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK else {
            return 0
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    private static func sqliteSettingsTableExists(_ db: OpaquePointer) -> Bool {
        var statement: OpaquePointer?
        let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND name='settings' LIMIT 1"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private static func readSQLiteSettingsRows(_ db: OpaquePointer) throws -> [SQLiteRow] {
        var statement: OpaquePointer?
        let sql = "SELECT scope, key, value FROM settings"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var rows: [SQLiteRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let scopePtr = sqlite3_column_text(statement, 0),
                let keyPtr = sqlite3_column_text(statement, 1),
                let valuePtr = sqlite3_column_text(statement, 2)
            else {
                continue
            }
            let scope = String(cString: scopePtr)
            let key = String(cString: keyPtr)
            let rawValue = String(cString: valuePtr)
            let decoded: Any
            if let data = rawValue.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                decoded = json
            } else {
                decoded = rawValue
            }
            rows.append(SQLiteRow(scope: scope, key: key, rawValue: rawValue, decodedValue: decoded))
        }
        return rows
    }

    private static func writeSQLiteChanges(
        db: OpaquePointer,
        originalRows: [SQLiteRow],
        originalRawByIdentifier: [String: String],
        desiredRows: [(scope: String, key: String, encoded: String)],
        desiredIdentifiers: Set<String>
    ) throws {
        guard sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK else {
            return
        }
        var committed = false
        defer {
            if !committed {
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            }
        }

        var deleteStmt: OpaquePointer?
        if sqlite3_prepare_v2(
            db,
            "DELETE FROM settings WHERE scope = ? AND key = ?",
            -1,
            &deleteStmt,
            nil
        ) == SQLITE_OK {
            defer { sqlite3_finalize(deleteStmt) }
            for row in originalRows {
                let identifier = sqliteIdentifier(scope: row.scope, key: row.key)
                guard !desiredIdentifiers.contains(identifier) else { continue }
                sqlite3_reset(deleteStmt)
                sqlite3_bind_text(deleteStmt, 1, row.scope, -1, sqliteTransient)
                sqlite3_bind_text(deleteStmt, 2, row.key, -1, sqliteTransient)
                sqlite3_step(deleteStmt)
            }
        }

        var upsertStmt: OpaquePointer?
        if sqlite3_prepare_v2(
            db,
            "INSERT OR REPLACE INTO settings(scope, key, value) VALUES (?, ?, ?)",
            -1,
            &upsertStmt,
            nil
        ) == SQLITE_OK {
            defer { sqlite3_finalize(upsertStmt) }
            for desired in desiredRows {
                let identifier = sqliteIdentifier(scope: desired.scope, key: desired.key)
                // Only touch rows whose JSON representation actually changed,
                // or that did not exist before synchronization.
                if let existingRaw = originalRawByIdentifier[identifier],
                   jsonValuesEqual(existingRaw, desired.encoded) {
                    continue
                }
                sqlite3_reset(upsertStmt)
                sqlite3_bind_text(upsertStmt, 1, desired.scope, -1, sqliteTransient)
                sqlite3_bind_text(upsertStmt, 2, desired.key, -1, sqliteTransient)
                sqlite3_bind_text(upsertStmt, 3, desired.encoded, -1, sqliteTransient)
                sqlite3_step(upsertStmt)
            }
        }

        if sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK {
            committed = true
        }
    }

    private static func jsonValuesEqual(_ lhsRaw: String, _ rhsRaw: String) -> Bool {
        if lhsRaw == rhsRaw { return true }
        guard
            let lhsData = lhsRaw.data(using: .utf8),
            let rhsData = rhsRaw.data(using: .utf8),
            let lhsObj = try? JSONSerialization.jsonObject(with: lhsData, options: [.fragmentsAllowed]),
            let rhsObj = try? JSONSerialization.jsonObject(with: rhsData, options: [.fragmentsAllowed]),
            let lhsNorm = encodeJSONValue(lhsObj),
            let rhsNorm = encodeJSONValue(rhsObj)
        else {
            return false
        }
        return lhsNorm == rhsNorm
    }

    private static func encodeJSONValue(_ value: Any) -> String? {
        if value is NSNull {
            return "null"
        }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            guard let wrapped = try? JSONSerialization.data(
                withJSONObject: [number],
                options: [.withoutEscapingSlashes]
            ),
                  let text = String(data: wrapped, encoding: .utf8),
                  text.count >= 2
            else {
                return nil
            }
            return String(text.dropFirst().dropLast())
        }
        if let string = value as? String {
            guard let wrapped = try? JSONSerialization.data(
                withJSONObject: [string],
                options: [.withoutEscapingSlashes]
            ),
                  let text = String(data: wrapped, encoding: .utf8),
                  text.count >= 2
            else {
                return nil
            }
            return String(text.dropFirst().dropLast())
        }
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(
                  withJSONObject: value,
                  options: [.sortedKeys, .withoutEscapingSlashes]
              )
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
