import AppKit
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
    @State private var isPointerInside = false

    private var isExpanded: Bool {
        if case .expanded = model.state { return true }
        return false
    }

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
                    isHovered: isPointerInside,
                    action: model.onActivateChatGPT
                )
            case let .workingCompact(primary, count, usage):
                CompactNotchView(
                    icon: .working,
                    title: "Codex 运行中",
                    subtitle: count > 1
                        ? "\(count) 个任务"
                        : "已运行 \(NotchText.formatDuration(seconds: max(0, model.now.timeIntervalSince(primary.startedAt))))",
                    usage: usage,
                    isHovered: isPointerInside,
                    action: { model.onOpenThread(primary.threadID) }
                )
            case let .completedCompact(session):
                CompactNotchView(
                    icon: .completed,
                    title: "Codex 已完成",
                    subtitle: NotchText.projectName(cwd: session.cwd),
                    usage: nil,
                    isHovered: isPointerInside,
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
        .clipShape(
            NotchAttachedShape(
                shoulderDepth: 6,
                bottomRadius: isExpanded ? 22 : 14
            )
        )
        .shadow(
            color: isExpanded ? Color.black.opacity(0.48) : Color.clear,
            radius: 12,
            y: 6
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                isPointerInside = hovering
            }
            model.onHoverChanged(hovering)
        }
    }
}

private struct NotchAttachedShape: Shape {
    var shoulderDepth: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(shoulderDepth, bottomRadius) }
        set {
            shoulderDepth = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let shoulder = min(max(0, shoulderDepth), rect.height / 2)
        let radius = min(
            max(0, bottomRadius),
            max(0, rect.height - shoulder),
            max(0, rect.width / 2 - shoulder)
        )
        let curve = CGFloat(0.55)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX - shoulder, y: rect.minY + shoulder),
            control1: CGPoint(x: rect.maxX - shoulder * curve, y: rect.minY),
            control2: CGPoint(x: rect.maxX - shoulder, y: rect.minY + shoulder * curve)
        )
        path.addLine(to: CGPoint(x: rect.maxX - shoulder, y: rect.maxY - radius))
        path.addCurve(
            to: CGPoint(x: rect.maxX - shoulder - radius, y: rect.maxY),
            control1: CGPoint(x: rect.maxX - shoulder, y: rect.maxY - radius * curve),
            control2: CGPoint(x: rect.maxX - shoulder - radius * curve, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + shoulder + radius, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX + shoulder, y: rect.maxY - radius),
            control1: CGPoint(x: rect.minX + shoulder + radius * curve, y: rect.maxY),
            control2: CGPoint(x: rect.minX + shoulder, y: rect.maxY - radius * curve)
        )
        path.addLine(to: CGPoint(x: rect.minX + shoulder, y: rect.minY + shoulder))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control1: CGPoint(x: rect.minX + shoulder, y: rect.minY + shoulder * curve),
            control2: CGPoint(x: rect.minX + shoulder * curve, y: rect.minY)
        )
        path.closeSubpath()
        return path
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

        var fallbackSystemName: String {
            switch self {
            case .quota: return "sparkles"
            case .working: return "sparkles"
            case .completed: return "checkmark.circle.fill"
            }
        }
    }

    let icon: IconKind
    let title: String
    let subtitle: String
    let usage: UsageSnapshot?
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    CompactAppIconView(status: icon, isHovered: isHovered)
                }
                .frame(width: 38)

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    switch icon {
                    case .completed:
                        CompactCompletionView()
                    case .quota, .working:
                        CompactQuotaView(window: usage?.windows.first, isHovered: isHovered)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 38)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle())
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [title, subtitle]
        if let usage, !usage.windows.isEmpty {
            parts.append(NotchText.quotaSubtitle(usage: usage))
        }
        return parts.joined(separator: "，")
    }
}

private struct CompactAppIconView: View {
    let status: CompactNotchView.IconKind
    let isHovered: Bool

    var body: some View {
        ZStack {
            if let image = ChatGPTIconAsset.templateImage {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .foregroundStyle(NotchPalette.primaryText.opacity(0.92))
            } else {
                Image(systemName: status.fallbackSystemName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchPalette.primaryText.opacity(0.92))
            }
        }
        .frame(width: isHovered ? 17.5 : 16.5, height: isHovered ? 17.5 : 16.5)
        .offset(x: 2)
        .frame(width: 28, height: 32)
        .accessibilityHidden(true)
    }
}

private struct CompactQuotaView: View {
    let window: UsageWindow?
    let isHovered: Bool

    private var remainingPercent: Double {
        window?.remainingPercent ?? 0
    }

    private var progressColor: Color {
        if remainingPercent <= 20 { return NotchPalette.danger }
        if remainingPercent <= 50 { return NotchPalette.warning }
        return NotchPalette.accent
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(NotchPalette.track, lineWidth: 1.5)

            if window != nil {
                Circle()
                    .trim(from: 0, to: remainingPercent / 100)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            Text(window.map { NotchText.percent($0.remainingPercent) } ?? "—")
                .font(.system(size: window == nil ? 8 : 6.2, weight: .bold, design: .rounded))
                .foregroundStyle(window == nil ? NotchPalette.secondaryText : NotchPalette.primaryText)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(width: isHovered ? 22 : 20, height: isHovered ? 22 : 20)
        .offset(x: -2)
        .frame(width: 28, height: 32)
        .accessibilityHidden(true)
    }
}

private struct CompactCompletionView: View {
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(NotchPalette.success)
            .offset(x: -2)
            .frame(width: 28, height: 32)
            .accessibilityHidden(true)
    }
}

private enum ChatGPTIconAsset {
    static let templateImage: NSImage? = {
        let workspace = NSWorkspace.shared
        guard let appURL = workspace.urlForApplication(
            withBundleIdentifier: AppIdentity.chatGPTCodexBundleIdentifier
        ) else {
            return nil
        }
        guard let resourceURL = Bundle(url: appURL)?.url(
            forResource: "chatgptTemplate",
            withExtension: "png"
        ) else {
            return nil
        }
        return NSImage(contentsOf: resourceURL)
    }()
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
        .padding(.top, 40)
        .padding(.bottom, 10)
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
                Text("已用 \(NotchText.percent(window.usedPercent)) · 剩余 \(NotchText.percent(window.remainingPercent))")
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
    static let background = Color.black
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.6)
    static let chip = Color.white.opacity(0.13)
    static let row = Color.white.opacity(0.09)
    static let track = Color.white.opacity(0.13)
    static let accent = Color(red: 0.38, green: 0.66, blue: 1.0)
    static let warning = Color(red: 1.0, green: 0.68, blue: 0.28)
    static let success = Color(red: 0.34, green: 0.88, blue: 0.55)
    static let danger = Color(red: 1.0, green: 0.35, blue: 0.35)
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
        "\(windowLabel(window.kind))余\(percent(window.remainingPercent))"
    }

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    static func quotaSubtitle(usage: UsageSnapshot?) -> String {
        guard let usage, let window = usage.windows.first else {
            return "额度暂不可用"
        }
        return "\(windowLabel(window.kind))剩余 \(percent(window.remainingPercent)) · 已用 \(percent(window.usedPercent))"
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
