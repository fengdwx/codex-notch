import AppKit
import SwiftUI

struct NotchSettingsView: View {
    static let githubRepositoryURL = URL(string: "https://github.com/fengdwx/codex-notch")!

    @AppStorage(QuotaDisplayStyle.storageKey)
    private var quotaDisplayStyleRaw = QuotaDisplayStyle.defaultStyle.rawValue
    @AppStorage(StatusIconStyle.storageKey)
    private var statusIconStyleRaw = StatusIconStyle.defaultStyle.rawValue
    @AppStorage(RecentConversationLimit.storageKey)
    private var recentConversationLimitRaw = RecentConversationLimit.defaultLimit.rawValue
    @AppStorage(AppLanguage.storageKey)
    private var appLanguageRaw = AppLanguage.defaultLanguage.rawValue
    @AppStorage(AppAnimationPreference.storageKey)
    private var animationsEnabled = AppAnimationPreference.defaultEnabled
    @AppStorage(FloatingCenterStyle.storageKey)
    private var floatingCenterStyleRaw = FloatingCenterStyle.defaultStyle.rawValue
    @AppStorage(FloatingCenterText.storageKey)
    private var floatingCenterText = FloatingCenterText.defaultText
    @AppStorage(NotchDisplayPreference.storageKey)
    private var notchDisplayEnabled = NotchDisplayPreference.defaultEnabled

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var updater = AppUpdater.shared
    @ObservedObject private var launchAtLogin = LaunchAtLogin.shared
    @ObservedObject private var accountsService: AccountsService
    private let appVersionOverride: AppVersion?

    @State private var selectedTab: SettingsTab
    @State private var hoveredTab: SettingsTab?
    @State private var isFooterHovered = false
    @State private var isUpdateFooterHovered = false
    @State private var isShowingWebLoginSheet = false
    @State private var layoutMode: NotchLayoutMode?
    @State private var previewState = FloatingPreviewState.running

    init(
        initialTab: SettingsTab = .general,
        accountsService: AccountsService = .shared,
        appVersion: AppVersion? = nil
    ) {
        self.accountsService = accountsService
        self.appVersionOverride = appVersion
        _selectedTab = State(initialValue: initialTab)
    }

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general
        case appearance
        case floating
        case accounts

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintbrush"
            case .floating: return "menubar.rectangle"
            case .accounts: return "person.2"
            }
        }

        func title(for language: AppLanguage) -> String {
            switch self {
            case .general: return language.localized(chinese: "通用", english: "General")
            case .appearance: return language.localized(chinese: "外观", english: "Appearance")
            case .floating: return language.localized(chinese: "外接屏悬浮岛", english: "External Island")
            case .accounts: return language.localized(chinese: "账号", english: "Accounts")
            }
        }
    }

    private var appLanguage: AppLanguage {
        AppLanguage.fromStoredValue(appLanguageRaw)
    }

    private var selectedStyle: QuotaDisplayStyle {
        QuotaDisplayStyle.fromStoredValue(quotaDisplayStyleRaw)
    }

    private var selectedStatusIconStyle: StatusIconStyle {
        StatusIconStyle.fromStoredValue(statusIconStyleRaw)
    }

    private var recentConversationLimit: RecentConversationLimit {
        RecentConversationLimit.fromStoredValue(recentConversationLimitRaw)
    }

    private var floatingStyle: FloatingCenterStyle {
        .fromStoredValue(floatingCenterStyleRaw)
    }

    private var floatingContext: FloatingSettingsContext {
        FloatingSettingsContext(layoutMode: layoutMode, displayEnabled: notchDisplayEnabled)
    }

    private var currentVersion: AppVersion {
        appVersionOverride ?? AppVersion.fromBundle() ?? .zero
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            SettingsWindowShellBackground()

            HStack(spacing: 0) {
                sidebar
                detailPane
            }
        }
        .frame(
            minWidth: NotchSettingsLayout.windowWidth,
            idealWidth: NotchSettingsLayout.windowWidth,
            maxWidth: .infinity,
            minHeight: NotchSettingsLayout.windowHeight,
            idealHeight: NotchSettingsLayout.windowHeight,
            maxHeight: .infinity
        )
        .ignoresSafeArea()
        .background(SettingsWindowChromeAccessor())
        .onAppear {
            refreshSystemState()
            SettingsWindowPresenter.bringToFront()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshSystemState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            refreshSystemState()
        }
    }

    // MARK: - Left Sidebar (Unified Neutral Shell)

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Uncluttered top drag strip aligned with the macOS traffic lights (y = 0..40pt)
            SettingsWindowDragArea()
                .frame(height: NotchSettingsLayout.topBarHeight)
                .padding(.leading, 76)

            // Compact brand block aligned optically with the top edge of the inset detail sheet
            HStack(spacing: 10) {
                CodexNotchBrandIcon(width: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text("CodexNotch")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(currentVersion.displayValue)
                        .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SettingsWindowDragArea())

            VStack(spacing: 3) {
                ForEach(SettingsTab.allCases) { tab in
                    sidebarItem(tab)
                }
            }
            .padding(.horizontal, NotchSettingsLayout.sheetInset)

            Spacer(minLength: 12)
                .frame(maxWidth: .infinity)
                .background(SettingsWindowDragArea())

            sidebarFooter
        }
        .frame(width: NotchSettingsLayout.sidebarWidth)
        .frame(maxHeight: .infinity)
    }

    private func sidebarItem(_ tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab
        let isHovered = hoveredTab == tab
        let pillShape = RoundedRectangle(cornerRadius: 8.5, style: .continuous)

        let pillFill: Color = {
            if isSelected {
                return colorScheme == .dark ? Color.white.opacity(0.10) : Color.white
            }
            if isHovered {
                return colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.045)
            }
            return .clear
        }()

        let pillBorder: Color = {
            guard isSelected else { return .clear }
            return colorScheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.08)
        }()

        return Button {
            withAnimation(.easeInOut(duration: 0.14)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 18, alignment: .center)

                Text(tab.title(for: appLanguage))
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.84))

                Spacer(minLength: 4)

                if tab == .accounts, !accountsService.accounts.isEmpty {
                    Text("\(accountsService.accounts.count)")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.accentColor.opacity(0.13) : Color.primary.opacity(0.06))
                        )
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                pillShape
                    .fill(pillFill)
                    .shadow(
                        color: Color.black.opacity(isSelected && colorScheme != .dark ? 0.035 : 0),
                        radius: 2,
                        y: 1
                    )
            )
            .overlay(
                pillShape.strokeBorder(pillBorder, lineWidth: 0.5)
            )
            .contentShape(pillShape)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredTab = hovering ? tab : (hoveredTab == tab ? nil : hoveredTab)
        }
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 2) {
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 0.5)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)

            sidebarFooterRow(
                isHovered: $isUpdateFooterHovered,
                isDisabled: !updater.canCheckForUpdates,
                help: updater.startupError ?? appLanguage.localized(
                    chinese: "当前版本 \(currentVersion.displayValue) · 检查新版本",
                    english: "Current version \(currentVersion.displayValue) · Check for updates"
                ),
                action: { updater.checkForUpdates() },
                icon: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, alignment: .center)
                },
                title: appLanguage.localized(chinese: "检查更新", english: "Check Updates"),
                trailing: {
                    Text(currentVersion.displayValue)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.75))
                }
            )

            sidebarFooterRow(
                isHovered: $isFooterHovered,
                help: Self.githubRepositoryURL.absoluteString,
                action: { NSWorkspace.shared.open(Self.githubRepositoryURL) },
                icon: {
                    GitHubMarkIcon(size: 13)
                        .foregroundStyle(.secondary)
                        .frame(width: 18, alignment: .center)
                },
                title: "GitHub",
                trailing: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(isFooterHovered ? 0.85 : 0.45))
                }
            )
        }
        .padding(.horizontal, NotchSettingsLayout.sheetInset)
        .padding(.bottom, NotchSettingsLayout.sheetInset)
    }

    private func sidebarFooterRow<Icon: View, Trailing: View>(
        isHovered: Binding<Bool>,
        isDisabled: Bool = false,
        help: String,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon,
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8.5, style: .continuous)
        let activeHover = isHovered.wrappedValue && !isDisabled
        let hoverFill: Color = {
            guard activeHover else { return .clear }
            return colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.045)
        }()

        return Button(action: action) {
            HStack(spacing: 9) {
                icon()

                Text(title)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(.primary.opacity(0.80))
                    .lineLimit(1)

                Spacer(minLength: 4)

                trailing()
            }
            .padding(.horizontal, 10)
            .frame(height: 29)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(isDisabled ? 0.45 : 1)
            .background(shape.fill(hoverFill))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { isHovered.wrappedValue = $0 }
        .help(help)
    }

    // MARK: - Unified Top Header Bar + Inset Rounded Detail Sheet

    private var detailPane: some View {
        VStack(spacing: 0) {
            unifiedTopBar

            SettingsDetailSheet {
                Group {
                    switch selectedTab {
                    case .general:
                        ScrollView(.vertical, showsIndicators: false) {
                            generalSettings
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 18)
                        }
                    case .appearance:
                        ScrollView(.vertical, showsIndicators: false) {
                            appearanceSettings
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 18)
                        }
                    case .floating:
                        ScrollView(.vertical, showsIndicators: false) {
                            floatingSettings
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 18)
                        }
                    case .accounts:
                        accountsSettings
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 16)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.trailing, NotchSettingsLayout.sheetInset)
            .padding(.bottom, NotchSettingsLayout.sheetInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unifiedTopBar: some View {
        HStack(spacing: 10) {
            Text(selectedTab.title(for: appLanguage))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.leading, 4)

            Spacer(minLength: 8)

            if selectedTab == .accounts {
                HStack(spacing: 6) {
                    SettingsIconButton(
                        systemName: "arrow.clockwise",
                        tint: .secondary,
                        isLoading: accountsService.isRefreshingQuotas,
                        isDisabled: accountsService.isRefreshingQuotas || accountsService.accounts.isEmpty,
                        helpText: appLanguage.localized(chinese: "刷新全部账号额度", english: "Refresh all account quotas")
                    ) {
                        Task { await accountsService.refreshAllQuotas() }
                    }

                    SettingsActionButton(
                        title: appLanguage.localized(chinese: "网页登录", english: "Sign in"),
                        systemImage: "plus",
                        tone: .prominent(.accentColor)
                    ) {
                        isShowingWebLoginSheet = true
                        accountsService.startWebLogin(language: appLanguage)
                    }
                }
                .padding(.trailing, NotchSettingsLayout.sheetInset)
            }
        }
        .frame(height: NotchSettingsLayout.topBarHeight)
        .frame(maxWidth: .infinity)
        .background(SettingsWindowDragArea())
    }

    // MARK: - General Page

    private static let recentLimitPresets: [RecentConversationLimit] = [.none, .one, .two, .three]

    private var generalSettings: some View {
        let segmentWidth: CGFloat = 208

        return VStack(alignment: .leading, spacing: 14) {
            SettingsSheetIntro(
                subtitle: appLanguage.localized(
                    chinese: "控制启动行为、界面语言与展开卡片中的近期任务记录",
                    english: "Configure startup behavior, display language, and recent conversation history"
                )
            )

            SettingsSurfaceCard(padding: 0) {
                VStack(spacing: 0) {
                    SettingsRow(
                        title: appLanguage.localized(chinese: "登录时启动", english: "Launch at login"),
                        subtitle: appLanguage.localized(
                            chinese: "登录 Mac 时自动在后台启动 CodexNotch",
                            english: "Automatically launch CodexNotch when you log in"
                        )
                    ) {
                        Toggle("", isOn: Binding(
                            get: { launchAtLogin.isRequested },
                            set: { launchAtLogin.setEnabled($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(SettingsCapsuleToggleStyle())
                    }
                    .padding(.horizontal, 16)

                    if launchAtLogin.status == .requiresApproval || launchAtLogin.errorMessage != nil {
                        launchAtLoginNotice
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                    }

                    SettingsHairlineDivider()
                        .padding(.horizontal, 16)

                    SettingsRow(
                        title: appLanguage.localized(chinese: "界面语言", english: "Language"),
                        subtitle: appLanguage.localized(
                            chinese: "实时切换状态卡片与设置语言",
                            english: "Switch notch card and settings language"
                        )
                    ) {
                        SettingsSegmentedControl(
                            items: AppLanguage.allCases,
                            selection: appLanguageBinding,
                            fixedWidth: segmentWidth,
                            equalWidth: true,
                            titleProvider: { $0.title }
                        )
                    }
                    .padding(.horizontal, 16)

                    SettingsHairlineDivider()
                        .padding(.horizontal, 16)

                    SettingsRow(
                        title: appLanguage.localized(chinese: "最近任务数量", english: "Recent tasks"),
                        subtitle: appLanguage.localized(
                            chinese: "展开卡片最多展示的近期对话条数",
                            english: "Max recent conversations when expanded"
                        )
                    ) {
                        SettingsSegmentedControl(
                            items: Self.recentLimitPresets,
                            selection: recentConversationLimitBinding,
                            fixedWidth: segmentWidth,
                            equalWidth: true,
                            titleProvider: { limit in
                                limit.rawValue == 0
                                    ? appLanguage.localized(chinese: "隐藏", english: "Off")
                                    : "\(limit.rawValue)"
                            }
                        )
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var launchAtLoginNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            if launchAtLogin.status == .requiresApproval {
                HStack(spacing: 8) {
                    Text(appLanguage.localized(
                        chinese: "需在“系统设置 → 登录项”中允许登录时启动。",
                        english: "Approval in System Settings → Login Items is required."
                    ))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    Spacer()
                    SettingsActionButton(
                        title: appLanguage.localized(chinese: "打开登录项…", english: "Open Login Items…"),
                        tone: .secondary
                    ) {
                        launchAtLogin.openSystemSettings()
                    }
                }
            }
            if let error = launchAtLogin.errorMessage {
                Text(appLanguage.localized(
                    chinese: "无法保存自动启动设置：\(error)",
                    english: "Unable to save launch-at-login: \(error)"
                ))
                .font(.system(size: 11))
                .foregroundStyle(.red)
                if launchAtLogin.status == .notFound {
                    Text(appLanguage.localized(
                        chinese: "请将 CodexNotch 移至“应用程序”文件夹后重新打开。",
                        english: "Move CodexNotch to the Applications folder and reopen it."
                    ))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.09))
        )
    }

    // MARK: - Appearance Page (Single Authentic Hero Notch Stage + Clean Controls)

    private var appearanceSettings: some View {
        let segmentWidth: CGFloat = 208

        return VStack(alignment: .leading, spacing: 14) {
            SettingsSheetIntro(
                subtitle: appLanguage.localized(
                    chinese: "实时预览并自定义刘海两侧的额度样式与状态图标",
                    english: "Preview and customize quota rings, left-side indicator, and motion"
                )
            )

            notchHeroStage

            SettingsSurfaceCard(padding: 0) {
                VStack(spacing: 0) {
                    SettingsRow(
                        title: appLanguage.localized(chinese: "右侧额度样式", english: "Quota style"),
                        subtitle: selectedStyle.subtitle(for: appLanguage)
                    ) {
                        SettingsSegmentedControl(
                            items: QuotaDisplayStyle.allCases,
                            selection: Binding(
                                get: { selectedStyle },
                                set: { quotaDisplayStyleRaw = $0.rawValue }
                            ),
                            fixedWidth: segmentWidth,
                            equalWidth: true,
                            titleProvider: { $0.title(for: appLanguage) }
                        )
                    }
                    .padding(.horizontal, 16)

                    SettingsHairlineDivider()
                        .padding(.horizontal, 16)

                    SettingsRow(
                        title: appLanguage.localized(chinese: "刘海左侧显示", english: "Left side"),
                        subtitle: appLanguage.localized(
                            chinese: "5h 额度可用时优先展示；关闭可减少与菜单栏重叠",
                            english: "5h quota takes priority when present; Off avoids menu-bar overlap"
                        )
                    ) {
                        SettingsSegmentedControl(
                            items: StatusIconStyle.allCases,
                            selection: Binding(
                                get: { selectedStatusIconStyle },
                                set: { statusIconStyleRaw = $0.rawValue }
                            ),
                            fixedWidth: segmentWidth,
                            equalWidth: true,
                            titleProvider: { $0.title(for: appLanguage) }
                        )
                    }
                    .padding(.horizontal, 16)

                    SettingsHairlineDivider()
                        .padding(.horizontal, 16)

                    SettingsRow(
                        title: appLanguage.localized(chinese: "动画效果", english: "Animations"),
                        subtitle: appLanguage.localized(
                            chinese: "关闭动画可降低图形开销，额度与任务状态照常实时更新",
                            english: "Turn off animations to reduce overhead; quota & status keep updating"
                        )
                    ) {
                        Toggle("", isOn: $animationsEnabled)
                            .labelsHidden()
                            .toggleStyle(SettingsCapsuleToggleStyle())
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var notchHeroStage: some View {
        let sampleWindow = UsageWindow(id: "appearance-preview", kind: .weekly, usedPercent: 25)
        let sampleUsage = UsageSnapshot(windows: [sampleWindow])
        let sampleTheme = StatusIconTheme(usage: sampleUsage)
        let previewMotionEnabled = selectedTab == .appearance && animationsEnabled
        let previewActivity: QuotaRingActivity = previewMotionEnabled ? .running : .idle
        let notchShape = NotchSurfaceShape(
            layoutMode: .notch,
            shoulderDepth: 6,
            bottomRadius: 13,
            leadingInset: selectedStatusIconStyle.showsLeftIndicator ? 0 : 44
        )

        return DarkPreviewStage {
            VStack(spacing: 0) {
                // Authentic macOS top menu bar backdrop with centered physical notch preview
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 30)

                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 11))
                            Text("Codex")
                                .font(.system(size: 10.5, weight: .semibold))
                            Text("File")
                                .font(.system(size: 10.5))
                                .opacity(0.75)
                        }
                        Spacer()
                        HStack(spacing: 9) {
                            Image(systemName: "wifi")
                                .font(.system(size: 10))
                            Image(systemName: "battery.100")
                                .font(.system(size: 11))
                            Text("09:41")
                                .font(.system(size: 10.5, weight: .medium))
                                .monospacedDigit()
                        }
                    }
                    .foregroundStyle(.white.opacity(0.52))
                    .padding(.horizontal, 16)
                    .frame(height: 30)

                    // Centered MacBook physical notch + CodexNotch wings
                    HStack(spacing: 0) {
                        ZStack {
                            if selectedStatusIconStyle.showsLeftIndicator {
                                if previewMotionEnabled, selectedStatusIconStyle.templateImage != nil {
                                    StatusMarkEchoLayer(
                                        isAnimating: true,
                                        iconStyle: selectedStatusIconStyle,
                                        color: sampleTheme.runningEcho
                                    )
                                    .frame(width: 17, height: 17)
                                    .allowsHitTesting(false)
                                }

                                StatusMark(
                                    style: selectedStatusIconStyle,
                                    size: 17,
                                    theme: sampleTheme
                                )
                            }
                        }
                        .frame(width: 44, height: 32)

                        // Physical camera cutout area
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 6, height: 6)
                                .overlay(
                                    Circle()
                                        .fill(Color(red: 0.14, green: 0.24, blue: 0.42).opacity(0.8))
                                        .frame(width: 3, height: 3)
                                )
                        }
                        .frame(width: 146, height: 32)

                        ZStack {
                            if QuotaRunningHaloMotion.shouldAnimate(
                                layoutMode: .notch,
                                activity: previewActivity,
                                hasQuota: true,
                                motionEnabled: previewMotionEnabled
                            ) {
                                QuotaRunningHaloView(isAnimating: true)
                                    .frame(
                                        width: QuotaRunningHaloMotion.visualDiameter,
                                        height: QuotaRunningHaloMotion.visualDiameter
                                    )
                                    .allowsHitTesting(false)
                            }

                            QuotaIndicatorView(
                                style: selectedStyle,
                                window: sampleWindow,
                                activity: previewActivity,
                                diameter: 22,
                                lineWidth: NotchCompactLayout.quotaIndicatorLineWidth(for: selectedStyle),
                                fontSize: 9.5
                            )
                            .environment(\.notchMotionEnabled, previewMotionEnabled)
                        }
                        .frame(width: 44, height: 32)
                    }
                    .background(Color.black, in: notchShape)
                    .clipShape(notchShape)
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
                }

                Spacer(minLength: 26)

                HStack {
                    Text(
                        animationsEnabled
                            ? appLanguage.localized(
                                chinese: "刘海实时预览 · 运行中示例 75%",
                                english: "Live notch preview · Running sample 75%"
                            )
                            : appLanguage.localized(
                                chinese: "刘海实时预览 · 静态示例 75%（动画已关闭）",
                                english: "Live notch preview · Static sample 75% (Motion off)"
                            )
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))

                    Spacer()

                    Text("\(selectedStyle.title(for: appLanguage)) · \(selectedStatusIconStyle.title(for: appLanguage))")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.09)))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(height: 116)
    }

    // MARK: - Floating Bar Page

    private var floatingSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSheetIntro(
                subtitle: floatingContext.explanation(for: appLanguage)
            )

            DarkPreviewStage {
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 28)

                        HStack {
                            HStack(spacing: 10) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 11))
                                Text("Codex")
                                    .font(.system(size: 10.5, weight: .semibold))
                            }
                            Spacer()
                            Text("09:41")
                                .font(.system(size: 10.5, weight: .medium))
                                .monospacedDigit()
                        }
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.horizontal, 16)
                        .frame(height: 28)

                        if selectedTab == .floating {
                            FloatingBarSettingsPreview(
                                style: floatingStyle,
                                customText: floatingCenterText,
                                state: previewState,
                                language: appLanguage,
                                animationsEnabled: animationsEnabled,
                                quotaStyle: selectedStyle,
                                iconStyle: selectedStatusIconStyle
                            )
                            .sampleBar
                            .shadow(color: .black.opacity(0.5), radius: 8, y: 3)
                        }
                    }

                    Spacer(minLength: 26)

                    HStack(spacing: 10) {
                        SettingsSegmentedControl(
                            items: FloatingPreviewState.allCases,
                            selection: $previewState,
                            darkAppearance: true,
                            titleProvider: { $0.title(for: appLanguage) }
                        )

                        Spacer()

                        Text(floatingContext.title(for: appLanguage))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
            .frame(height: 126)

            SettingsSurfaceCard(padding: 0) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(appLanguage.localized(chinese: "中间样式", english: "Center style"))
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            SettingsSegmentedControl(
                                items: FloatingCenterStyle.allCases,
                                selection: Binding(
                                    get: { floatingStyle },
                                    set: { floatingCenterStyleRaw = $0.rawValue }
                                ),
                                titleProvider: { $0.title(for: appLanguage) }
                            )
                        }

                        Text(floatingStyle.explanation(for: appLanguage))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if floatingStyle.usesCustomText {
                        SettingsHairlineDivider()
                            .padding(.horizontal, 16)

                        SettingsRow(
                            title: appLanguage.localized(chinese: "自定义文字", english: "Custom text"),
                            subtitle: appLanguage.localized(
                                chinese: "最多 12 个字符，留空时默认显示 Codex",
                                english: "Up to 12 characters; defaults to Codex when blank"
                            )
                        ) {
                            TextField(
                                FloatingCenterText.defaultText,
                                text: $floatingCenterText
                            )
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5, weight: .medium))
                            .padding(.horizontal, 12)
                            .frame(width: 170, height: 26)
                            .background(
                                Capsule()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
                                    .shadow(
                                        color: Color.black.opacity(colorScheme == .dark ? 0 : 0.04),
                                        radius: 1.5,
                                        y: 0.75
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10),
                                        lineWidth: 0.5
                                    )
                            )
                            .onChange(of: floatingCenterText) { _, value in
                                let limited = String(value.prefix(FloatingCenterText.maximumCharacters))
                                if limited != value { floatingCenterText = limited }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if !animationsEnabled {
                        SettingsHairlineDivider()
                            .padding(.horizontal, 16)

                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(appLanguage.localized(
                                chinese: "动画效果当前已关闭，可在“外观”中重新开启。",
                                english: "Animations are turned off. Re-enable them in Appearance."
                            ))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    // MARK: - Accounts Page

    private var accountsSettings: some View {
        AccountsSettingsView(
            service: accountsService,
            appLanguage: appLanguage,
            isShowingWebLoginSheet: $isShowingWebLoginSheet
        )
    }

    // MARK: - Bindings & Lifecycle

    private var recentConversationLimitBinding: Binding<RecentConversationLimit> {
        Binding(
            get: { recentConversationLimit },
            set: { recentConversationLimitRaw = $0.rawValue }
        )
    }

    private var appLanguageBinding: Binding<AppLanguage> {
        Binding(
            get: { appLanguage },
            set: { appLanguageRaw = $0.rawValue }
        )
    }

    private func refreshSystemState() {
        launchAtLogin.refresh()
        layoutMode = NotchScreenMetrics.preferredScreen().map {
            NotchGeometry.layout(metrics: NotchScreenMetrics(screen: $0)).mode
        }
    }
}

struct SettingsHelpTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct GitHubMarkIcon: View {
    let size: CGFloat

    var body: some View {
        GitHubMarkShape()
            .fill(style: FillStyle(eoFill: false, antialiased: true))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct GitHubMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 24.0
        let sy = rect.height / 24.0
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()
        path.move(to: p(12.000, 0.297))
        path.addCurve(to: p(0.000, 12.297), control1: p(5.370, 0.297), control2: p(0.000, 5.670))
        path.addCurve(to: p(8.205, 23.682), control1: p(0.000, 17.600), control2: p(3.438, 22.097))
        path.addCurve(to: p(9.025, 23.105), control1: p(8.805, 23.795), control2: p(9.025, 23.424))
        path.addCurve(to: p(9.010, 21.065), control1: p(9.025, 22.820), control2: p(9.015, 22.065))
        path.addCurve(to: p(4.968, 19.455), control1: p(5.672, 21.789), control2: p(4.968, 19.455))
        path.addCurve(to: p(3.633, 17.700), control1: p(4.422, 18.070), control2: p(3.633, 17.700))
        path.addCurve(to: p(3.717, 16.971), control1: p(2.546, 16.956), control2: p(3.717, 16.971))
        path.addCurve(to: p(5.555, 18.207), control1: p(4.922, 17.055), control2: p(5.555, 18.207))
        path.addCurve(to: p(9.050, 19.205), control1: p(6.625, 20.042), control2: p(8.364, 19.512))
        path.addCurve(to: p(9.810, 17.600), control1: p(9.158, 18.429), control2: p(9.467, 17.900))
        path.addCurve(to: p(4.344, 11.670), control1: p(7.145, 17.300), control2: p(4.344, 16.268))
        path.addCurve(to: p(5.579, 8.450), control1: p(4.344, 10.360), control2: p(4.809, 9.290))
        path.addCurve(to: p(5.684, 5.274), control1: p(5.444, 8.147), control2: p(5.039, 6.927))
        path.addCurve(to: p(8.984, 6.504), control1: p(5.684, 5.274), control2: p(6.689, 4.952))
        path.addCurve(to: p(11.984, 6.099), control1: p(9.944, 6.237), control2: p(10.964, 6.105))
        path.addCurve(to: p(14.984, 6.504), control1: p(13.004, 6.105), control2: p(14.024, 6.237))
        path.addCurve(to: p(18.269, 5.274), control1: p(17.264, 4.952), control2: p(18.269, 5.274))
        path.addCurve(to: p(18.389, 8.450), control1: p(18.914, 6.927), control2: p(18.509, 8.147))
        path.addCurve(to: p(19.619, 11.670), control1: p(19.154, 9.290), control2: p(19.619, 10.360))
        path.addCurve(to: p(14.144, 17.590), control1: p(19.619, 16.280), control2: p(16.814, 17.295))
        path.addCurve(to: p(14.954, 19.810), control1: p(14.564, 17.950), control2: p(14.954, 18.686))
        path.addCurve(to: p(14.939, 23.096), control1: p(14.954, 21.416), control2: p(14.939, 22.706))
        path.addCurve(to: p(15.764, 23.666), control1: p(14.939, 23.411), control2: p(15.149, 23.786))
        path.addCurve(to: p(24.000, 12.297), control1: p(20.565, 22.092), control2: p(24.000, 17.592))
        path.addCurve(to: p(12.000, 0.297), control1: p(24.000, 5.670), control2: p(18.627, 0.297))
        path.closeSubpath()
        return path
    }
}
