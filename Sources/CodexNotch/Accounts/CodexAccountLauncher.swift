import AppKit
import Foundation

protocol CodexLaunching {
    /// Quits every running Codex instance and waits for it to exit.
    func quit() async
    /// Launches Codex against the shared `~/.codex` home.
    func launchShared() async throws
}

extension CodexLaunching {
    func restartShared() async throws {
        await quit()
        try await launchShared()
    }
}

struct LiveCodexLauncher: CodexLaunching {
    static let bundleIdentifier = "com.openai.codex"
    static let openExecutable = URL(fileURLWithPath: "/usr/bin/open")

    func quit() async {
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
        // Give the renderer a moment to flush `.codex-global-state.json`.
        try? await Task.sleep(nanoseconds: 300_000_000)
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

        let output: SubprocessRunner.Output
        do {
            output = try await Task.detached(priority: .userInitiated) {
                try SubprocessRunner.run(
                    executableURL: Self.openExecutable,
                    arguments: Self.openArguments(appURL: appURL),
                    captureStdout: false,
                    captureStderr: true
                )
            }.value
        } catch {
            throw AccountError.launchFailed(error.localizedDescription)
        }

        guard output.terminationStatus == 0 else {
            let message = String(data: output.stderr, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw AccountError.launchFailed(
                message?.isEmpty == false ? message! : "open exited with \(output.terminationStatus)"
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

/// Runs a short-lived child process while draining attached stdout/stderr pipes
/// concurrently *before* `waitUntilExit()` so outputs exceeding the 64 KB macOS
/// pipe buffer never deadlock.
enum SubprocessRunner {
    struct Output: Sendable {
        let terminationStatus: Int32
        let stdout: Data
        let stderr: Data
    }

    private final class LockedData: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()

        func set(_ value: Data) {
            lock.lock()
            data = value
            lock.unlock()
        }

        func get() -> Data {
            lock.lock()
            let copy = data
            lock.unlock()
            return copy
        }
    }

    static func run(
        executableURL: URL,
        arguments: [String],
        captureStdout: Bool = true,
        captureStderr: Bool = true
    ) throws -> Output {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdoutPipe = captureStdout ? Pipe() : nil
        let stderrPipe = captureStderr ? Pipe() : nil
        process.standardOutput = stdoutPipe ?? FileHandle.nullDevice
        process.standardError = stderrPipe ?? FileHandle.nullDevice

        try process.run()

        let stdoutBox = LockedData()
        let stderrBox = LockedData()
        let group = DispatchGroup()

        if let stdoutPipe {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                stdoutBox.set(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
                group.leave()
            }
        }
        if let stderrPipe {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                stderrBox.set(stderrPipe.fileHandleForReading.readDataToEndOfFile())
                group.leave()
            }
        }

        group.wait()
        process.waitUntilExit()
        return Output(
            terminationStatus: process.terminationStatus,
            stdout: stdoutBox.get(),
            stderr: stderrBox.get()
        )
    }
}
