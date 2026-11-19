import AppKit
import Foundation

enum IsolatedLoginPhase: Equatable, Sendable {
    case idle
    case startingServer
    case waitingForBrowser
    case importingCredentials
    case completed(AccountProfile)
    case failed(String)
    case cancelled

    var isInProgress: Bool {
        switch self {
        case .startingServer, .waitingForBrowser, .importingCredentials:
            return true
        case .idle, .completed, .failed, .cancelled:
            return false
        }
    }
}

struct IsolatedLoginState: Equatable, Sendable {
    var phase: IsolatedLoginPhase
    var authURL: URL?
    var statusLines: [String]

    init(
        phase: IsolatedLoginPhase = .idle,
        authURL: URL? = nil,
        statusLines: [String] = []
    ) {
        self.phase = phase
        self.authURL = authURL
        self.statusLines = statusLines
    }
}

enum IsolatedLoginServiceError: LocalizedError, Equatable {
    case codexBinaryNotFound
    case loginAlreadyRunning
    case unexpectedResponse(String)
    case untrustedAuthURL(String)
    case authFileNotCreated
    case timedOut

    func localizedMessage(for language: AppLanguage) -> String {
        switch self {
        case .codexBinaryNotFound:
            return language.localized(
                chinese: "未找到可用的 Codex CLI，请先安装 ChatGPT / Codex 桌面端或在终端安装 codex。",
                english: "Could not find a Codex CLI binary. Please install the ChatGPT / Codex desktop app or codex CLI."
            )
        case .loginAlreadyRunning:
            return language.localized(
                chinese: "已有登录流程正在进行中。",
                english: "A browser login session is already running."
            )
        case .unexpectedResponse(let detail):
            return language.localized(
                chinese: "登录服务返回异常：\(detail)",
                english: "Login server returned an unexpected response: \(detail)"
            )
        case .untrustedAuthURL(let urlString):
            return language.localized(
                chinese: "拦截了不受信任的授权链接：\(urlString)",
                english: "Blocked an untrusted authorization URL: \(urlString)"
            )
        case .authFileNotCreated:
            return language.localized(
                chinese: "浏览器授权已返回，但临时目录中未生成 auth.json。",
                english: "Browser authorization finished, but no auth.json file was written in the temporary sandbox."
            )
        case .timedOut:
            return language.localized(
                chinese: "登录等待超时，请重试。",
                english: "Browser login timed out. Please try again."
            )
        }
    }

    var errorDescription: String? {
        localizedMessage(for: .chinese)
    }
}

/// Runs an ephemeral `codex app-server --stdio` login inside an isolated
/// `CODEX_HOME` (`PendingLogins/<UUID>`) so a brand-new or expired account can
/// sign in via OAuth in the browser without touching `~/.codex` or logging out
/// the currently active Codex Desktop session.
final class IsolatedLoginService: @unchecked Sendable {
    private static let ansiEscapeRegex = try? NSRegularExpression(
        pattern: "\\x1B\\[[0-?]*[ -/]*[@-~]",
        options: []
    )

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let codexBinaryProvider: () -> URL?
    private let authImporter: @MainActor (Data) throws -> AccountProfile
    private let urlOpener: @MainActor (URL) -> Void
    private let timeoutInterval: TimeInterval
    private let queue = DispatchQueue(label: "com.david.codexnotch.isolated-login")

    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private var sessionDirectory: URL?
    private var sessionID: UUID?
    private var loginID: String?
    private var timeoutWorkItem: DispatchWorkItem?
    private var stdoutBuffer = Data()
    private var stderrDiagnostics: [String] = []
    private var state = IsolatedLoginState()
    private var onStateChange: (@MainActor (IsolatedLoginState) -> Void)?
    private var isFinishing = false

    init(
        rootDirectory: URL,
        fileManager: FileManager = .default,
        codexBinaryProvider: @escaping () -> URL? = { CodexBinaryLocator.locate() },
        urlOpener: @escaping @MainActor (URL) -> Void = { _ = NSWorkspace.shared.open($0) },
        timeoutInterval: TimeInterval = 600,
        authImporter: @escaping @MainActor (Data) throws -> AccountProfile
    ) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        self.codexBinaryProvider = codexBinaryProvider
        self.urlOpener = urlOpener
        self.timeoutInterval = timeoutInterval
        self.authImporter = authImporter
        removeStaleSessions()
    }

    deinit {
        queue.sync {
            cleanupLocked()
        }
    }

    func removeStaleSessions() {
        queue.async { [weak self] in
            guard let self, self.process == nil else { return }
            self.cleanupRootDirectoryLocked()
        }
    }

    static func isTrustedAuthorizationURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !host.isEmpty else {
            return false
        }
        return host == "openai.com"
            || host.hasSuffix(".openai.com")
            || host == "chatgpt.com"
            || host.hasSuffix(".chatgpt.com")
    }

    static func startupMessages() -> [[String: Any]] {
        [
            [
                "method": "initialize",
                "id": 0,
                "params": [
                    "clientInfo": [
                        "name": "codex-notch",
                        "title": "CodexNotch",
                        "version": AppVersion.fromBundle()?.displayValue
                            .trimmingCharacters(in: CharacterSet(charactersIn: "v")) ?? "2.0.0"
                    ],
                    "capabilities": [
                        "experimentalApi": true,
                        "requestAttestation": false
                    ]
                ]
            ],
            [
                "method": "initialized"
            ],
            [
                "method": "account/login/start",
                "id": 1,
                "params": [
                    "type": "chatgpt"
                ]
            ]
        ]
    }

    func startLogin(
        language: AppLanguage = .chinese,
        onStateChange: @escaping @MainActor (IsolatedLoginState) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            guard self.process == nil else {
                let message = IsolatedLoginServiceError.loginAlreadyRunning.localizedMessage(for: language)
                self.publishStateLocked(
                    IsolatedLoginState(
                        phase: .failed(message),
                        authURL: self.state.authURL,
                        statusLines: self.state.statusLines + [message]
                    ),
                    callback: onStateChange
                )
                return
            }

            self.onStateChange = onStateChange
            self.isFinishing = false
            self.loginID = nil
            self.stdoutBuffer = Data()
            self.stderrDiagnostics = []

            guard let binaryURL = self.codexBinaryProvider() else {
                let message = IsolatedLoginServiceError.codexBinaryNotFound.localizedMessage(for: language)
                self.publishStateLocked(
                    IsolatedLoginState(phase: .failed(message), statusLines: [message])
                )
                return
            }

            let sessionID = UUID()
            let sessionDir = self.rootDirectory.appendingPathComponent(sessionID.uuidString, isDirectory: true)
            do {
                try PrivateFileWriter.ensureDirectory(self.rootDirectory, fileManager: self.fileManager)
                try PrivateFileWriter.ensureDirectory(sessionDir, fileManager: self.fileManager)
            } catch {
                let message = IsolatedLoginServiceError.unexpectedResponse(error.localizedDescription)
                    .localizedMessage(for: language)
                self.publishStateLocked(
                    IsolatedLoginState(phase: .failed(message), statusLines: [message])
                )
                return
            }

            self.sessionID = sessionID
            self.sessionDirectory = sessionDir

            let startingLine = language.localized(
                chinese: "正在独立沙盒中启动 Codex 登录服务…",
                english: "Starting isolated Codex login helper…"
            )
            self.publishStateLocked(
                IsolatedLoginState(phase: .startingServer, statusLines: [startingLine])
            )

            let process = Process()
            process.executableURL = binaryURL
            process.arguments = ["-c", "cli_auth_credentials_store=\"file\"", "app-server", "--stdio"]
            process.currentDirectoryURL = sessionDir

            var env = ProcessInfo.processInfo.environment
            env["CODEX_HOME"] = sessionDir.path
            env["NO_COLOR"] = "1"
            env["TERM"] = "dumb"
            env.removeValue(forKey: "CODEX_ACCESS_TOKEN")
            env.removeValue(forKey: "CODEX_API_KEY")
            env.removeValue(forKey: "OPENAI_API_KEY")
            process.environment = env

            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            self.process = process
            self.stdinHandle = stdinPipe.fileHandleForWriting
            self.stdoutHandle = stdoutPipe.fileHandleForReading
            self.stderrHandle = stderrPipe.fileHandleForReading

            stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let chunk = handle.availableData
                self?.queue.async { [weak self] in
                    guard let self else { return }
                    if chunk.isEmpty {
                        handle.readabilityHandler = nil
                        return
                    }
                    self.handleStdoutChunkLocked(chunk, expectedSessionID: sessionID, language: language)
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let chunk = handle.availableData
                self?.queue.async { [weak self] in
                    guard let self else { return }
                    if chunk.isEmpty {
                        handle.readabilityHandler = nil
                        return
                    }
                    self.handleStderrChunkLocked(chunk, expectedSessionID: sessionID)
                }
            }

            process.terminationHandler = { [weak self] terminated in
                self?.queue.async { [weak self] in
                    self?.handleProcessTerminationLocked(
                        status: terminated.terminationStatus,
                        expectedSessionID: sessionID,
                        language: language
                    )
                }
            }

            do {
                try process.run()
            } catch {
                self.finishFailureLocked(
                    message: error.localizedDescription,
                    expectedSessionID: sessionID
                )
                return
            }

            self.scheduleTimeoutLocked(expectedSessionID: sessionID, language: language)
            self.sendStartupMessagesLocked(expectedSessionID: sessionID)
        }
    }

    func cancel(language: AppLanguage = .chinese) {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.process != nil || self.state.phase.isInProgress else { return }
            if let loginID = self.loginID, let stdinHandle = self.stdinHandle {
                self.sendJSONLine(
                    [
                        "method": "account/login/cancel",
                        "id": 2,
                        "params": ["loginId": loginID]
                    ],
                    to: stdinHandle
                )
            }
            self.isFinishing = true
            self.cleanupLocked()
            let line = language.localized(chinese: "已取消网页登录", english: "Browser login cancelled")
            var next = self.state
            next.phase = .cancelled
            next.statusLines.append(line)
            self.publishStateLocked(next)
        }
    }

    // MARK: - Internal JSON-RPC & Sandbox Management

    private func sendStartupMessagesLocked(expectedSessionID: UUID) {
        guard self.sessionID == expectedSessionID,
              let stdinHandle = self.stdinHandle else {
            return
        }
        for message in Self.startupMessages() {
            sendJSONLine(message, to: stdinHandle)
        }
    }

    private func sendJSONLine(_ payload: [String: Any], to handle: FileHandle) {
        guard JSONSerialization.isValidJSONObject(payload),
              var data = try? JSONSerialization.data(
                  withJSONObject: payload,
                  options: [.withoutEscapingSlashes]
              ) else {
            return
        }
        data.append(0x0A)
        try? handle.write(contentsOf: data)
    }

    private func handleStdoutChunkLocked(
        _ chunk: Data,
        expectedSessionID: UUID,
        language: AppLanguage
    ) {
        guard sessionID == expectedSessionID, !isFinishing else { return }
        stdoutBuffer.append(chunk)

        while let newlineIndex = stdoutBuffer.firstIndex(of: 0x0A) {
            let lineData = stdoutBuffer.subdata(in: stdoutBuffer.startIndex..<newlineIndex)
            stdoutBuffer.removeSubrange(stdoutBuffer.startIndex...newlineIndex)
            guard let line = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !line.isEmpty else {
                continue
            }
            handleJSONRPCLineLocked(line, expectedSessionID: expectedSessionID, language: language)
        }
    }

    private func handleStderrChunkLocked(_ chunk: Data, expectedSessionID: UUID) {
        guard sessionID == expectedSessionID, !isFinishing else { return }
        guard let raw = String(data: chunk, encoding: .utf8) else { return }
        let cleanedLines = raw
            .components(separatedBy: .newlines)
            .map { Self.stripANSI($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleanedLines.isEmpty else { return }
        stderrDiagnostics.append(contentsOf: cleanedLines)
        if stderrDiagnostics.count > 20 {
            stderrDiagnostics.removeFirst(stderrDiagnostics.count - 20)
        }
    }

    private func handleJSONRPCLineLocked(
        _ line: String,
        expectedSessionID: UUID,
        language: AppLanguage
    ) {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let id = object["id"] as? Int, id == 1 {
            handleLoginStartResponseLocked(object, expectedSessionID: expectedSessionID, language: language)
            return
        }

        if let method = object["method"] as? String, method == "account/login/completed" {
            handleLoginCompletedNotificationLocked(
                object,
                expectedSessionID: expectedSessionID,
                language: language
            )
        }
    }

    private func handleLoginStartResponseLocked(
        _ object: [String: Any],
        expectedSessionID: UUID,
        language: AppLanguage
    ) {
        guard sessionID == expectedSessionID, !isFinishing else { return }

        if let errorObj = object["error"] as? [String: Any] {
            let detail = (errorObj["message"] as? String) ?? "JSON-RPC error"
            finishFailureLocked(
                message: IsolatedLoginServiceError.unexpectedResponse(detail).localizedMessage(for: language),
                expectedSessionID: expectedSessionID
            )
            return
        }

        guard let result = object["result"] as? [String: Any],
              result["type"] as? String == "chatgpt",
              let authURLString = result["authUrl"] as? String,
              let authURL = URL(string: authURLString),
              let loginID = result["loginId"] as? String,
              !loginID.isEmpty else {
            finishFailureLocked(
                message: IsolatedLoginServiceError.unexpectedResponse("Missing chatgpt authUrl/loginId")
                    .localizedMessage(for: language),
                expectedSessionID: expectedSessionID
            )
            return
        }

        guard Self.isTrustedAuthorizationURL(authURL) else {
            finishFailureLocked(
                message: IsolatedLoginServiceError.untrustedAuthURL(authURLString).localizedMessage(for: language),
                expectedSessionID: expectedSessionID
            )
            return
        }

        self.loginID = loginID
        let line = language.localized(
            chinese: "已获取官方授权页，正在默认浏览器中打开…",
            english: "Authorization URL ready; opening default browser…"
        )
        var next = state
        next.phase = .waitingForBrowser
        next.authURL = authURL
        next.statusLines.append(line)
        publishStateLocked(next)

        let opener = urlOpener
        Task { @MainActor in
            opener(authURL)
        }
    }

    private func handleLoginCompletedNotificationLocked(
        _ object: [String: Any],
        expectedSessionID: UUID,
        language: AppLanguage
    ) {
        guard sessionID == expectedSessionID, !isFinishing else { return }

        if let params = object["params"] as? [String: Any],
           let success = params["success"] as? Bool,
           !success {
            let detail = (params["error"] as? String) ?? "OAuth login failed"
            finishFailureLocked(
                message: IsolatedLoginServiceError.unexpectedResponse(detail).localizedMessage(for: language),
                expectedSessionID: expectedSessionID
            )
            return
        }

        isFinishing = true
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil

        let line = language.localized(
            chinese: "授权已完成，正在保存账号凭据…",
            english: "Authorization completed, importing credentials…"
        )
        var next = state
        next.phase = .importingCredentials
        next.statusLines.append(line)
        publishStateLocked(next)

        loadAuthDataLocked(attempt: 0, expectedSessionID: expectedSessionID, language: language)
    }

    private func loadAuthDataLocked(
        attempt: Int,
        expectedSessionID: UUID,
        language: AppLanguage
    ) {
        guard sessionID == expectedSessionID,
              let sessionDir = sessionDirectory else {
            return
        }

        let authURL = sessionDir.appendingPathComponent("auth.json")
        if let data = try? Data(contentsOf: authURL), !data.isEmpty {
            let importer = authImporter
            let currentLines = state.statusLines
            let currentAuthURL = state.authURL

            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let profile = try importer(data)
                    self.queue.async { [weak self] in
                        guard let self else { return }
                        self.cleanupLocked()
                        let doneLine = language.localized(
                            chinese: "账号「\(profile.shortLabel)」已导入，正在同步额度…",
                            english: "Imported \(profile.shortLabel), fetching quota…"
                        )
                        self.publishStateLocked(
                            IsolatedLoginState(
                                phase: .completed(profile),
                                authURL: currentAuthURL,
                                statusLines: currentLines + [doneLine]
                            )
                        )
                    }
                } catch {
                    self.queue.async { [weak self] in
                        self?.finishFailureLocked(
                            message: error.localizedDescription,
                            expectedSessionID: expectedSessionID
                        )
                    }
                }
            }
            return
        }

        if attempt < 12 {
            queue.asyncAfter(deadline: .now() + .milliseconds(150)) { [weak self] in
                self?.loadAuthDataLocked(
                    attempt: attempt + 1,
                    expectedSessionID: expectedSessionID,
                    language: language
                )
            }
        } else {
            finishFailureLocked(
                message: IsolatedLoginServiceError.authFileNotCreated.localizedMessage(for: language),
                expectedSessionID: expectedSessionID
            )
        }
    }

    private func handleProcessTerminationLocked(
        status: Int32,
        expectedSessionID: UUID,
        language: AppLanguage
    ) {
        guard sessionID == expectedSessionID, !isFinishing else { return }

        // If the server already wrote auth.json before exiting, still adopt it.
        if let authURL = sessionDirectory?.appendingPathComponent("auth.json"),
           fileManager.fileExists(atPath: authURL.path) {
            isFinishing = true
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
            loadAuthDataLocked(attempt: 0, expectedSessionID: expectedSessionID, language: language)
            return
        }

        let detail = stderrDiagnostics.last
            ?? language.localized(
                chinese: "登录进程意外退出 (code \(status))",
                english: "Login helper exited unexpectedly (code \(status))"
            )
        finishFailureLocked(
            message: detail,
            expectedSessionID: expectedSessionID
        )
    }

    private func scheduleTimeoutLocked(expectedSessionID: UUID, language: AppLanguage) {
        timeoutWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.sessionID == expectedSessionID, !self.isFinishing else { return }
            self.finishFailureLocked(
                message: IsolatedLoginServiceError.timedOut.localizedMessage(for: language),
                expectedSessionID: expectedSessionID
            )
        }
        timeoutWorkItem = item
        queue.asyncAfter(deadline: .now() + timeoutInterval, execute: item)
    }

    private func finishFailureLocked(message: String, expectedSessionID: UUID) {
        guard sessionID == expectedSessionID else { return }
        isFinishing = true
        cleanupLocked()
        var next = state
        next.phase = .failed(message)
        next.statusLines.append(message)
        publishStateLocked(next)
    }

    private func publishStateLocked(
        _ newState: IsolatedLoginState,
        callback: (@MainActor (IsolatedLoginState) -> Void)? = nil
    ) {
        state = newState
        guard let handler = callback ?? onStateChange else { return }
        Task { @MainActor in
            handler(newState)
        }
    }

    private func cleanupLocked() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        stdoutHandle?.readabilityHandler = nil
        stderrHandle?.readabilityHandler = nil
        try? stdinHandle?.close()
        stdinHandle = nil
        stdoutHandle = nil
        stderrHandle = nil

        if let process, process.isRunning {
            process.terminate()
        }
        process = nil

        if let sessionDir = sessionDirectory {
            try? fileManager.removeItem(at: sessionDir)
        }
        sessionDirectory = nil
        sessionID = nil
        loginID = nil
    }

    private func cleanupRootDirectoryLocked() {
        guard fileManager.fileExists(atPath: rootDirectory.path) else { return }
        if let contents = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: nil
        ) {
            for item in contents {
                try? fileManager.removeItem(at: item)
            }
        }
    }

    private static func stripANSI(_ text: String) -> String {
        guard let regex = ansiEscapeRegex else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }
}
