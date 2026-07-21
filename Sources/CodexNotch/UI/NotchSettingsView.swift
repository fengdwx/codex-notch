import SwiftUI

struct NotchSettingsView: View {
    @AppStorage(QuotaDisplayStyle.storageKey)
    private var quotaDisplayStyleRaw = QuotaDisplayStyle.defaultStyle.rawValue
    @AppStorage(RecentConversationLimit.storageKey)
    private var recentConversationLimitRaw = RecentConversationLimit.defaultLimit.rawValue
    @AppStorage(AppLanguage.storageKey)
    private var appLanguageRaw = AppLanguage.defaultLanguage.rawValue

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
                Text(appLanguage.localized(chinese: "刘海显示", english: "Notch display"))
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
}
