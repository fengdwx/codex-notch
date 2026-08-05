import SwiftUI

struct NotchSettingsView: View {
    @AppStorage(QuotaDisplayStyle.storageKey)
    private var quotaDisplayStyleRaw = QuotaDisplayStyle.defaultStyle.rawValue
    @AppStorage(RecentConversationLimit.storageKey)
    private var recentConversationLimitRaw = RecentConversationLimit.defaultLimit.rawValue
    @AppStorage(AppLanguage.storageKey)
    private var appLanguageRaw = AppLanguage.defaultLanguage.rawValue
    @AppStorage(AppAnimationPreference.storageKey)
    private var animationsEnabled = AppAnimationPreference.defaultEnabled
    @State private var updateState: UpdatePresentationState = .idle
    @State private var isCheckingForUpdates = false

    private let updateChecker = AppUpdateChecker()

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
                    HStack {
                        Button {
                            checkForUpdates()
                        } label: {
                            Label(
                                appLanguage.localized(chinese: "检查更新", english: "Check for Updates"),
                                systemImage: "arrow.clockwise"
                            )
                        }
                        .disabled(isCheckingForUpdates)

                        if isCheckingForUpdates {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    Text(updateStatusText)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if case let .updateAvailable(release) = updateState {
                        Link(destination: release.url) {
                            Label(
                                appLanguage.localized(chinese: "打开下载页", english: "Open download page"),
                                systemImage: "arrow.up.right.square"
                            )
                        }
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

    private func checkForUpdates() {
        guard !isCheckingForUpdates else { return }

        isCheckingForUpdates = true
        updateState = .checking

        Task { @MainActor in
            defer { isCheckingForUpdates = false }
            do {
                switch try await updateChecker.check() {
                case let .upToDate(current):
                    updateState = .upToDate(current)
                case let .updateAvailable(_, release):
                    updateState = .updateAvailable(release)
                }
            } catch {
                updateState = .failed
            }
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

    private var updateStatusText: String {
        switch updateState {
        case .idle:
            return appLanguage.localized(
                chinese: "当前版本 \(currentVersion.displayValue)。点击检查 GitHub 上的最新正式版本。",
                english: "Current version \(currentVersion.displayValue). Check GitHub for the latest stable release."
            )
        case .checking:
            return appLanguage.localized(chinese: "正在检查…", english: "Checking…")
        case let .upToDate(version):
            return appLanguage.localized(
                chinese: "已是最新版本 \(version.displayValue)。",
                english: "You're up to date (\(version.displayValue))."
            )
        case let .updateAvailable(release):
            return appLanguage.localized(
                chinese: "发现新版本 \(release.version.displayValue)。",
                english: "Version \(release.version.displayValue) is available."
            )
        case .failed:
            return appLanguage.localized(
                chinese: "检查更新失败，请稍后重试。",
                english: "Couldn't check for updates. Try again later."
            )
        }
    }

    private var currentVersion: AppVersion {
        AppVersion.fromBundle() ?? .zero
    }
}

private enum UpdatePresentationState {
    case idle
    case checking
    case upToDate(AppVersion)
    case updateAvailable(UpdateRelease)
    case failed
}
