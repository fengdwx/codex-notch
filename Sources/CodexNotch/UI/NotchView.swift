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
                    onOpenThread: model.onOpenThread
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
    enum IconKind: Equatable {
        case quota
        case working
        case completed

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
                    CompactAppIconView(status: icon)
                }
                .frame(width: 38)

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    switch icon {
                    case .completed:
                        CompactCompletionView()
                    case .quota, .working:
                        CompactQuotaView(usage: usage, isHovered: isHovered)
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

    var body: some View {
        Group {
            if status == .working {
                RunningChatGPTIcon(size: 18)
            } else {
                ChatGPTMark(size: 18, fallbackSystemName: status.fallbackSystemName)
            }
        }
        .offset(x: 2)
        .frame(width: 28, height: 32)
        .accessibilityHidden(true)
    }
}

private struct CompactQuotaView: View {
    let usage: UsageSnapshot?
    let isHovered: Bool

    var body: some View {
        WeeklyQuotaRing(
            usage: usage,
            diameter: isHovered ? 22 : 20,
            lineWidth: 1.5,
            fontSize: 6.2
        )
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
            forResource: "chatgptTemplate@2x",
            withExtension: "png"
        ), let image = NSImage(contentsOf: resourceURL) else {
            return nil
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()
}

private struct ChatGPTMark: View {
    let size: CGFloat
    var fallbackSystemName = "sparkles"

    var body: some View {
        Group {
            if let image = ChatGPTIconAsset.templateImage {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .foregroundStyle(NotchPalette.primaryText.opacity(0.96))
            } else {
                Image(systemName: fallbackSystemName)
                    .font(.system(size: size * 0.72, weight: .semibold))
                    .foregroundStyle(NotchPalette.primaryText.opacity(0.96))
            }
        }
        .frame(width: size, height: size)
    }
}

private struct RunningChatGPTIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    let size: CGFloat

    var body: some View {
        ZStack {
            if !reduceMotion {
                Circle()
                    .stroke(NotchPalette.accent.opacity(isPulsing ? 0 : 0.55), lineWidth: 1)
                    .frame(width: size + 7, height: size + 7)
                    .scaleEffect(isPulsing ? 1.22 : 0.78)
                    .opacity(isPulsing ? 0 : 1)
            }

            ChatGPTMark(size: size)
        }
        .frame(width: size + 8, height: size + 8)
        .onAppear {
            guard !reduceMotion else { return }
            isPulsing = true
        }
        .animation(
            reduceMotion
                ? nil
                : .easeOut(duration: 1.45).repeatForever(autoreverses: false),
            value: isPulsing
        )
    }
}

private struct WeeklyQuotaRing: View {
    let usage: UsageSnapshot?
    let diameter: CGFloat
    let lineWidth: CGFloat
    let fontSize: CGFloat

    private var window: UsageWindow? {
        usage?.weeklyWindow
    }

    private var remainingPercent: Double {
        window?.remainingPercent ?? 0
    }

    private var level: WeeklyQuotaLevel {
        WeeklyQuotaLevel(weeklyWindow: window)
    }

    private var progressColor: Color {
        switch level {
        case .healthy:
            return NotchPalette.success
        case .critical:
            return NotchPalette.danger
        case .unavailable:
            return NotchPalette.secondaryText
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(NotchPalette.track, lineWidth: lineWidth)

            if window != nil {
                Circle()
                    .trim(from: 0, to: remainingPercent / 100)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            Text(window.map { NotchText.percent($0.remainingPercent) } ?? "—")
                .font(.system(
                    size: window == nil ? fontSize + 1 : fontSize,
                    weight: .bold,
                    design: .rounded
                ))
                .foregroundStyle(
                    window == nil ? NotchPalette.secondaryText : NotchPalette.primaryText
                )
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(width: diameter, height: diameter)
        .animation(.easeInOut(duration: 0.28), value: remainingPercent)
    }
}

private struct ExpandedNotchView: View {
    let content: ExpandedContent
    let now: Date
    let onOpenThread: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ExpandedRunningHeader(sessions: content.sessions, now: now)

            HStack(spacing: 7) {
                ForEach(Array(content.sessions.prefix(2))) { session in
                    SessionCardView(
                        session: session,
                        now: now,
                        action: { onOpenThread(session.threadID) }
                    )
                }
            }
            .frame(height: 46)

            WeeklyQuotaCard(usage: content.usage, now: now)
        }
        .padding(.horizontal, 12)
        .padding(.top, 38)
        .padding(.bottom, 10)
    }
}

private struct ExpandedRunningHeader: View {
    let sessions: [SessionActivity]
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            RunningChatGPTIcon(size: 16)

            Text(sessions.count > 1 ? "\(sessions.count) 个任务运行中" : "Codex 正在运行")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(NotchPalette.primaryText)

            Spacer(minLength: 8)

            if let primary = sessions.first {
                Text(NotchText.formatDuration(
                    seconds: max(0, now.timeIntervalSince(primary.startedAt))
                ))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(NotchPalette.secondaryText)
                .monospacedDigit()
            }
        }
        .frame(height: 24)
    }
}

private struct SessionCardView: View {
    let session: SessionActivity
    let now: Date
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Circle()
                    .fill(NotchPalette.success)
                    .frame(width: 6, height: 6)
                    .shadow(color: NotchPalette.success.opacity(0.55), radius: 3)

                VStack(alignment: .leading, spacing: 1) {
                    Text(NotchText.projectName(cwd: session.cwd))
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(NotchPalette.primaryText)
                        .lineLimit(1)
                    Text("运行 \(NotchText.formatDuration(seconds: max(0, now.timeIntervalSince(session.startedAt))))")
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        .foregroundStyle(NotchPalette.secondaryText)
                        .lineLimit(1)
                        .monospacedDigit()
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(NotchPalette.secondaryText)
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NotchPalette.row)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(NotchPalette.border, lineWidth: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle())
    }
}

private struct WeeklyQuotaCard: View {
    let usage: UsageSnapshot?
    let now: Date

    private var window: UsageWindow? {
        usage?.weeklyWindow
    }

    var body: some View {
        HStack(spacing: 10) {
            WeeklyQuotaRing(
                usage: usage,
                diameter: 38,
                lineWidth: 2.5,
                fontSize: 9
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("本周额度")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchPalette.primaryText)

                Text(resetTimestampText)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(NotchPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("距离重置")
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(NotchPalette.secondaryText)

                Text(resetCountdownText)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(NotchPalette.primaryText)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
        .background(NotchPalette.row)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(NotchPalette.border, lineWidth: 0.5)
        }
    }

    private var resetTimestampText: String {
        guard let resetAt = window?.resetAt else {
            return "重置时间暂不可用"
        }
        return "重置于 \(NotchText.resetTimestamp(resetAt))"
    }

    private var resetCountdownText: String {
        guard let resetAt = window?.resetAt else {
            return "--:--:--"
        }
        return NotchText.resetCountdown(resetAt: resetAt, now: now)
    }
}

private enum NotchPalette {
    static let background = Color.black
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.6)
    static let chip = Color.white.opacity(0.13)
    static let row = Color.white.opacity(0.09)
    static let border = Color.white.opacity(0.1)
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

    static func resetTimestamp(
        _ date: Date,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    static func resetCountdown(resetAt: Date, now: Date) -> String {
        let total = max(0, Int(resetAt.timeIntervalSince(now).rounded(.down)))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60

        if days > 0 {
            return String(format: "%d天 %02d:%02d:%02d", days, hours, minutes, seconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private static func formatDuration(seconds: Int) -> String {
        formatDuration(seconds: TimeInterval(seconds))
    }
}
