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

    var body: some View {
        Form {
            Section {
                Picker(
                    appLanguage.localized(chinese: "额度指示器", english: "Quota indicator"),
                    selection: selectedStyleBinding
                ) {
                    ForEach(QuotaDisplayStyle.allCases) { style in
                        Label(
                            style.title(for: appLanguage),
                            systemImage: style.systemImage
                        )
                            .tag(style)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(selectedStyle.subtitle(for: appLanguage))
                    .font(.callout)
                    .foregroundStyle(.secondary)

            } header: {
                Text(appLanguage.localized(chinese: "额度指示器", english: "Quota indicator"))
            }

            Section {
                Picker(
                    appLanguage.localized(chinese: "状态图标", english: "Status icon"),
                    selection: statusIconStyleBinding
                ) {
                    ForEach(StatusIconStyle.allCases) { style in
                        Label {
                            Text(style.title)
                        } icon: {
                            StatusMark(style: style, size: 16, tint: .primary)
                        }
                        .tag(style)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(appLanguage.localized(
                    chinese: "切换状态图标的外观。有五小时额度时，左侧仍优先显示额度。",
                    english: "Choose the status mark. When five-hour quota is available, it keeps the left lane."
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
            } header: {
                Text(appLanguage.localized(chinese: "状态图标", english: "Status icon"))
            }

            Section {
                Picker(
                    appLanguage.localized(chinese: "显示样式", english: "Style"),
                    selection: Binding(
                        get: { FloatingCenterStyle.fromStoredValue(floatingCenterStyleRaw) },
                        set: { floatingCenterStyleRaw = $0.rawValue }
                    )
                ) {
                    ForEach(FloatingCenterStyle.allCases) { style in
                        Text(style.title(for: appLanguage)).tag(style)
                    }
                }
                .pickerStyle(.menu)

                TextField(
                    appLanguage.localized(chinese: "自定义文字", english: "Custom text"),
                    text: $floatingCenterText,
                    prompt: Text(FloatingCenterText.defaultText)
                )
                .onChange(of: floatingCenterText) { _, value in
                    let limited = String(value.prefix(FloatingCenterText.maximumCharacters))
                    if limited != value { floatingCenterText = limited }
                }

                Text(appLanguage.localized(
                    chinese: "最多 12 个字符，留空显示 Codex。适用于无刘海或镜像屏幕的中间区域；计时对应当前主任务，空闲或完成后显示签名。个人签名在卡片收起时持续缓慢扫光；轨道和流光仅在任务运行时播放。",
                    english: "Up to 12 characters; blank uses Codex. Applies to the center of floating bars on displays without a notch, including mirrors. The timer follows the primary task and returns to your signature when idle or complete. Personal signatures shimmer slowly while the card is collapsed; orbit and flow animate only while a task is running."
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
            } header: {
                Text(appLanguage.localized(chinese: "浮动横条中间区域", english: "Floating bar center"))
            }

            Section {
                Toggle(
                    appLanguage.localized(chinese: "动画效果", english: "Animations"),
                    isOn: $animationsEnabled
                )

                Text(
                    appLanguage.localized(
                        chinese: "关闭后停止持续转动、波浪、完成特效和界面过渡，但保留运行中与已完成的静态提示。",
                        english: "Turn off continuous quota motion, completion effects, and interface transitions while keeping static running and completed indicators."
                    )
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            } header: {
                Text(appLanguage.localized(chinese: "动效", english: "Motion"))
            }

            Section {
                Picker(
                    appLanguage.localized(chinese: "最近聊天条数", english: "Recent conversations"),
                    selection: recentConversationLimitBinding
                ) {
                    ForEach(RecentConversationLimit.allCases) { limit in
                        Text(limit.title(for: appLanguage))
                            .tag(limit)
                    }
                }
                .pickerStyle(.menu)

                Text(recentConversationDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text(appLanguage.localized(chinese: "展开卡片", english: "Expanded card"))
            }

            Section {
                Picker(
                    appLanguage.localized(chinese: "语言", english: "Language"),
                    selection: appLanguageBinding
                ) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title)
                            .tag(language)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(appLanguage.localized(chinese: "语言", english: "Language"))
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        updater.checkForUpdates()
                    } label: {
                        Label(
                            appLanguage.localized(chinese: "检查更新", english: "Check for Updates"),
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .disabled(!updater.canCheckForUpdates)

                    Text(appLanguage.localized(
                        chinese: "当前版本 \(currentVersion.displayValue)。发现新版后可直接下载、安装并重启。",
                        english: "Current version \(currentVersion.displayValue). Download, install, and relaunch here when an update is available."
                    ))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                    if let error = updater.startupError {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(appLanguage.localized(chinese: "更新", english: "Updates"))
            }

            Section {
                Label(
                    appLanguage.localized(
                        chinese: "设置会立即应用到刘海，不需要重启。展开面板右下角和右键刘海都可以打开本窗口。",
                        english: "Settings apply to the notch immediately; no restart is required. Open this window from the expanded panel or the notch context menu."
                    ),
                    systemImage: "info.circle"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 430)
        .padding(.vertical, 12)
        .onAppear {
            SettingsWindowPresenter.bringToFront()
        }
    }

    private var appLanguageBinding: Binding<AppLanguage> {
        Binding(
            get: { appLanguage },
            set: { appLanguageRaw = $0.rawValue }
        )
    }

    private var recentConversationDescription: String {
        if recentConversationLimit == .none {
            return appLanguage.localized(
                chinese: "不显示最近聊天；展开卡片仍会保留额度和任务状态。",
                english: "Hide recent conversations; quota and task status remain available in the expanded card."
            )
        }
        return appLanguage.localized(
            chinese: "展开卡片最多显示 \(recentConversationLimit.rawValue) 条最近聊天，并从刘海向下延展。",
            english: "The expanded card shows up to \(recentConversationLimit.rawValue) recent conversations and grows downward from the notch."
        )
    }

    private var currentVersion: AppVersion {
        AppVersion.fromBundle() ?? .zero
    }
}
