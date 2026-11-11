import AppKit
import Foundation

protocol CodexLaunching {
    func restart(home: URL, userData: URL) async throws
}

/// Quits every running Codex instance and relaunches it with an isolated
/// `CODEX_HOME` and Electron user-data directory. The desktop app resolves
/// both variables itself, so no binary patching is involved.
struct LiveCodexLauncher: CodexLaunching {
    static let bundleIdentifier = "com.openai.codex"
    static let openExecutable = URL(fileURLWithPath: "/usr/bin/open")

    func restart(home: URL, userData: URL) async throws {
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

        try await launch(home: home, userData: userData)
    }

    static func openArguments(appURL: URL, home: URL, userData: URL) -> [String] {
        [
            "-n",
            "--env", "CODEX_HOME=\(home.path)",
            "--env", "CODEX_ELECTRON_USER_DATA_PATH=\(userData.path)",
            appURL.path,
            "--args", "--user-data-dir=\(userData.path)"
        ]
    }

    func launch(home: URL, userData: URL) async throws {
        guard let appURL = await MainActor.run(body: {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleIdentifier)
        }) else {
            throw AccountError.launchFailed("Codex.app is not installed.")
        }

        let process = Process()
        process.executableURL = Self.openExecutable
        process.arguments = Self.openArguments(appURL: appURL, home: home, userData: userData)

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
