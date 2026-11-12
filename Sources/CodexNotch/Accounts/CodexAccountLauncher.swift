import AppKit
import Foundation

protocol CodexLaunching {
    /// Quits Codex and relaunches it against the shared `~/.codex` home, so
    /// every account sees the same project and session pool.
    func restartShared() async throws
}

struct LiveCodexLauncher: CodexLaunching {
    static let bundleIdentifier = "com.openai.codex"
    static let openExecutable = URL(fileURLWithPath: "/usr/bin/open")

    func restartShared() async throws {
        await MainActor.run { terminateRunningInstances() }

        for _ in 0..<24 {
            let running = await MainActor.run { self.isRunning }
            if !running { break }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        if await MainActor.run(body: { self.isRunning }) {
            await MainActor.run { forceTerminateRunningInstances() }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        try await launchShared()
    }

    static func openArguments(appURL: URL) -> [String] {
        ["-n", appURL.path]
    }

    func launchShared() async throws {
        guard let appURL = await MainActor.run(body: {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleIdentifier)
        }) else {
            throw AccountError.launchFailed("Codex.app is not installed.")
        }

        let process = Process()
        process.executableURL = Self.openExecutable
        process.arguments = Self.openArguments(appURL: appURL)

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
        } catch {
            throw AccountError.launchFailed(error.localizedDescription)
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw AccountError.launchFailed(
                message?.isEmpty == false ? message! : "open exited with \(process.terminationStatus)"
            )
        }
    }

    @MainActor
    private var isRunning: Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.bundleIdentifier
        ).isEmpty
    }

    @MainActor
    private func terminateRunningInstances() {
        for application in NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.bundleIdentifier
        ) {
            _ = application.terminate()
        }
    }

    @MainActor
    private func forceTerminateRunningInstances() {
        for application in NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.bundleIdentifier
        ) {
            _ = application.forceTerminate()
        }
    }
}
