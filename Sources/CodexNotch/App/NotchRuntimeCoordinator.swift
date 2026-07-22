import AppKit
import Foundation

struct CodexHomeLocator {
    static func home(
        environment: [String: String],
        homeDirectory: URL
    ) -> URL {
        environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) }
            ?? homeDirectory.appendingPathComponent(".codex", isDirectory: true)
    }
}

final class NotchRuntimeCoordinator {
    static let sessionPollInterval: TimeInterval = 0.5
    static let rolloutRescanInterval: TimeInterval = 5
    static let usageRefreshInterval: TimeInterval = 60
    static let hoverExpandDelay: TimeInterval = 0.18
    static let hoverCollapseDelay: TimeInterval = 0.12

    private let windowController: NotchWindowController
    private let frontmostMonitor: FrontmostAppMonitor
    private let threadNavigator: CodexThreadNavigator
    private let authReader: CodexAuthReader
    private let sessionStore: ActiveSessionStore
    private let rolloutMonitor: RolloutActivityMonitor
    private let urlSession: URLSession
    private let usageEndpoint: URL
    private let nowProvider: () -> Date
    private let userDefaults: UserDefaults
    private let viewModel: NotchViewModel

    private var sessionTimer: Timer?
    private var rolloutRescanTimer: Timer?
    private var usageTask: Task<Void, Never>?
    private var started = false
    private var isChatGPTFrontmost = false
    private var isHovered = false
    private var isPointerInside = false
    private var isResetScheduleExpanded = false
    private var activeSessions: [SessionActivity] = []
    private var recentCompletions: [CompletedSession] = []
    private var usage: UsageSnapshot?
    private var lastUsageRequestAt: Date?
    private var usageRequestID: UUID?
    private var hoverExpandWorkItem: DispatchWorkItem?
    private var hoverCollapseWorkItem: DispatchWorkItem?
    private var preferencesObserver: NSObjectProtocol?
    private var lastObservedPreferences: NotchRuntimePreferences?

    init(
        windowController: NotchWindowController = NotchWindowController(),
        frontmostMonitor: FrontmostAppMonitor = FrontmostAppMonitor(),
        threadNavigator: CodexThreadNavigator = CodexThreadNavigator(),
        authReader: CodexAuthReader = CodexAuthReader(),
        sessionStore: ActiveSessionStore = ActiveSessionStore(),
        urlSession: URLSession = .shared,
        usageEndpoint: URL = CodexUsageClient.defaultEndpoint,
        nowProvider: @escaping () -> Date = { .now },
        userDefaults: UserDefaults = .standard
    ) {
        self.windowController = windowController
        self.frontmostMonitor = frontmostMonitor
        self.threadNavigator = threadNavigator
        self.authReader = authReader
        self.sessionStore = sessionStore
        self.urlSession = urlSession
        self.usageEndpoint = usageEndpoint
        self.nowProvider = nowProvider
        self.userDefaults = userDefaults
        self.viewModel = NotchViewModel()

        let codexHome = CodexHomeLocator.home(
            environment: authReader.environment,
            homeDirectory: authReader.homeDirectory
        )
        self.rolloutMonitor = RolloutActivityMonitor(
            rootURL: codexHome.appendingPathComponent("sessions", isDirectory: true),
            store: sessionStore
        )
    }

    func start() {
        guard !started else { return }
        started = true
        observePreferenceChanges()

        viewModel.onOpenThread = { [weak self] threadID in
            self?.openThread(threadID)
        }
        viewModel.onActivateChatGPT = { [weak self] in
            self?.activateChatGPT()
        }
        viewModel.onHoverChanged = { [weak self] hovered in
            self?.setHovered(hovered)
        }
        viewModel.onResetScheduleExpandedChanged = { [weak self] isExpanded in
            self?.setResetScheduleExpanded(isExpanded)
        }

        windowController.onScreenParametersChanged = { [weak self] in
            self?.render()
        }
        windowController.onOpenThread = { [weak self] threadID in
            self?.openThread(threadID)
        }
        windowController.onActivateChatGPT = { [weak self] in
            self?.activateChatGPT()
        }
        windowController.setRootView(NotchView(model: viewModel))

        frontmostMonitor.onChange = { [weak self] isFrontmost in
            DispatchQueue.main.async {
                self?.setChatGPTFrontmost(isFrontmost)
            }
        }
        frontmostMonitor.start()
        rolloutMonitor.start()

        sessionTimer = Timer.scheduledTimer(
            withTimeInterval: Self.sessionPollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.handleTimerTick()
        }
        rolloutRescanTimer = Timer.scheduledTimer(
            withTimeInterval: Self.rolloutRescanInterval,
            repeats: true
        ) { [weak self] _ in
            self?.rolloutMonitor.rescan()
        }

        refreshUsage()
        pollSessions()
        render()
    }

    func stop() {
        guard started else { return }
        started = false

        sessionTimer?.invalidate()
        sessionTimer = nil
        rolloutRescanTimer?.invalidate()
        rolloutRescanTimer = nil
        usageTask?.cancel()
        usageTask = nil
        usageRequestID = nil
        hoverExpandWorkItem?.cancel()
        hoverExpandWorkItem = nil
        hoverCollapseWorkItem?.cancel()
        hoverCollapseWorkItem = nil
        stopObservingPreferenceChanges()
        isPointerInside = false
        isHovered = false
        isResetScheduleExpanded = false

        frontmostMonitor.stop()
        rolloutMonitor.stop()
        viewModel.update(
            state: .hidden,
            now: nowProvider(),
            animationsEnabled: animationsEnabled
        )
        windowController.window?.orderOut(nil)
    }

    deinit {
        sessionTimer?.invalidate()
        rolloutRescanTimer?.invalidate()
        usageTask?.cancel()
        hoverExpandWorkItem?.cancel()
        hoverCollapseWorkItem?.cancel()
        stopObservingPreferenceChanges()
        frontmostMonitor.stop()
        rolloutMonitor.stop()
    }

    private func handleTimerTick() {
        pollSessions()
        let now = nowProvider()
        if now.timeIntervalSince(lastUsageRequestAt ?? .distantPast) >= Self.usageRefreshInterval {
            refreshUsage()
        }
    }

    private func pollSessions() {
        let store = sessionStore
        let now = nowProvider()
        Task {
            let snapshot = await store.snapshot(now: now)
            await MainActor.run { [weak self] in
                self?.apply(snapshot: snapshot, now: now)
            }
        }
    }

    private func apply(snapshot: ActiveSessionStoreSnapshot, now: Date) {
        let hadActiveSessions = !activeSessions.isEmpty
        activeSessions = snapshot.activeSessions
        if hadActiveSessions, activeSessions.isEmpty {
            resetHoverState()
        }
        recentCompletions = snapshot.recentCompletions
        render(now: now)
    }

    private func refreshUsage() {
        let requestID = UUID()
        usageRequestID = requestID
        lastUsageRequestAt = nowProvider()
        usageTask?.cancel()

        let reader = authReader
        let urlSession = self.urlSession
        let endpoint = usageEndpoint
        usageTask = Task { [weak self] in
            do {
                let credentials = try reader.read()
                let snapshot = try await CodexUsageClient(
                    credentials: credentials,
                    session: urlSession,
                    endpoint: endpoint
                ).fetch()
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self, self.usageRequestID == requestID else { return }
                    self.usage = snapshot
                    self.render()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self, self.usageRequestID == requestID else { return }
                    // Keep the last successful snapshot. A transient usage failure
                    // must not hide an otherwise valid session indicator.
                    self.render()
                }
            }
        }
    }

    private func setChatGPTFrontmost(_ isFrontmost: Bool) {
        guard isChatGPTFrontmost != isFrontmost else { return }
        isChatGPTFrontmost = isFrontmost
        if isFrontmost {
            refreshUsage()
        }
        render()
    }

    private func setHovered(_ hovered: Bool) {
        isPointerInside = hovered

        if hovered {
            hoverCollapseWorkItem?.cancel()
            hoverCollapseWorkItem = nil

            guard !isHovered, hoverExpandWorkItem == nil else { return }
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.hoverExpandWorkItem = nil
                guard self.started, self.isPointerInside, !self.isHovered else { return }
                self.isHovered = true
                self.render()
            }
            hoverExpandWorkItem = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Self.hoverExpandDelay,
                execute: workItem
            )
            return
        }

        hoverExpandWorkItem?.cancel()
        hoverExpandWorkItem = nil
        guard isHovered else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.hoverCollapseWorkItem = nil
            guard self.isHovered, !self.isPointerInside else { return }
            self.isHovered = false
            self.isResetScheduleExpanded = false
            self.render()
        }
        hoverCollapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.hoverCollapseDelay,
            execute: workItem
        )
    }

    private func resetHoverState() {
        hoverExpandWorkItem?.cancel()
        hoverExpandWorkItem = nil
        hoverCollapseWorkItem?.cancel()
        hoverCollapseWorkItem = nil
        isPointerInside = false
        isHovered = false
        isResetScheduleExpanded = false
    }

    private func setResetScheduleExpanded(_ isExpanded: Bool) {
        guard isHovered, isPointerInside,
              isResetScheduleExpanded != isExpanded else {
            return
        }
        isResetScheduleExpanded = isExpanded
        render()
    }

    private func openThread(_ threadID: String) {
        _ = threadNavigator.open(threadID: threadID)
    }

    private func activateChatGPT() {
        _ = threadNavigator.activateCodex()
    }

    private var recentConversationLimit: RecentConversationLimit {
        runtimePreferences.recentConversationLimit
    }

    private var animationsEnabled: Bool {
        runtimePreferences.animationsEnabled
    }

    private var runtimePreferences: NotchRuntimePreferences {
        NotchRuntimePreferences.read(from: userDefaults)
    }

    private func observePreferenceChanges() {
        guard preferencesObserver == nil else { return }
        lastObservedPreferences = runtimePreferences
        preferencesObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: userDefaults,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.started else { return }
            let preferences = self.runtimePreferences
            guard preferences != self.lastObservedPreferences else { return }
            self.lastObservedPreferences = preferences
            self.render()
        }
    }

    private func stopObservingPreferenceChanges() {
        if let preferencesObserver {
            NotificationCenter.default.removeObserver(preferencesObserver)
        }
        preferencesObserver = nil
        lastObservedPreferences = nil
    }

    private func expandedContentSize(
        for state: NotchPresentationState,
        isResetScheduleExpanded: Bool
    ) -> NSSize {
        guard case let .expanded(content) = state,
              !content.conversations.isEmpty else {
            return NotchExpandedLayout.taskContentSize(
                conversationCount: 2,
                isResetScheduleExpanded: isResetScheduleExpanded,
                resetCreditCount: resetCreditCount(in: state)
            )
        }
        return NotchExpandedLayout.taskContentSize(
            conversationCount: content.conversations.count,
            isResetScheduleExpanded: isResetScheduleExpanded,
            resetCreditCount: content.usage?.resetCredits.count ?? 0
        )
    }

    private func quotaExpandedContentSize(
        for state: NotchPresentationState,
        isResetScheduleExpanded: Bool
    ) -> NSSize {
        NotchExpandedLayout.quotaContentSize(
            isResetScheduleExpanded: isResetScheduleExpanded,
            resetCreditCount: resetCreditCount(in: state)
        )
    }

    private func resetCreditCount(in state: NotchPresentationState) -> Int {
        guard case let .expanded(content) = state else { return 0 }
        return content.usage?.resetCredits.count ?? 0
    }

    private func render(now: Date? = nil) {
        let renderDate = now ?? nowProvider()
        let input = NotchPresentationInput(
            now: renderDate,
            isChatGPTFrontmost: isChatGPTFrontmost,
            activeSessions: activeSessions,
            recentCompletions: recentCompletions,
            usage: usage,
            isHovered: isHovered
        )

        guard let screen = preferredScreen() else {
            windowController.window?.orderOut(nil)
            return
        }
        let metrics = NotchScreenMetrics(screen: screen)
        let baseLayout = NotchGeometry.layout(metrics: metrics)
        let state = NotchPresentationReducer.reduce(input)
        let stateForWindow: NotchPresentationState
        if baseLayout.mode == .menuBarFallback {
            stateForWindow = NotchPresentationReducer.reduce(
                NotchPresentationInput(
                    now: input.now,
                    isChatGPTFrontmost: input.isChatGPTFrontmost,
                    activeSessions: input.activeSessions,
                    recentCompletions: input.recentCompletions,
                    usage: input.usage,
                    isHovered: true
                )
            )
        } else {
            stateForWindow = state
        }
        let displayState = stateForWindow.limitingRecentConversations(
            to: recentConversationLimit
        )
        guard case .expanded = displayState else {
            isResetScheduleExpanded = false
            return renderCompactState(displayState, now: renderDate, screen: screen, metrics: metrics)
        }
        if resetCreditCount(in: displayState) == 0 {
            isResetScheduleExpanded = false
        }
        let layout = NotchGeometry.layout(
            metrics: metrics,
            quotaExpandedSize: quotaExpandedContentSize(
                for: displayState,
                isResetScheduleExpanded: isResetScheduleExpanded
            ),
            expandedSize: expandedContentSize(
                for: displayState,
                isResetScheduleExpanded: isResetScheduleExpanded
            )
        )
        let targetFrame = layout.frame(for: displayState)
        // The controller allocates the final canvas before the SwiftUI state
        // changes. That lets the island grow within one stable window instead
        // of animating the NSPanel itself.
        windowController.prepare(
            layout: layout,
            state: displayState,
            animationsEnabled: animationsEnabled
        )
        viewModel.update(
            state: displayState,
            now: renderDate,
            cameraSafeAreaInset: max(0, screen.safeAreaInsets.top),
            compactWidth: layout.compactFrame.width,
            surfaceSize: targetFrame.size,
            isResetScheduleExpanded: isResetScheduleExpanded,
            animationsEnabled: animationsEnabled
        )
        windowController.settleFrame(
            layout: layout,
            state: displayState,
            animationsEnabled: animationsEnabled
        )
    }

    private func renderCompactState(
        _ displayState: NotchPresentationState,
        now: Date,
        screen: NSScreen,
        metrics: NotchScreenMetrics
    ) {
        let layout = NotchGeometry.layout(metrics: metrics)
        let targetFrame = layout.frame(for: displayState)
        windowController.prepare(
            layout: layout,
            state: displayState,
            animationsEnabled: animationsEnabled
        )
        viewModel.update(
            state: displayState,
            now: now,
            cameraSafeAreaInset: max(0, screen.safeAreaInsets.top),
            compactWidth: layout.compactFrame.width,
            surfaceSize: targetFrame.size,
            isResetScheduleExpanded: false,
            animationsEnabled: animationsEnabled
        )
        windowController.settleFrame(
            layout: layout,
            state: displayState,
            animationsEnabled: animationsEnabled
        )
    }

    private func preferredScreen() -> NSScreen? {
        let screens = NSScreen.screens
        let main = NSScreen.main
        if let main,
           main.auxiliaryTopLeftArea != nil,
           main.auxiliaryTopRightArea != nil {
            return main
        }
        return screens.first {
            $0.auxiliaryTopLeftArea != nil && $0.auxiliaryTopRightArea != nil
        } ?? main ?? screens.first
    }
}
