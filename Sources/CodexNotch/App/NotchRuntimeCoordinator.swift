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
    static let fullScreenPollInterval: TimeInterval = 1
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
    private var isFullScreenSuppressed = false
    private var isHovered = false
    private var isPointerInside = false
    private var isResetScheduleExpanded = false
    private var activeSessions: [SessionActivity] = []
    private var recentCompletions: [CompletedSession] = []
    private var usage: UsageSnapshot?
    private var lastUsageRequestAt: Date?
    private var lastFullScreenCheckAt: Date?
    private var usageRequestID: UUID?
    private var hoverExpandWorkItem: DispatchWorkItem?
    private var hoverCollapseWorkItem: DispatchWorkItem?
    private var preferencesObserver: NSObjectProtocol?
    private var lastObservedPreferences: NotchRuntimePreferences?
    private var visibilityShortcut: NotchVisibilityShortcut?

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
        visibilityShortcut = NotchVisibilityShortcut { [weak self] in
            self?.toggleNotchDisplay()
        }

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
        _ = refreshFullScreenSuppression()
        lastFullScreenCheckAt = nowProvider()
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
        lastFullScreenCheckAt = nil
        hoverExpandWorkItem?.cancel()
        hoverExpandWorkItem = nil
        hoverCollapseWorkItem?.cancel()
        hoverCollapseWorkItem = nil
        visibilityShortcut = nil
        stopObservingPreferenceChanges()
        isPointerInside = false
        isHovered = false
        isResetScheduleExpanded = false
        isFullScreenSuppressed = false

        frontmostMonitor.stop()
        rolloutMonitor.stop()
        viewModel.update(
            state: .hidden,
            now: nowProvider(),
            animationsEnabled: animationsEnabled
        )
        windowController.hideNotchPanel()
    }

    deinit {
        sessionTimer?.invalidate()
        rolloutRescanTimer?.invalidate()
        usageTask?.cancel()
        hoverExpandWorkItem?.cancel()
        hoverCollapseWorkItem?.cancel()
        visibilityShortcut = nil
        stopObservingPreferenceChanges()
        frontmostMonitor.stop()
        rolloutMonitor.stop()
    }

    private func handleTimerTick() {
        let now = nowProvider()
        if now.timeIntervalSince(lastFullScreenCheckAt ?? .distantPast)
            >= Self.fullScreenPollInterval {
            lastFullScreenCheckAt = now
            if refreshFullScreenSuppression() {
                render(now: now)
            }
        }
        pollSessions()
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
        let frontmostStateChanged = isChatGPTFrontmost != isFrontmost
        if isChatGPTFrontmost != isFrontmost {
            isChatGPTFrontmost = isFrontmost
            if isFrontmost {
                refreshUsage()
            }
        }
        let suppressionChanged = refreshFullScreenSuppression()
        lastFullScreenCheckAt = nowProvider()
        if frontmostStateChanged || suppressionChanged {
            render()
        }
        // The monitor calls this for every app switch, including transitions
        // between two non-Codex apps that both map to `false`.
        windowController.reassertNotchPanelAfterApplicationSwitch(
            displayIsEnabled: runtimePreferences.notchDisplayEnabled
        )
    }

    private func refreshFullScreenSuppression() -> Bool {
        let shouldSuppress: Bool
        if let screen = preferredScreen(),
           screen.auxiliaryTopLeftArea != nil,
           screen.auxiliaryTopRightArea != nil {
            shouldSuppress = FrontmostFullScreenDetector
                .isFrontmostApplicationFullScreen(on: screen)
        } else {
            shouldSuppress = false
        }

        guard shouldSuppress != isFullScreenSuppressed else { return false }
        isFullScreenSuppressed = shouldSuppress
        if shouldSuppress {
            resetHoverState()
        }
        windowController.setFullScreenSuppressed(shouldSuppress)
        return true
    }

    private func toggleNotchDisplay() {
        userDefaults.set(
            NotchDisplayPreference.toggledValue(
                for: runtimePreferences.notchDisplayEnabled
            ),
            forKey: NotchDisplayPreference.storageKey
        )
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
        let preferences = runtimePreferences
        guard let screen = preferredScreen() else {
            resetHoverState()
            windowController.hideNotchPanel()
            return
        }
        if isFullScreenSuppressed {
            resetHoverState()
            windowController.setFullScreenSuppressed(true)
            return
        }
        let metrics = NotchScreenMetrics(screen: screen)
        let baseLayout = NotchGeometry.layout(metrics: metrics)

        if baseLayout.mode == .menuBarFallback {
            if !preferences.notchDisplayEnabled {
                resetHoverState()
                viewModel.update(
                    state: .hidden,
                    now: renderDate,
                    animationsEnabled: false
                )
                windowController.showDisplayDisabledFallback()
                return
            }
        } else if NotchPanelVisibilityPolicy.shouldKeepHiddenHoverSensor(
            layoutMode: baseLayout.mode,
            displayIsEnabled: preferences.notchDisplayEnabled
        ), !isHovered {
            return renderHiddenHoverSensor(
                now: renderDate,
                screen: screen,
                metrics: metrics
            )
        }

        let input = NotchPresentationInput(
            now: renderDate,
            isChatGPTFrontmost: isChatGPTFrontmost,
            activeSessions: activeSessions,
            recentCompletions: recentCompletions,
            usage: usage,
            isHovered: isHovered
        )

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

    private func renderHiddenHoverSensor(
        now: Date,
        screen: NSScreen,
        metrics: NotchScreenMetrics
    ) {
        let layout = NotchGeometry.layout(metrics: metrics)
        guard layout.mode == .notch else {
            windowController.showDisplayDisabledFallback()
            return
        }

        let hiddenState = NotchPresentationState.hidden
        let targetFrame = layout.frame(for: hiddenState)
        windowController.prepare(
            layout: layout,
            state: hiddenState,
            animationsEnabled: false
        )
        viewModel.update(
            state: hiddenState,
            now: now,
            cameraSafeAreaInset: max(0, screen.safeAreaInsets.top),
            compactWidth: layout.compactFrame.width,
            surfaceSize: targetFrame.size,
            isResetScheduleExpanded: false,
            animationsEnabled: false
        )
        windowController.settleFrame(
            layout: layout,
            state: hiddenState,
            animationsEnabled: false
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
