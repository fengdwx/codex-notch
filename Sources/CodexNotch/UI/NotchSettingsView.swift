import SwiftUI

struct NotchSettingsView: View {
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
    @ObservedObject private var updater = AppUpdater.shared
    @ObservedObject private var launchAtLogin = LaunchAtLogin.shared

    private var appLanguage: AppLanguage {
        AppLanguage.fromStoredValue(appLanguageRaw)
    }

    private var selectedStyle: QuotaDisplayStyle {
        QuotaDisplayStyle.fromStoredValue(quotaDisplayStyleRaw)
    }

    private var selectedStyleBinding: Binding<QuotaDisplayStyle> {
        Binding(
            get: { selectedStyle },
            set: { quotaDisplayStyleRaw = $0.rawValue }
        )
    }

    private var recentConversationLimit: RecentConversationLimit {
        RecentConversationLimit.fromStoredValue(recentConversationLimitRaw)
    }

    private var statusIconStyleBinding: Binding<StatusIconStyle> {
        Binding(
            get: { StatusIconStyle.fromStoredValue(statusIconStyleRaw) },
            set: { statusIconStyleRaw = $0.rawValue }
        )
    }

    private var recentConversationLimitBinding: Binding<RecentConversationLimit> {
        Binding(
            get: { recentConversationLimit },
            set: { recentConversationLimitRaw = $0.rawValue }
        )
    }

    @AppStorage(NotchDisplayPreference.storageKey)
    private var notchDisplayEnabled = NotchDisplayPreference.defaultEnabled
    @State private var selectedTab: SettingsTab = .general
    @State private var layoutMode: NotchLayoutMode?
    @State private var previewState = FloatingPreviewState.running

    private enum SettingsTab { case general, appearance, floating }
    private var floatingStyle: FloatingCenterStyle { .fromStoredValue(floatingCenterStyleRaw) }
    private var floatingContext: FloatingSettingsContext {
        FloatingSettingsContext(layoutMode: layoutMode, displayEnabled: notchDisplayEnabled)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            generalSettings
                .tabItem { Label(appLanguage.localized(chinese: "通用", english: "General"), systemImage: "gearshape") }
                .tag(SettingsTab.general)
            appearanceSettings
                .tabItem { Label(appLanguage.localized(chinese: "外观", english: "Appearance"), systemImage: "paintpalette") }
                .tag(SettingsTab.appearance)
            floatingSettings
                .tabItem { Label(appLanguage.localized(chinese: "浮动横条", english: "Floating Bar"), systemImage: "display") }
                .tag(SettingsTab.floating)
        }
        .padding(16)
        .frame(width: 560, height: 580)
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

    private var generalSettings: some View {
        Form {
            Section {
                launchAtLoginControls
                Picker(appLanguage.localized(chinese: "语言", english: "Language"), selection: appLanguageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                Picker(appLanguage.localized(chinese: "最近任务数量", english: "Number of recent tasks"), selection: recentConversationLimitBinding) {
                    ForEach(RecentConversationLimit.allCases) { limit in
                        Text(limit.title(for: appLanguage)).tag(limit)
                    }
                }
            } header: {
                Text(appLanguage.localized(chinese: "日常使用", english: "Everyday use"))
            } footer: {
                Text(appLanguage.localized(
                    chinese: "将指针移至屏幕顶部可查看最近任务。设为 0 时隐藏列表。",
                    english: "Hover over CodexNotch at the top of the screen to view recent tasks. Set to 0 to hide the list."
                ))
            }

            Section {
                LabeledContent(appLanguage.localized(chinese: "当前版本", english: "Current version"), value: currentVersion.displayValue)
                Button {
                    updater.checkForUpdates()
                } label: {
                    Label(appLanguage.localized(chinese: "检查更新…", english: "Check for Updates…"), systemImage: "arrow.clockwise")
                }
                .disabled(!updater.canCheckForUpdates)
                if let error = updater.startupError {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            } header: {
                Text(appLanguage.localized(chinese: "更新", english: "Updates"))
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var launchAtLoginControls: some View {
        Toggle(
            appLanguage.localized(chinese: "登录时启动", english: "Launch at login"),
            isOn: Binding(get: { launchAtLogin.isRequested }, set: { launchAtLogin.setEnabled($0) })
        )
        .help(appLanguage.localized(chinese: "登录 Mac 时自动启动 CodexNotch。", english: "Automatically launch CodexNotch when you log in to your Mac."))

        if launchAtLogin.status == .requiresApproval {
            Text(appLanguage.localized(chinese: "需在系统设置中允许登录时启动。", english: "Approval in System Settings is required to launch at login."))
                .font(.callout).foregroundStyle(.secondary)
            Button(appLanguage.localized(chinese: "打开登录项设置…", english: "Open Login Items…")) {
                launchAtLogin.openSystemSettings()
            }
        }
        if let error = launchAtLogin.errorMessage {
            Text(appLanguage.localized(chinese: "无法保存自动启动设置：\(error)", english: "Unable to save the launch-at-login setting: \(error)"))
                .font(.callout).foregroundStyle(.red)
            if launchAtLogin.status == .notFound {
                Text(appLanguage.localized(chinese: "请将 CodexNotch 移至“应用程序”文件夹后重新打开。", english: "Move CodexNotch to the Applications folder, then reopen it."))
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var appearanceSettings: some View {
        Form {
            Section {
                Picker(appLanguage.localized(chinese: "额度样式", english: "Quota style"), selection: selectedStyleBinding) {
                    ForEach(QuotaDisplayStyle.allCases) { style in
                        Label(style.title(for: appLanguage), systemImage: style.systemImage).tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
                Picker(appLanguage.localized(chinese: "左侧显示", english: "Left side"), selection: statusIconStyleBinding) {
                    ForEach(StatusIconStyle.allCases) { style in
                        Label {
                            Text(style.title(for: appLanguage))
                        } icon: {
                            StatusMark(style: style, size: 16, tint: .primary)
                        }
                        .tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text(appLanguage.localized(chinese: "顶部显示", english: "Top display"))
            } footer: {
                Text(appLanguage.localized(
                    chinese: "刘海左侧优先显示 5 小时额度。选择“关闭”可减少菜单栏遮挡，额度仍可展开查看。",
                    english: "Five-hour quota takes priority beside the notch. Select Off to reduce overlap with the menu bar. Quota remains available in the expanded card."
                ))
            }

            Section {
                Toggle(appLanguage.localized(chinese: "动画效果", english: "Animations"), isOn: $animationsEnabled)
            } header: {
                Text(appLanguage.localized(chinese: "动画与性能", english: "Animations and performance"))
            } footer: {
                Text(appLanguage.localized(
                    chinese: "关闭动画可减少开销，额度和任务状态照常更新。",
                    english: "Turn off animations to reduce resource use. Quota and task status keep updating."
                ))
            }
        }
        .formStyle(.grouped)
    }

    private var floatingSettings: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label(floatingContext.title(for: appLanguage), systemImage: "info.circle")
                        .font(.headline)
                    Text(floatingContext.explanation(for: appLanguage))
                        .font(.callout).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            Section {
                if selectedTab == .floating {
                    FloatingBarSettingsPreview(
                        style: floatingStyle, customText: floatingCenterText, state: previewState,
                        language: appLanguage, animationsEnabled: animationsEnabled
                    )
                }
                Picker(appLanguage.localized(chinese: "预览状态", english: "Preview state"), selection: $previewState) {
                    ForEach(FloatingPreviewState.allCases) { state in
                        Text(state.title(for: appLanguage)).tag(state)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } header: {
                Text(appLanguage.localized(chinese: "效果预览", english: "Preview"))
            } footer: {
                if !animationsEnabled {
                    Text(appLanguage.localized(chinese: "动画已关闭，可在“外观”中开启。", english: "Animations are off. Enable them in Appearance."))
                }
            }

            Section {
                Picker(appLanguage.localized(chinese: "中间样式", english: "Center style"), selection: Binding(
                    get: { floatingStyle }, set: { floatingCenterStyleRaw = $0.rawValue }
                )) {
                    ForEach(FloatingCenterStyle.allCases) { style in
                        Text(style.title(for: appLanguage)).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if floatingStyle.usesCustomText {
                    TextField(
                        appLanguage.localized(chinese: "自定义文字", english: "Custom text"),
                        text: $floatingCenterText, prompt: Text(FloatingCenterText.defaultText)
                    )
                    .onChange(of: floatingCenterText) { _, value in
                        let limited = String(value.prefix(FloatingCenterText.maximumCharacters))
                        if limited != value { floatingCenterText = limited }
                    }
                }
            } header: {
                Text(appLanguage.localized(chinese: "中间样式", english: "Center style"))
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(floatingStyle.explanation(for: appLanguage))
                    if floatingStyle.usesCustomText {
                        Text(appLanguage.localized(chinese: "最多 12 个字符，留空时显示 Codex。", english: "Up to 12 characters. Leave blank to display Codex."))
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func refreshSystemState() {
        launchAtLogin.refresh()
        layoutMode = NotchScreenMetrics.preferredScreen().map {
            NotchGeometry.layout(metrics: NotchScreenMetrics(screen: $0)).mode
        }
    }

    private var appLanguageBinding: Binding<AppLanguage> {
        Binding(get: { appLanguage }, set: { appLanguageRaw = $0.rawValue })
    }

    private var currentVersion: AppVersion { AppVersion.fromBundle() ?? .zero }
}
