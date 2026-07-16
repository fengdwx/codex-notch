import SwiftUI

final class NotchViewModel: ObservableObject {
    @Published private(set) var state: NotchPresentationState
    @Published private(set) var now: Date

    var onOpenThread: (String) -> Void
    var onActivateChatGPT: () -> Void
    var onHoverChanged: (Bool) -> Void

    init(
        state: NotchPresentationState = .hidden,
        now: Date = .now,
        onOpenThread: @escaping (String) -> Void = { _ in },
        onActivateChatGPT: @escaping () -> Void = {},
        onHoverChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.state = state
        self.now = now
        self.onOpenThread = onOpenThread
        self.onActivateChatGPT = onActivateChatGPT
        self.onHoverChanged = onHoverChanged
    }

    func update(state: NotchPresentationState, now: Date) {
        self.state = state
        self.now = now
    }
}

struct NotchView: View {
    @ObservedObject private var model: NotchViewModel

    init(
        state: NotchPresentationState,
        now: Date = .now,
        onOpenThread: @escaping (String) -> Void = { _ in },
        onActivateChatGPT: @escaping () -> Void = {},
        onHoverChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(
            model: NotchViewModel(
                state: state,
                now: now,
                onOpenThread: onOpenThread,
                onActivateChatGPT: onActivateChatGPT,
                onHoverChanged: onHoverChanged
            )
        )
    }

    init(model: NotchViewModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    var body: some View {
        Group {
            switch model.state {
            case .hidden:
                EmptyView()
            case let .quotaCompact(usage):
                CompactNotchView(
                    icon: .quota,
                    title: "Codex",
                    subtitle: NotchText.quotaSubtitle(usage: usage),
                    usage: usage,
                    action: model.onActivateChatGPT
                )
            case let .workingCompact(primary, count, usage):
                CompactNotchView(
                    icon: .working,
                    title: count > 1 ? "Codex 正在运行 · \(count) 个任务" : "Codex 正在运行",
                    subtitle: NotchText.sessionSubtitle(primary, now: model.now),
                    usage: usage,
                    action: { model.onOpenThread(primary.threadID) }
                )
            case let .completedCompact(session):
                CompactNotchView(
                    icon: .completed,
                    title: "Codex 已完成",
                    subtitle: NotchText.projectName(cwd: session.cwd),
                    usage: nil,
                    action: { model.onOpenThread(session.threadID) }
                )
            case let .expanded(content):
                ExpandedNotchView(
                    content: content,
                    now: model.now,
                    onOpenThread: model.onOpenThread,
                    onActivateChatGPT: model.onActivateChatGPT
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NotchPalette.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NotchPalette.border, lineWidth: 1)
        }
        .onHover(perform: model.onHoverChanged)
    }
}

private struct CompactNotchView: View {
    enum IconKind {
        case quota
        case working
        case completed

        var color: Color {
            switch self {
            case .quota: return NotchPalette.accent
            case .working: return NotchPalette.warning
            case .completed: return NotchPalette.success
            }
        }

        var systemName: String {
            switch self {
            case .quota: return "gauge.with.dots.needle.67percent"
            case .working: return "sparkles"
            case .completed: return "checkmark"
            }
        }
    }

    let icon: IconKind
    let title: String
    let subtitle: String
    let usage: UsageSnapshot?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon.systemName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(icon.color)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(NotchPalette.primaryText)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(NotchPalette.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let usage, !usage.windows.isEmpty {
                    CompactUsageView(usage: usage)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle())
    }
}

private struct CompactUsageView: View {
    let usage: UsageSnapshot

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(usage.windows.prefix(2))) { window in
                Text(NotchText.compactWindow(window))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(NotchPalette.primaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(NotchPalette.chip)
                    .clipShape(Capsule())
            }
        }
    }
}

private struct ExpandedNotchView: View {
    let content: ExpandedContent
    let now: Date
    let onOpenThread: (String) -> Void
    let onActivateChatGPT: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(content.sessions.isEmpty ? "Codex 额度" : "Codex 任务")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(NotchPalette.primaryText)
                    Text(content.sessions.isEmpty ? "当前账号使用情况" : "点击任务可直接跳转")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(NotchPalette.secondaryText)
                }

                Spacer()

                Button("打开 ChatGPT", action: onActivateChatGPT)
                    .buttonStyle(NotchTextButtonStyle())
            }

            if content.sessions.isEmpty {
                UsageDetailView(usage: content.usage)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(content.sessions) { session in
                            SessionRowView(
                                session: session,
                                now: now,
                                action: { onOpenThread(session.threadID) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 111)

                if let usage = content.usage, !usage.windows.isEmpty {
                    UsageSummaryLine(usage: usage)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
    }
}

private struct SessionRowView: View {
    let session: SessionActivity
    let now: Date
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(NotchPalette.warning)
                    .frame(width: 7, height: 7)
                    .shadow(color: NotchPalette.warning.opacity(0.65), radius: 4)

                VStack(alignment: .leading, spacing: 1) {
                    Text(NotchText.projectName(cwd: session.cwd))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(NotchPalette.primaryText)
                        .lineLimit(1)
                    Text(NotchText.sessionSubtitle(session, now: now))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(NotchPalette.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchPalette.secondaryText)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(NotchPalette.row)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle())
    }
}

private struct UsageDetailView: View {
    let usage: UsageSnapshot?

    var body: some View {
        if let usage, !usage.windows.isEmpty {
            VStack(spacing: 7) {
                ForEach(usage.windows) { window in
                    UsageWindowRow(window: window)
                }
                if let credits = usage.resetCreditsAvailable {
                    Text("可重置额度：\(credits)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(NotchPalette.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle")
                Text("额度暂不可用，请稍后重试")
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(NotchPalette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct UsageSummaryLine: View {
    let usage: UsageSnapshot

    var body: some View {
        HStack(spacing: 10) {
            ForEach(usage.windows) { window in
                HStack(spacing: 4) {
                    Text(NotchText.windowLabel(window.kind))
                    Text(NotchText.percent(window.remainingPercent))
                        .foregroundStyle(NotchPalette.primaryText)
                }
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(NotchPalette.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct UsageWindowRow: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(NotchText.windowLabel(window.kind))
                Spacer()
                Text("\(NotchText.percent(window.remainingPercent)) 剩余")
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(NotchPalette.primaryText)

            GeometryReader { proxy in
                Capsule()
                    .fill(NotchPalette.track)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(NotchPalette.accent)
                            .frame(width: proxy.size.width * window.remainingPercent / 100)
                    }
            }
            .frame(height: 5)
        }
    }
}

private enum NotchPalette {
    static let background = Color.black.opacity(0.96)
    static let border = Color.white.opacity(0.1)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.6)
    static let chip = Color.white.opacity(0.13)
    static let row = Color.white.opacity(0.09)
    static let track = Color.white.opacity(0.13)
    static let accent = Color(red: 0.38, green: 0.66, blue: 1.0)
    static let warning = Color(red: 1.0, green: 0.68, blue: 0.28)
    static let success = Color(red: 0.34, green: 0.88, blue: 0.55)
}

private struct NotchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct NotchTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(NotchPalette.accent)
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

enum NotchText {
    static func windowLabel(_ kind: UsageWindowKind) -> String {
        switch kind {
        case let .rolling(hours):
            return "滚动 \(hours)h"
        case .daily:
            return "每日"
        case .weekly:
            return "每周"
        case let .custom(seconds):
            return formatDuration(seconds: seconds)
        }
    }

    static func compactWindow(_ window: UsageWindow) -> String {
        "\(windowLabel(window.kind)) \(percent(window.remainingPercent))"
    }

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    static func quotaSubtitle(usage: UsageSnapshot?) -> String {
        guard let usage, let window = usage.windows.first else {
            return "额度暂不可用"
        }
        return "\(windowLabel(window.kind))剩余 \(percent(window.remainingPercent))"
    }

    static func sessionSubtitle(_ session: SessionActivity, now: Date) -> String {
        "\(projectName(cwd: session.cwd)) · 已运行 \(formatDuration(seconds: max(0, now.timeIntervalSince(session.startedAt))))"
    }

    static func projectName(cwd: String?) -> String {
        guard let cwd, !cwd.isEmpty else { return "未命名任务" }
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? cwd : name
    }

    static func formatDuration(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainingSeconds = total % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private static func formatDuration(seconds: Int) -> String {
        formatDuration(seconds: TimeInterval(seconds))
    }
}
