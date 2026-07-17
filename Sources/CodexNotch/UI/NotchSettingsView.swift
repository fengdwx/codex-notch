import SwiftUI

struct NotchSettingsView: View {
    @AppStorage(QuotaDisplayStyle.storageKey)
    private var quotaDisplayStyleRaw = QuotaDisplayStyle.defaultStyle.rawValue
    @AppStorage(RecentConversationLimit.storageKey)
    private var recentConversationLimitRaw = RecentConversationLimit.defaultLimit.rawValue

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
                Picker("额度指示器", selection: selectedStyleBinding) {
                    ForEach(QuotaDisplayStyle.allCases) { style in
                        Label(style.title, systemImage: style.systemImage)
                            .tag(style)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(selectedStyle.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("数字固定显示在指标内；波浪球只给字形加细描边，不遮挡液面。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("刘海显示")
            }

            Section {
                Picker("最近聊天条数", selection: recentConversationLimitBinding) {
                    ForEach(RecentConversationLimit.allCases) { limit in
                        Text(limit.title)
                            .tag(limit)
                    }
                }
                .pickerStyle(.menu)

                Text("展开卡片最多显示 \(recentConversationLimit.rawValue) 条最近聊天，并从刘海向下延展。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("展开卡片")
            }

            Section {
                Label(
                    "设置会立即应用到刘海，不需要重启。展开面板右下角和右键刘海都可以打开本窗口。",
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
}
