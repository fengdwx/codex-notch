import AppKit
import SwiftUI

final class NotchViewModel: ObservableObject {
    @Published private(set) var state: NotchPresentationState
    @Published private(set) var now: Date
    @Published private(set) var cameraSafeAreaInset: CGFloat

    var onOpenThread: (String) -> Void
    var onActivateChatGPT: () -> Void
    var onHoverChanged: (Bool) -> Void

    init(
        state: NotchPresentationState = .hidden,
        now: Date = .now,
        cameraSafeAreaInset: CGFloat = 0,
        onOpenThread: @escaping (String) -> Void = { _ in },
        onActivateChatGPT: @escaping () -> Void = {},
        onHoverChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.state = state
        self.now = now
        self.cameraSafeAreaInset = cameraSafeAreaInset
        self.onOpenThread = onOpenThread
        self.onActivateChatGPT = onActivateChatGPT
        self.onHoverChanged = onHoverChanged
    }

    func update(
        state: NotchPresentationState,
        now: Date,
        cameraSafeAreaInset: CGFloat = 0
    ) {
        self.state = state
        self.now = now
        self.cameraSafeAreaInset = cameraSafeAreaInset
    }
}

struct NotchView: View {
    @ObservedObject private var model: NotchViewModel
    @AppStorage(QuotaDisplayStyle.storageKey)
    private var quotaDisplayStyleRaw = QuotaDisplayStyle.defaultStyle.rawValue
    @State private var isPointerInside = false

    private var quotaDisplayStyle: QuotaDisplayStyle {
        QuotaDisplayStyle.fromStoredValue(quotaDisplayStyleRaw)
    }

    private var isExpanded: Bool {
        if case .expanded = model.state { return true }
        return false
    }

    private var isHidden: Bool {
        model.state == .hidden
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
                Color.clear
            case let .quotaCompact(usage):
                CompactNotchView(
                    icon: .quota,
                    title: "Codex",
                    subtitle: NotchText.quotaSubtitle(usage: usage),
                    usage: usage,
                    quotaDisplayStyle: quotaDisplayStyle,
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
                    quotaDisplayStyle: quotaDisplayStyle,
                    isHovered: isPointerInside,
                    action: { model.onOpenThread(primary.threadID) }
                )
            case let .completedCompact(session, usage):
                CompactNotchView(
                    icon: .completed,
                    title: "Codex 已完成",
                    subtitle: NotchText.projectName(cwd: session.cwd),
                    usage: usage,
                    quotaDisplayStyle: quotaDisplayStyle,
                    isHovered: isPointerInside,
                    action: { model.onOpenThread(session.threadID) }
                )
            case let .expanded(content):
                ExpandedNotchView(
                    content: content,
                    now: model.now,
                    cameraSafeAreaInset: model.cameraSafeAreaInset,
                    onOpenThread: model.onOpenThread
                )
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .background(isHidden ? Color.clear : NotchPalette.background)
        .clipShape(
            NotchAttachedShape(
                shoulderDepth: 6,
                bottomRadius: isExpanded ? 22 : 14
            )
        )
        .overlay {
            NotchAttachedShape(
                shoulderDepth: 6,
                bottomRadius: isExpanded ? 22 : 14
            )
            .stroke(
                isExpanded ? NotchPalette.border : Color.clear,
                lineWidth: 0.5
            )
        }
        .animation(.easeInOut(duration: 0.24), value: isExpanded)
        .onHover { hovering in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                isPointerInside = hovering
            }
            model.onHoverChanged(hovering)
        }
        .contextMenu {
            SettingsLink {
                Label("设置…", systemImage: "gearshape")
            }
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

        var quotaActivity: QuotaRingActivity {
            switch self {
            case .quota: return .idle
            case .working: return .running
            case .completed: return .completed
            }
        }
    }

    let icon: IconKind
    let title: String
    let subtitle: String
    let usage: UsageSnapshot?
    let quotaDisplayStyle: QuotaDisplayStyle
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                CompactAppIconView(status: icon)
                    .frame(
                        width: NotchCompactLayout.sideWingWidth,
                        height: NotchCompactLayout.height
                    )

                Spacer(minLength: 0)

                // Keep the complete quota control centered in the right safe
                // area. Its number is always inside the indicator, so neither
                // display style shifts visual weight toward the camera cutout.
                CompactQuotaView(
                    usage: usage,
                    activity: icon.quotaActivity,
                    style: quotaDisplayStyle,
                    isHovered: isHovered
                )
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
            switch status {
            case .working:
                RunningChatGPTIcon(size: 18)
            case .completed:
                CompletedChatGPTIcon(size: 18)
            case .quota:
                ChatGPTMark(size: 18, fallbackSystemName: status.fallbackSystemName)
            }
        }
        .frame(width: 28, height: NotchCompactLayout.height)
        .accessibilityHidden(true)
    }
}

private struct CompactQuotaView: View {
    let usage: UsageSnapshot?
    let activity: QuotaRingActivity
    let style: QuotaDisplayStyle
    let isHovered: Bool

    private var indicatorDiameter: CGFloat {
        isHovered ? 26 : 24
    }

    var body: some View {
        quotaIndicator
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(
                width: NotchCompactLayout.sideWingWidth,
                height: NotchCompactLayout.height,
                alignment: .center
            )
            .accessibilityHidden(true)
    }

    private var quotaIndicator: some View {
        QuotaIndicatorView(
            style: style,
            usage: usage,
            activity: activity,
            diameter: indicatorDiameter,
            lineWidth: 1.75,
            fontSize: 10
        )
    }
}

private enum QuotaRingActivity: Equatable {
    case idle
    case running
    case completed
}

private struct CompletedChatGPTIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasSettled = false

    let size: CGFloat

    var body: some View {
        ZStack {
            if !reduceMotion {
                Circle()
                    .stroke(NotchPalette.success.opacity(hasSettled ? 0 : 0.7), lineWidth: 1)
                    .frame(width: size + 8, height: size + 8)
                    .scaleEffect(hasSettled ? 1.18 : 0.78)
            }

            ChatGPTMark(size: size)

            Image(systemName: "checkmark")
                .font(.system(size: 5.5, weight: .black))
                .foregroundStyle(Color.black)
                .frame(width: 9, height: 9)
                .background(NotchPalette.success, in: Circle())
                .offset(x: 7, y: 7)
        }
        .frame(width: size + 8, height: size + 8)
        .onAppear {
            guard !reduceMotion else { return }
            hasSettled = true
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.48),
            value: hasSettled
        )
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
                    .stroke(NotchPalette.accent.opacity(0.28), lineWidth: 1)
                    .frame(width: size + 7, height: size + 7)
                    .scaleEffect(1.04)

                Circle()
                    .stroke(NotchPalette.accent.opacity(isPulsing ? 0 : 0.92), lineWidth: 1.35)
                    .frame(width: size + 10, height: size + 10)
                    .scaleEffect(isPulsing ? 1.34 : 0.68)
                    .opacity(isPulsing ? 0 : 1)
                    .shadow(color: NotchPalette.accent.opacity(0.46), radius: 2)
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
                : .easeOut(duration: 1.05).repeatForever(autoreverses: false),
            value: isPulsing
        )
    }
}

private struct QuotaIndicatorView: View {
    let style: QuotaDisplayStyle
    let usage: UsageSnapshot?
    let activity: QuotaRingActivity
    let diameter: CGFloat
    let lineWidth: CGFloat
    let fontSize: CGFloat

    var body: some View {
        switch style {
        case .clockwiseRing:
            WeeklyQuotaRing(
                style: style,
                usage: usage,
                activity: activity,
                diameter: diameter,
                lineWidth: lineWidth,
                fontSize: fontSize
            )
        case .waveBall:
            QuotaWaveBall(
                usage: usage,
                activity: activity,
                diameter: diameter,
                lineWidth: lineWidth,
                fontSize: fontSize
            )
        }
    }
}

private struct QuotaValueText: View {
    let value: String
    let isAvailable: Bool
    let fontSize: CGFloat

    var body: some View {
        Text(value)
            .font(.system(
                size: isAvailable ? fontSize : fontSize + 1,
                weight: .bold,
                design: .rounded
            ))
            .foregroundStyle(isAvailable ? NotchPalette.primaryText : NotchPalette.secondaryText)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .shadow(
                color: .black.opacity(isAvailable ? 0.9 : 0.45),
                radius: 1.15,
                x: 0,
                y: 0.4
            )
    }
}

private struct QuotaValueLens: View {
    let value: String
    let isAvailable: Bool
    let diameter: CGFloat
    let fontSize: CGFloat

    private var lensWidth: CGFloat {
        let textWidth = fontSize * CGFloat(value.count) * 0.57 + 5
        return min(diameter - 4, max(fontSize * 1.45, textWidth))
    }

    private var lensHeight: CGFloat {
        min(diameter - 8, max(fontSize * 1.35, 13))
    }

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.black.opacity(isAvailable ? 0.7 : 0.46))
                .overlay {
                    Capsule()
                        .stroke(
                            Color.white.opacity(isAvailable ? 0.17 : 0.1),
                            lineWidth: 0.55
                        )
                }
                .shadow(color: .black.opacity(0.46), radius: 1.3, x: 0, y: 0.6)

            QuotaValueText(
                value: value,
                isAvailable: isAvailable,
                fontSize: fontSize
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 1)
        }
        .frame(width: lensWidth, height: lensHeight)
        .accessibilityHidden(true)
    }
}

private struct QuotaWaveBall: View {
    let usage: UsageSnapshot?
    let activity: QuotaRingActivity
    let diameter: CGFloat
    let lineWidth: CGFloat
    let fontSize: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedProgress: CGFloat = 0
    @State private var completionPulse = false

    private var window: UsageWindow? {
        usage?.weeklyWindow
    }

    private var remainingPercent: Double {
        window?.remainingPercent ?? 0
    }

    private var targetProgress: CGFloat {
        CGFloat(min(max(remainingPercent, 0), 100) / 100)
    }

    private var progressColor: Color {
        guard window != nil else { return NotchPalette.secondaryText }
        return QuotaColorScale.color(for: remainingPercent)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(NotchPalette.track)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                QuotaWaveShape(
                    fillProgress: displayedProgress,
                    phase: reduceMotion
                        ? 0
                        : context.date.timeIntervalSinceReferenceDate * waveSpeed
                )
                .fill(progressColor)
                .clipShape(Circle())
            }

            Circle()
                .stroke(NotchPalette.border, lineWidth: lineWidth)

            if activity == .completed, !reduceMotion {
                Circle()
                    .stroke(
                        progressColor.opacity(completionPulse ? 0 : 0.7),
                        lineWidth: 1
                    )
                    .scaleEffect(completionPulse ? 1.32 : 0.84)
                    .animation(.easeOut(duration: 0.5), value: completionPulse)
            }

            // The liquid moves only behind this stable, dark lens. It keeps
            // the percentage readable while preserving the solid-ball shape.
            QuotaValueLens(
                value: window.map { NotchText.quotaNumber($0.remainingPercent) } ?? "—",
                isAvailable: window != nil,
                diameter: diameter,
                fontSize: fontSize
            )
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            updateProgress(forAppearance: true)
            updateActivityAnimation()
        }
        .onChange(of: remainingPercent) { _, _ in
            updateProgress()
        }
        .onChange(of: activity) { _, _ in
            updateActivityAnimation()
        }
        .onChange(of: reduceMotion) { _, _ in
            updateActivityAnimation()
        }
    }

    private var waveSpeed: Double {
        switch activity {
        case .running:
            return 2.0
        case .idle, .completed:
            return 0.65
        }
    }

    private func updateProgress(forAppearance: Bool = false) {
        if reduceMotion {
            displayedProgress = targetProgress
        } else if forAppearance, activity == .running {
            displayedProgress = 1
            withAnimation(.easeOut(duration: 0.9)) {
                displayedProgress = targetProgress
            }
        } else if forAppearance {
            displayedProgress = targetProgress
        } else {
            withAnimation(.easeInOut(duration: 0.42)) {
                displayedProgress = targetProgress
            }
        }
    }

    private func updateActivityAnimation() {
        guard !reduceMotion else {
            completionPulse = false
            displayedProgress = targetProgress
            return
        }

        switch activity {
        case .idle, .running:
            completionPulse = false
            updateProgress()
        case .completed:
            displayedProgress = targetProgress
            completionPulse = false
            withAnimation(.easeOut(duration: 0.5)) {
                completionPulse = true
            }
        }
    }
}

private struct QuotaWaveShape: Shape {
    var fillProgress: CGFloat
    var phase: Double

    var animatableData: AnimatablePair<CGFloat, Double> {
        get { AnimatablePair(fillProgress, phase) }
        set {
            fillProgress = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let progress = min(max(fillProgress, 0), 1)
        let level = rect.maxY - rect.height * progress
        let amplitude = max(0.8, rect.height * 0.075)
        let samples = 28
        let cycles = 1.35

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: level))

        for index in 0...samples {
            let fraction = CGFloat(index) / CGFloat(samples)
            let x = rect.minX + rect.width * fraction
            let angle = fraction * CGFloat(cycles * Double.pi * 2) + CGFloat(phase)
            let y = level + sin(angle) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct WeeklyQuotaRing: View {
    let style: QuotaDisplayStyle
    let usage: UsageSnapshot?
    let activity: QuotaRingActivity
    let diameter: CGFloat
    let lineWidth: CGFloat
    let fontSize: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedProgress: CGFloat = 0
    @State private var highlightActive = false
    @State private var completionPulse = false

    private var window: UsageWindow? {
        usage?.weeklyWindow
    }

    private var remainingPercent: Double {
        window?.remainingPercent ?? 0
    }

    private var targetProgress: CGFloat {
        CGFloat(min(max(remainingPercent, 0), 100) / 100)
    }

    private var progressColor: Color {
        guard window != nil else { return NotchPalette.secondaryText }
        return QuotaColorScale.color(for: remainingPercent)
    }

    private var progressTrim: (from: CGFloat, to: CGFloat) {
        switch style {
        case .clockwiseRing:
            // Keep the filled arc's end fixed at the 12 o'clock anchor. As
            // the remaining quota drops, the gap grows clockwise from there.
            return QuotaRingMath.clockwiseTrim(progress: displayedProgress)
        case .waveBall:
            return (0, displayedProgress)
        }
    }

    private var highlightTrim: (from: CGFloat, to: CGFloat) {
        switch style {
        case .clockwiseRing:
            return (0.84, 1)
        case .waveBall:
            return (0, 0)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(NotchPalette.track, lineWidth: lineWidth)

            if window != nil {
                Circle()
                    .trim(from: progressTrim.from, to: progressTrim.to)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(QuotaRingMath.clockwiseStartAngleDegrees))

                if activity == .running, !reduceMotion {
                    Circle()
                        .trim(from: highlightTrim.from, to: highlightTrim.to)
                        .stroke(
                            progressColor.opacity(0.96),
                            style: StrokeStyle(lineWidth: lineWidth + 0.8, lineCap: .round)
                        )
                        .rotationEffect(
                            .degrees(
                                (highlightActive ? 360 : 0)
                                    + QuotaRingMath.clockwiseStartAngleDegrees
                            )
                        )
                        .shadow(color: progressColor.opacity(0.6), radius: 2)
                        .animation(
                            .linear(duration: 1.45).repeatForever(autoreverses: false),
                            value: highlightActive
                        )
                }

                if activity == .completed, !reduceMotion {
                    Circle()
                        .stroke(
                            progressColor.opacity(completionPulse ? 0 : 0.7),
                            lineWidth: 1
                        )
                        .scaleEffect(completionPulse ? 1.32 : 0.84)
                        .animation(.easeOut(duration: 0.5), value: completionPulse)
                }
            }

            QuotaValueText(
                value: window.map { NotchText.quotaNumber($0.remainingPercent) } ?? "—",
                isAvailable: window != nil,
                fontSize: fontSize
            )
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            updateProgress(forAppearance: true)
            updateActivityAnimation()
        }
        .onChange(of: remainingPercent) { _, _ in
            updateProgress()
        }
        .onChange(of: activity) { _, _ in
            updateActivityAnimation()
        }
        .onChange(of: reduceMotion) { _, _ in
            updateActivityAnimation()
        }
    }

    private func updateProgress(forAppearance: Bool = false) {
        guard window != nil else {
            displayedProgress = 0
            return
        }
        if reduceMotion {
            displayedProgress = targetProgress
        } else if forAppearance, activity == .running {
            displayedProgress = 1
            withAnimation(.easeOut(duration: 0.9)) {
                displayedProgress = targetProgress
            }
        } else if forAppearance {
            displayedProgress = targetProgress
        } else {
            withAnimation(.easeInOut(duration: 0.42)) {
                displayedProgress = targetProgress
            }
        }
    }

    private func updateActivityAnimation() {
        guard !reduceMotion else {
            highlightActive = false
            completionPulse = false
            displayedProgress = targetProgress
            return
        }

        switch activity {
        case .idle:
            highlightActive = false
            completionPulse = false
            updateProgress()
        case .running:
            completionPulse = false
            displayedProgress = 1
            withAnimation(.easeOut(duration: 0.9)) {
                displayedProgress = targetProgress
            }
            highlightActive = true
        case .completed:
            highlightActive = false
            displayedProgress = targetProgress
            completionPulse = false
            withAnimation(.easeOut(duration: 0.5)) {
                completionPulse = true
            }
        }
    }
}

private struct ExpandedNotchView: View {
    let content: ExpandedContent
    let now: Date
    let cameraSafeAreaInset: CGFloat
    let onOpenThread: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WeeklyQuotaProgressView(usage: content.usage, now: now)

            if !content.conversations.isEmpty {
                Spacer(minLength: 7)

                Rectangle()
                    .fill(NotchPalette.border)
                    .frame(height: 0.5)

                Spacer(minLength: 6)

                Text("最近对话")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchPalette.secondaryText)

                Spacer(minLength: 4)

                VStack(spacing: 0) {
                    ForEach(
                        Array(content.conversations.enumerated()),
                        id: \.offset
                    ) { index, conversation in
                        ConversationRowView(
                            conversation: conversation,
                            now: now,
                            action: { onOpenThread(conversation.threadID) }
                        )

                        if index < content.conversations.count - 1 {
                            Rectangle()
                                .fill(NotchPalette.border)
                                .frame(height: 0.5)
                                .padding(.leading, 31)
                        }
                    }
                }
                .background(NotchPalette.row.opacity(0.62))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(NotchPalette.border, lineWidth: 0.5)
                }
            }
        }
        .padding(.horizontal, 14)
        // The panel itself attaches to the physical notch. Only the content
        // moves down, so the progress bar and text stay on drawable pixels.
        .padding(.top, cameraSafeAreaInset + 8)
        .padding(.bottom, 10)
    }
}

private struct ConversationRowView: View {
    let conversation: ConversationSummary
    let now: Date
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ConversationStatusView(activity: conversation.activity)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 1) {
                    Text(conversation.title ?? NotchText.projectName(cwd: conversation.cwd))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(NotchPalette.primaryText)
                        .lineLimit(1)
                    Text(metadataText)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(NotchPalette.secondaryText)
                        .lineLimit(1)
                        .monospacedDigit()
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(NotchPalette.secondaryText)
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle())
    }

    private var metadataText: String {
        let project = NotchText.projectName(cwd: conversation.cwd)
        switch conversation.activity {
        case let .running(startedAt):
            return "运行 \(NotchText.formatDuration(seconds: max(0, now.timeIntervalSince(startedAt)))) · \(project)"
        case let .completed(completedAt):
            return "已完成 · \(NotchText.relativeTime(from: completedAt, now: now)) · \(project)"
        }
    }
}

private struct ConversationStatusView: View {
    let activity: ConversationActivity

    var body: some View {
        switch activity {
        case .running:
            RunningStatusDot()
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NotchPalette.success)
        }
    }
}

private struct RunningStatusDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(NotchPalette.success)
            .frame(width: 6, height: 6)
            .scaleEffect(isPulsing ? 1.15 : 0.82)
            .opacity(isPulsing ? 0.62 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                isPulsing = true
            }
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: isPulsing
            )
    }
}

private struct WeeklyQuotaProgressView: View {
    let usage: UsageSnapshot?
    let now: Date

    private var window: UsageWindow? {
        usage?.weeklyWindow
    }

    private var progressColor: Color {
        guard window != nil else { return NotchPalette.secondaryText }
        return QuotaColorScale.color(for: window?.remainingPercent ?? 0)
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text("本周剩余")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchPalette.primaryText)

                Spacer()

                Text(window.map { NotchText.percent($0.remainingPercent) } ?? "—")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(progressColor)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                Capsule()
                    .fill(NotchPalette.track)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(progressColor)
                            .frame(
                                width: proxy.size.width * (window?.remainingPercent ?? 0) / 100
                            )
                    }
            }
            .frame(height: 5)

            HStack(spacing: 8) {
                Text(resetTimestampText)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(NotchPalette.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text("还剩 \(resetCountdownText)")
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchPalette.secondaryText)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 42)
        .animation(.easeInOut(duration: 0.28), value: window?.remainingPercent ?? 0)
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

enum QuotaColorScale {
    static func hue(for remainingPercent: Double) -> Double {
        let finiteValue = remainingPercent.isFinite ? remainingPercent : 0
        let clampedValue = min(max(finiteValue, 0), 100)
        return clampedValue / 100 * 0.34
    }

    static func color(for remainingPercent: Double) -> Color {
        Color(
            hue: hue(for: remainingPercent),
            saturation: 0.82,
            brightness: 0.96
        )
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

    static func quotaNumber(_ value: Double) -> String {
        "\(Int(value.rounded()))"
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

    static func relativeTime(from date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date).rounded(.down)))
        if seconds < 60 { return "刚刚" }
        if seconds < 3_600 { return "\(seconds / 60)分钟前" }
        if seconds < 86_400 { return "\(seconds / 3_600)小时前" }
        return "\(seconds / 86_400)天前"
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
