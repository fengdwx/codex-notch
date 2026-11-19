import AppKit
import Foundation

struct CodexExternalSession: Equatable, Sendable {
    let pid: Int32
    let command: String

    /// Short, non-sensitive description for the UI (executable name only).
    var displayName: String {
        guard let executable = command.split(separator: " ").first else {
            return "codex"
        }
        return (String(executable) as NSString).lastPathComponent
    }
}

protocol CodexSessionDetecting {
    /// Sessions outside the bundled ChatGPT app that would keep using
    /// `~/.codex/auth.json` after the desktop app quits (CLI, IDE, scripts).
    func externalSessions() -> [CodexExternalSession]
}

struct NoopCodexSessionDetector: CodexSessionDetecting {
    func externalSessions() -> [CodexExternalSession] { [] }
}

/// Detects standalone `codex` CLI processes. Processes launched from inside
/// the bundled Codex Desktop app (`/Applications/ChatGPT.app`,
/// `/Applications/Codex.app`, or the resolved bundle URL for `com.openai.codex`)
/// are ignored because quitting the desktop app terminates them as part of
/// the normal switch.
struct LiveCodexSessionDetector: CodexSessionDetecting {
    private static let standardBundledMarkers = [
        "/Applications/ChatGPT.app/",
        "/Applications/Codex.app/",
    ]

    private let bundledAppPaths: [String]?

    init(bundledAppPaths: [String]? = nil) {
        self.bundledAppPaths = bundledAppPaths
    }

    func externalSessions() -> [CodexExternalSession] {
        filterExternalSessions(fromLines: runProcessList())
    }

    func filterExternalSessions(fromLines lines: [String]) -> [CodexExternalSession] {
        let excludedMarkers = Self.normalizedMarkers(
            from: bundledAppPaths ?? Self.defaultBundledMarkers()
        )
        return lines
            .compactMap(parse(line:))
            .filter { session in
                !excludedMarkers.contains(where: { session.command.contains($0) })
                    && !session.command.contains("CodexNotch")
                    && !session.command.contains("grep ")
            }
    }

    private static func defaultBundledMarkers() -> [String] {
        var markers = standardBundledMarkers
        if let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: LiveCodexLauncher.bundleIdentifier
        ) {
            markers.append(appURL.path)
        }
        return markers
    }

    private static func normalizedMarkers(from rawPaths: [String]) -> [String] {
        var result: [String] = []
        for raw in rawPaths where !raw.isEmpty {
            let marker = raw.hasSuffix("/") ? raw : raw + "/"
            if !result.contains(marker) {
                result.append(marker)
            }
        }
        return result
    }

    private func runProcessList() -> [String] {
        guard let output = try? SubprocessRunner.run(
            executableURL: URL(fileURLWithPath: "/bin/ps"),
            arguments: ["-axo", "pid=,command="],
            captureStdout: true,
            captureStderr: false
        ),
        output.terminationStatus == 0,
        let text = String(data: output.stdout, encoding: .utf8) else {
            return []
        }
        return text.split(separator: "\n").map(String.init)
    }

    func parse(line: String) -> CodexExternalSession? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2, let pid = Int32(parts[0]) else { return nil }

        let command = String(parts[1])
        let executable = command.split(separator: " ").first.map(String.init) ?? command
        guard executable.hasSuffix("/codex") || executable == "codex" else {
            return nil
        }
        return CodexExternalSession(pid: pid, command: command)
    }
}
