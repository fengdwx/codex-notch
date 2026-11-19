import AppKit
import Foundation

enum CodexBinaryLocator {
    private static let relativeAppCLIRelativePaths = [
        "Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
        "Contents/Resources/codex-cli/bin/codex",
        "Contents/Resources/codex"
    ]

    static func locate(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        for candidate in candidateURLs(fileManager: fileManager, environment: environment) {
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    static func candidateURLs(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [URL] {
        var candidates: [URL] = []
        var seenPaths: Set<String> = []

        func appendCandidate(_ url: URL) {
            let standardized = url.standardizedFileURL.path
            guard seenPaths.insert(standardized).inserted else { return }
            candidates.append(url)
        }

        let home = fileManager.homeDirectoryForCurrentUser

        // 1. Prefer the Codex CLI bundled with the active ChatGPT/Codex desktop app.
        var appBundles: [URL] = []
        if let activeBundle = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: LiveCodexLauncher.bundleIdentifier
        ) {
            appBundles.append(activeBundle)
        }
        appBundles.append(contentsOf: [
            URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true),
            URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true),
            home.appendingPathComponent("Applications/Codex.app", isDirectory: true),
            home.appendingPathComponent("Applications/ChatGPT.app", isDirectory: true)
        ])

        for bundleURL in appBundles {
            for relativePath in relativeAppCLIRelativePaths {
                appendCandidate(bundleURL.appendingPathComponent(relativePath))
            }
        }

        // 2. Standard package-manager and user-local CLI locations.
        appendCandidate(URL(fileURLWithPath: "/opt/homebrew/bin/codex"))
        appendCandidate(URL(fileURLWithPath: "/usr/local/bin/codex"))
        appendCandidate(home.appendingPathComponent(".local/bin/codex"))

        // 3. Any directories on PATH (when available).
        if let pathEnv = environment["PATH"], !pathEnv.isEmpty {
            for entry in pathEnv.split(separator: ":") where !entry.isEmpty {
                appendCandidate(
                    URL(fileURLWithPath: String(entry), isDirectory: true)
                        .appendingPathComponent("codex")
                )
            }
        }

        // 4. Node version managers (Finder-launched GUI apps omit shell PATH).
        let nvmVersionsDir = home.appendingPathComponent(".nvm/versions/node", isDirectory: true)
        if let entries = try? fileManager.contentsOfDirectory(
            at: nvmVersionsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for versionDir in entries.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) {
                appendCandidate(versionDir.appendingPathComponent("bin/codex"))
            }
        }

        return candidates
    }
}
