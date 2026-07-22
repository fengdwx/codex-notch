import AppKit
import SwiftUI

final class NotchViewModel: ObservableObject {
    @Published private(set) var state: NotchPresentationState
    @Published private(set) var now: Date
    @Published private(set) var cameraSafeAreaInset: CGFloat
    @Published private(set) var compactWidth: CGFloat
    @Published private(set) var surfaceSize: CGSize
    @Published private(set) var isResetScheduleExpanded = false

    var onOpenThread: (String) -> Void
    var onActivateChatGPT: () -> Void
    var onHoverChanged: (Bool) -> Void
    var onResetScheduleExpandedChanged: (Bool) -> Void

    init(
        state: NotchPresentationState = .hidden,
        now: Date = .now,
        cameraSafeAreaInset: CGFloat = 0,
        compactWidth: CGFloat = NotchCompactLayout.minimumWidth,
        surfaceSize: CGSize = CGSize(
            width: NotchCompactLayout.minimumWidth,
            height: NotchCompactLayout.height
        ),
        onOpenThread: @escaping (String) -> Void = { _ in },
        onActivateChatGPT: @escaping () -> Void = {},
        onHoverChanged: @escaping (Bool) -> Void = { _ in },
        onResetScheduleExpandedChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.state = state
        self.now = now
        self.cameraSafeAreaInset = cameraSafeAreaInset
        self.compactWidth = compactWidth
        self.surfaceSize = surfaceSize
        self.onOpenThread = onOpenThread
        self.onActivateChatGPT = onActivateChatGPT
        self.onHoverChanged = onHoverChanged
        self.onResetScheduleExpandedChanged = onResetScheduleExpandedChanged
    }

    func update(
        state: NotchPresentationState,
        now: Date,
        cameraSafeAreaInset: CGFloat = 0,
        compactWidth: CGFloat = NotchCompactLayout.minimumWidth,
        surfaceSize: CGSize = CGSize(
            width: NotchCompactLayout.minimumWidth,
            height: NotchCompactLayout.height
        ),
        isResetScheduleExpanded: Bool = false
    ) {
        let wasExpanded = Self.isExpanded(self.state)
        let willBeExpanded = Self.isExpanded(state)
        let changesSurface = wasExpanded != willBeExpanded
            || self.surfaceSize != surfaceSize
            || self.compactWidth != compactWidth
            || self.isResetScheduleExpanded != isResetScheduleExpanded

        let applyUpdate = {
            self.state = state
            self.now = now
            self.cameraSafeAreaInset = cameraSafeAreaInset
            self.compactWidth = compactWidth
            self.surfaceSize = surfaceSize
            self.isResetScheduleExpanded = isResetScheduleExpanded
        }

        if changesSurface {
            let expands = surfaceSize.height > self.surfaceSize.height + 0.5
                || surfaceSize.width > self.surfaceSize.width + 0.5
                || (isResetScheduleExpanded && !self.isResetScheduleExpanded)
            withAnimation(NotchPresentationMotion.animation(forExpanding: expands)) {
                applyUpdate()
            }
        } else {
            applyUpdate()
        }
    }

    private static func isExpanded(_ state: NotchPresentationState) -> Bool {
        if case .expanded = state { return true }
        return false
    }
}

struct NotchView: View {
    @ObservedObject private var model: NotchViewModel
    @AppStorage(QuotaDisplayStyle.storageKey)
    private var quotaDisplayStyleRaw = QuotaDisplayStyle.defaultStyle.rawValue
    @AppStorage(AppLanguage.storageKey)
    private var appLanguageRaw = AppLanguage.defaultLanguage.rawValue
    @State private var isPointerInside = false

    private var quotaDisplayStyle: QuotaDisplayStyle {
        QuotaDisplayStyle.fromStoredValue(quotaDisplayStyleRaw)
    }

    private var appLanguage: AppLanguage {
        AppLanguage.fromStoredValue(appLanguageRaw)
    }

    private var isExpanded: Bool {
        if case .expanded = model.state { return true }
        return false
    }

    private var isHidden: Bool {
        model.state == .hidden
    }

    private var surfaceMaterial: NotchSurfaceMaterial {
        NotchSurfaceMaterial.resolve(isHidden: isHidden)
    }

    private var surfaceBorder: Color {
        switch surfaceMaterial {
        case .black:
            return isExpanded ? NotchPalette.border : .clear
        case .clear:
            return .clear
        }
    }

    private var surfaceSize: CGSize {
        if isHidden || isExpanded {
            return model.surfaceSize
        }
        return CGSize(
            width: model.compactWidth,
            height: NotchCompactLayout.height
        )
    }

    private var surfaceShape: NotchAttachedShape {
        NotchAttachedShape(
            shoulderDepth: 6,
            bottomRadius: isExpanded ? 22 : 14
        )
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
                    subtitle: NotchText.quotaSubtitle(usage: usage, language: appLanguage),
                    usage: usage,
                    quotaDisplayStyle: quotaDisplayStyle,
                    action: model.onActivateChatGPT
                )
            case let .workingCompact(primary, count, usage):
                CompactNotchView(
                    icon: .working,
                    title: appLanguage.localized(
                        chinese: "Codex 运行中",
                        english: "Codex running"
                    ),
                    subtitle: count > 1
                        ? appLanguage.localized(
                            chinese: "\(count) 个任务",
                            english: "\(count) tasks"
                        )
                        : appLanguage.localized(
                            chinese: "已运行 \(NotchText.formatDuration(seconds: max(0, model.now.timeIntervalSince(primary.startedAt))))",
                            english: "Running for \(NotchText.formatDuration(seconds: max(0, model.now.timeIntervalSince(primary.startedAt))))"
                        ),
                    usage: usage,
                    quotaDisplayStyle: quotaDisplayStyle,
                    action: { model.onOpenThread(primary.threadID) }
                )
            case let .completedCompact(session, usage):
                CompactNotchView(
                    icon: .completed,
                    title: appLanguage.localized(
                        chinese: "Codex 已完成",
                        english: "Codex completed"
                    ),
                    subtitle: NotchText.projectName(cwd: session.cwd, language: appLanguage),
                    usage: usage,
                    quotaDisplayStyle: quotaDisplayStyle,
                    action: { model.onOpenThread(session.threadID) }
                )
            case let .expanded(content):
                ExpandedNotchView(
                    content: content,
                    now: model.now,
                    cameraSafeAreaInset: model.cameraSafeAreaInset,
                    compactWidth: model.compactWidth,
                    quotaDisplayStyle: quotaDisplayStyle,
                    language: appLanguage,
                    isResetScheduleExpanded: model.isResetScheduleExpanded,
                    onActivateChatGPT: model.onActivateChatGPT,
                    onOpenThread: model.onOpenThread,
                    onResetScheduleExpandedChanged: model.onResetScheduleExpandedChanged
                )
                .transition(.opacity)
            }
        }
        // The panel is already at its final size before this state changes.
        // Animate this one visible surface from the compact island downward;
        // clear canvas around it never becomes part of the notch itself.
        .frame(
            width: surfaceSize.width,
            height: surfaceSize.height,
            alignment: .top
        )
        .contentShape(surfaceShape)
        .background {
            NotchSurfaceBackground(
                material: surfaceMaterial,
                shape: surfaceShape
            )
        }
        .clipShape(surfaceShape)
        .overlay {
            surfaceShape.stroke(
                surfaceBorder,
                lineWidth: 0.5
            )
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                isPointerInside = hovering
            }
            model.onHoverChanged(hovering)
        }
        .contextMenu {
            SettingsLink {
                Label(
                    appLanguage.localized(chinese: "设置…", english: "Settings…"),
                    systemImage: "gearshape"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.notchAppLanguage, appLanguage)
    }
}

private struct NotchAppLanguageKey: EnvironmentKey {
    static let defaultValue = AppLanguage.defaultLanguage
}

private extension EnvironmentValues {
    var notchAppLanguage: AppLanguage {
        get { self[NotchAppLanguageKey.self] }
        set { self[NotchAppLanguageKey.self] = newValue }
    }
}

private struct NotchSurfaceBackground: View {
    let material: NotchSurfaceMaterial
    let shape: NotchAttachedShape

    @ViewBuilder
    var body: some View {
        switch material {
        case .clear:
            Color.clear
        case .black:
            NotchPalette.background
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
    let action: () -> Void
    @Environment(\.notchAppLanguage) private var language

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                CompactAppIconView(status: icon)
                    .frame(
                        width: NotchCompactLayout.indicatorLaneWidth,
                        height: NotchCompactLayout.height
                    )

                Spacer(minLength: 0)

                // The wider content lanes move both indicators slightly toward
                // the camera while keeping their visible shapes outside it.
                CompactQuotaView(
                    usage: usage,
                    activity: icon.quotaActivity,
                    style: quotaDisplayStyle
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
            parts.append(NotchText.quotaSubtitle(usage: usage, language: language))
        }
        return parts.joined(separator: language == .english ? ", " : "，")
    }

}

private struct CompactAppIconView: View {
    let status: CompactNotchView.IconKind

    var body: some View {
        Group {
            switch status {
            case .working:
                RunningChatGPTIcon(size: NotchCompactLayout.appMarkSize)
            case .completed:
                CompletedChatGPTIcon(size: NotchCompactLayout.appMarkSize)
            case .quota:
                ChatGPTMark(
                    size: NotchCompactLayout.appMarkSize,
                    fallbackSystemName: status.fallbackSystemName
                )
            }
        }
        .frame(
            width: NotchCompactLayout.indicatorDiameter,
            height: NotchCompactLayout.height
        )
        .accessibilityHidden(true)
    }
}

private struct CompactQuotaView: View {
    let usage: UsageSnapshot?
    let activity: QuotaRingActivity
    let style: QuotaDisplayStyle

    var body: some View {
        quotaIndicator
            .offset(x: NotchCompactLayout.quotaIndicatorOutwardOffset)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(
                width: NotchCompactLayout.indicatorLaneWidth,
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
            diameter: NotchCompactLayout.indicatorDiameter,
            lineWidth: NotchCompactLayout.quotaIndicatorLineWidth(for: style),
            fontSize: 10.5
        )
    }
}

private struct CompletedChatGPTIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasSettled = false

    let size: CGFloat

    var body: some View {
        ZStack {
            if !reduceMotion {
                // Keep the acknowledgement tied to the actual ChatGPT mark,
                // not a generic circular notification ring. It reads as a
                // single completion echo from the left-side app icon.
                ChatGPTMark(size: size, tint: NotchPalette.success)
                    .scaleEffect(hasSettled ? 1.14 : 0.92)
                    .opacity(hasSettled ? 0 : 0.42)
                    .blur(radius: hasSettled ? 0.5 : 0)
            }

            ChatGPTMark(size: size)

            Image(systemName: "checkmark")
                .font(.system(size: 6.5, weight: .black))
                .foregroundStyle(Color.black)
                .frame(width: 11, height: 11)
                .background(NotchPalette.success, in: Circle())
                .overlay {
                    Circle()
                        .stroke(NotchPalette.background, lineWidth: 1)
                }
                .offset(x: 6, y: 6)
        }
        .frame(width: size, height: size)
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
    var tint = NotchPalette.primaryText.opacity(0.96)

    var body: some View {
        Group {
            if let image = ChatGPTIconAsset.templateImage {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .foregroundStyle(tint)
            } else {
                Image(systemName: fallbackSystemName)
                    .font(.system(size: size * 0.72, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct RunningChatGPTIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Keep the running signal visible without a perpetual pulse.
            // The low-opacity blue silhouette is the static ChatGPT echo.
            ChatGPTMark(size: size, tint: NotchPalette.accent.opacity(0.38))
                .scaleEffect(1.05)
                .blur(radius: 0.2)

            ChatGPTMark(size: size)
        }
        .frame(width: size, height: size)
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

private struct QuotaCompletionParticles: View {
    let color: Color
    let diameter: CGFloat

    @State private var startedAt = Date()
    @State private var hasFinished = false

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 60.0,
                paused: hasFinished
            )
        ) { context in
            particleField(
                elapsed: context.date.timeIntervalSince(startedAt)
            )
        }
        .onAppear {
            startedAt = .now
            hasFinished = false
        }
        .task {
            try? await Task.sleep(
                nanoseconds: UInt64(
                    QuotaIndicatorMotion.completionFireworkTotalDuration
                        * 1_000_000_000
                )
            )
            guard !Task.isCancelled else { return }
            hasFinished = true
        }
    }

    private func particleField(elapsed: TimeInterval) -> some View {
        ZStack {
            ignitionFlash(elapsed: elapsed)

            ForEach(
                Array(QuotaIndicatorMotion.completionParticles.enumerated()),
                id: \.offset
            ) { _, spec in
                particle(spec: spec, elapsed: elapsed)
            }

            ForEach(
                Array(QuotaIndicatorMotion.completionEndpointSparks.enumerated()),
                id: \.offset
            ) { _, spec in
                endpointSpark(spec: spec, elapsed: elapsed)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private func ignitionFlash(elapsed: TimeInterval) -> some View {
        let progress = QuotaIndicatorMotion.completionIgnitionProgress(
            elapsed: elapsed
        )
        let opacity = QuotaIndicatorMotion.completionIgnitionOpacity(
            progress: progress
        )

        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.82))
                .blur(radius: 0.7)

            Circle()
                .stroke(Color.white.opacity(0.96), lineWidth: 0.9)
        }
        .frame(
            width: 5 + progress * 9,
            height: 5 + progress * 9
        )
        .opacity(opacity)
    }

    private func particle(
        spec: CompletionParticleSpec,
        elapsed: TimeInterval
    ) -> some View {
        let progress = QuotaIndicatorMotion.completionParticleProgress(
            elapsed: elapsed,
            delay: spec.delay
        )
        let offset = QuotaIndicatorMotion.completionParticleOffset(
            spec: spec,
            progress: progress
        )

        let particleColor = toneColor(spec.tone)

        return Circle()
            .fill(particleColor)
            .frame(width: spec.diameter, height: spec.diameter)
            .scaleEffect(
                QuotaIndicatorMotion.completionParticleScale(
                    progress: progress
                )
            )
            .offset(x: offset.width, y: offset.height)
            .opacity(
                QuotaIndicatorMotion.completionParticleOpacity(
                    progress: progress
                )
            )
            .shadow(
                color: particleColor.opacity(spec.tone == .highlight ? 0.9 : 0.7),
                radius: QuotaIndicatorMotion.completionParticleGlowRadius(
                    tone: spec.tone
                )
            )
    }

    private func endpointSpark(
        spec: CompletionSparkSpec,
        elapsed: TimeInterval
    ) -> some View {
        let progress = QuotaIndicatorMotion.completionSparkProgress(
            elapsed: elapsed,
            delay: spec.delay
        )
        let offset = QuotaIndicatorMotion.completionSparkOffset(spec: spec)
        let sparkColor = toneColor(spec.tone)

        return CompletionSparkShape()
            .fill(sparkColor)
            .frame(width: spec.diameter, height: spec.diameter)
            .scaleEffect(
                QuotaIndicatorMotion.completionSparkScale(progress: progress)
            )
            .offset(x: offset.width, y: offset.height)
            .opacity(
                QuotaIndicatorMotion.completionSparkOpacity(progress: progress)
            )
            .shadow(
                color: sparkColor.opacity(0.92),
                radius: QuotaIndicatorMotion.completionSparkGlowRadius
            )
    }

    private func toneColor(_ tone: CompletionParticleTone) -> Color {
        switch tone {
        case .success:
            return color
        case .highlight:
            return Color.white.opacity(0.98)
        case .coral:
            return NotchPalette.completionCoral
        }
    }
}

private struct CompletionSparkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inner = min(rect.width, rect.height) * 0.16
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()
        path.move(to: CGPoint(x: center.x, y: rect.minY))
        path.addLine(to: CGPoint(x: center.x + inner, y: center.y - inner))
        path.addLine(to: CGPoint(x: rect.maxX, y: center.y))
        path.addLine(to: CGPoint(x: center.x + inner, y: center.y + inner))
        path.addLine(to: CGPoint(x: center.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: center.x - inner, y: center.y + inner))
        path.addLine(to: CGPoint(x: rect.minX, y: center.y))
        path.addLine(to: CGPoint(x: center.x - inner, y: center.y - inner))
        path.closeSubpath()
        return path
    }
}

private struct QuotaValueText: View {
    let value: String
    let isAvailable: Bool
    let fontSize: CGFloat

    private var textColor: Color {
        isAvailable ? NotchPalette.primaryText : NotchPalette.secondaryText
    }

    private var outlineColor: Color {
        Color.black.opacity(isAvailable ? 0.88 : 0.56)
    }

    private var outlineOffset: CGFloat {
        isAvailable ? 0.8 : 0.6
    }

    var body: some View {
        Text(value)
            .font(.system(
                size: isAvailable ? fontSize : fontSize + 1,
                weight: .bold,
                design: .rounded
            ))
            .foregroundStyle(textColor)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            // A text-only outline keeps the liquid fully visible while
            // preserving contrast as the wave crosses behind each glyph.
            .shadow(color: outlineColor, radius: 0.35, x: -outlineOffset, y: 0)
            .shadow(color: outlineColor, radius: 0.35, x: outlineOffset, y: 0)
            .shadow(color: outlineColor, radius: 0.35, x: 0, y: -outlineOffset)
            .shadow(color: outlineColor, radius: 0.35, x: 0, y: outlineOffset)
            .shadow(
                color: .black.opacity(isAvailable ? 0.64 : 0.35),
                radius: 1.15,
                x: 0,
                y: 0.4
            )
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

            waveFill

            Circle()
                .strokeBorder(NotchPalette.border, lineWidth: lineWidth)

            if activity == .completed, !reduceMotion {
                QuotaCompletionParticles(
                    color: NotchPalette.success,
                    diameter: diameter
                )
            }

            // The value uses glyph-only outlining: nothing masks the liquid.
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

    @ViewBuilder
    private var waveFill: some View {
        if QuotaIndicatorMotion.shouldAnimate(
            isTaskRunning: activity == .running,
            reduceMotion: reduceMotion
        ) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                waveShape(
                    phase: context.date.timeIntervalSinceReferenceDate * 2.0
                )
            }
        } else {
            waveShape(phase: 0)
        }
    }

    private func waveShape(phase: Double) -> some View {
        QuotaWaveShape(
            fillProgress: displayedProgress,
            phase: phase
        )
        .fill(progressColor)
        .clipShape(Circle())
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
            displayedProgress = targetProgress
            return
        }

        switch activity {
        case .idle, .running:
            updateProgress()
        case .completed:
            displayedProgress = targetProgress
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

    private var shouldAnimateGradient: Bool {
        QuotaIndicatorMotion.shouldAnimate(
            isTaskRunning: activity == .running,
            reduceMotion: reduceMotion
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(NotchPalette.track, lineWidth: lineWidth)

            if window != nil {
                quotaStroke

                if activity == .completed, !reduceMotion {
                    QuotaCompletionParticles(
                        color: NotchPalette.success,
                        diameter: diameter
                    )
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

    @ViewBuilder
    private var quotaStroke: some View {
        switch QuotaRingAppearance.colorMode(for: activity) {
        case .solid:
            quotaArc(progressColor)
        case .gradient:
            TimelineView(
                .animation(
                    minimumInterval: 1.0 / 60.0,
                    paused: !shouldAnimateGradient
                )
            ) { context in
                quotaArc(
                    QuotaRingGradient.gradient(
                        progressColor: progressColor,
                        angle: QuotaRingGradientMotion.angle(
                            at: context.date,
                            isAnimating: shouldAnimateGradient
                        )
                    )
                )
            }
        }
    }

    private func quotaArc<S: ShapeStyle>(_ shapeStyle: S) -> some View {
        Circle()
            .inset(by: QuotaRingMath.containedStrokeInset(lineWidth: lineWidth))
            .trim(from: progressTrim.from, to: progressTrim.to)
            .stroke(
                shapeStyle,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(QuotaRingMath.clockwiseStartAngleDegrees))
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
            displayedProgress = targetProgress
            return
        }

        switch activity {
        case .idle:
            updateProgress()
        case .running:
            displayedProgress = 1
            withAnimation(.easeOut(duration: 0.9)) {
                displayedProgress = targetProgress
            }
        case .completed:
            displayedProgress = targetProgress
        }
    }
}

private enum QuotaRingGradient {
    static func gradient(progressColor: Color, angle: Double) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: progressColor.opacity(0.24), location: 0),
                .init(color: progressColor.opacity(0.42), location: 0.18),
                .init(color: progressColor.opacity(0.78), location: 0.36),
                .init(color: progressColor, location: 0.52),
                .init(color: progressColor.opacity(0.82), location: 0.66),
                .init(color: progressColor.opacity(0.46), location: 0.82),
                .init(color: progressColor.opacity(0.24), location: 1)
            ]),
            center: .center,
            startAngle: .degrees(angle),
            endAngle: .degrees(angle + 360)
        )
    }
}

private struct ExpandedNotchView: View {
    let content: ExpandedContent
    let now: Date
    let cameraSafeAreaInset: CGFloat
    let compactWidth: CGFloat
    let quotaDisplayStyle: QuotaDisplayStyle
    let language: AppLanguage
    let isResetScheduleExpanded: Bool
    let onActivateChatGPT: () -> Void
    let onOpenThread: (String) -> Void
    let onResetScheduleExpandedChanged: (Bool) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            detailContent

            // Keep the original compact island visible at the top. The detail
            // body is revealed underneath it as the panel's bottom edge grows.
            CompactNotchView(
                icon: headerIcon,
                title: headerTitle,
                subtitle: headerSubtitle,
                usage: content.usage,
                quotaDisplayStyle: quotaDisplayStyle,
                action: headerAction
            )
            .frame(
                width: compactWidth,
                height: NotchCompactLayout.height
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            WeeklyQuotaProgressView(
                usage: content.usage,
                now: now,
                isResetScheduleExpanded: isResetScheduleExpanded,
                onResetScheduleExpandedChanged: onResetScheduleExpandedChanged
            )

            if !content.conversations.isEmpty {
                Spacer(minLength: 8)

                Rectangle()
                    .fill(NotchPalette.border)
                    .frame(height: 0.5)

                Spacer(minLength: 8)

                Text(language.localized(chinese: "最近对话", english: "Recent conversations"))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchPalette.secondaryText)

                Spacer(minLength: 6)

                VStack(spacing: 0) {
                    ForEach(
                        Array(content.conversations.enumerated()),
                        id: \.offset
                    ) { index, conversation in
                        ConversationRowView(
                            conversation: conversation,
                            now: now,
                            language: language,
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

            Spacer(minLength: 6)

            HStack {
                Spacer(minLength: 0)

                SettingsLink {
                    Label(
                        language.localized(chinese: "设置", english: "Settings"),
                        systemImage: "gearshape"
                    )
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(NotchPalette.secondaryText)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(NotchPalette.row.opacity(0.82), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(NotchPalette.border, lineWidth: 0.5)
                        }
                }
                .buttonStyle(NotchButtonStyle())
                .accessibilityLabel(
                    language.localized(chinese: "打开设置", english: "Open settings")
                )
            }
        }
        .padding(.horizontal, 14)
        // The panel itself attaches to the physical notch. Only the content
        // moves down, so the progress bar and text stay on drawable pixels.
        .padding(.top, cameraSafeAreaInset + 8)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var headerIcon: CompactNotchView.IconKind {
        if !content.sessions.isEmpty {
            return .working
        }
        if content.headerConversation != nil {
            return .completed
        }
        return .quota
    }

    private var headerTitle: String {
        switch headerIcon {
        case .working:
            return language.localized(chinese: "Codex 运行中", english: "Codex running")
        case .completed:
            return language.localized(chinese: "Codex 已完成", english: "Codex completed")
        case .quota:
            return "Codex"
        }
    }

    private var headerSubtitle: String {
        if let session = content.sessions.first {
            return NotchText.sessionSubtitle(session, now: now, language: language)
        }
        if let conversation = content.headerConversation {
            return NotchText.projectName(cwd: conversation.cwd, language: language)
        }
        return NotchText.quotaSubtitle(usage: content.usage, language: language)
    }

    private var headerAction: () -> Void {
        if let session = content.sessions.first {
            return { onOpenThread(session.threadID) }
        }
        if let conversation = content.headerConversation {
            return { onOpenThread(conversation.threadID) }
        }
        return onActivateChatGPT
    }
}

private struct ConversationRowView: View {
    let conversation: ConversationSummary
    let now: Date
    let language: AppLanguage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ConversationStatusView(activity: conversation.activity)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        conversation.title
                            ?? NotchText.projectName(cwd: conversation.cwd, language: language)
                    )
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(NotchPalette.primaryText)
                        .lineLimit(1)
                    Text(metadataText)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(NotchPalette.secondaryText)
                        .lineLimit(1)
                        .monospacedDigit()
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchPalette.secondaryText)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle())
    }

    private var metadataText: String {
        let project = NotchText.projectName(cwd: conversation.cwd, language: language)
        switch conversation.activity {
        case let .running(startedAt):
            return language.localized(
                chinese: "运行 \(NotchText.formatDuration(seconds: max(0, now.timeIntervalSince(startedAt)))) · \(project)",
                english: "Running \(NotchText.formatDuration(seconds: max(0, now.timeIntervalSince(startedAt)))) · \(project)"
            )
        case let .completed(completedAt):
            return language.localized(
                chinese: "已完成 · \(NotchText.relativeTime(from: completedAt, now: now, language: language)) · \(project)",
                english: "Completed · \(NotchText.relativeTime(from: completedAt, now: now, language: language)) · \(project)"
            )
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
                .font(.system(size: 12, weight: .semibold))
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
            .frame(width: 7, height: 7)
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
    let isResetScheduleExpanded: Bool
    let onResetScheduleExpandedChanged: (Bool) -> Void
    @Environment(\.notchAppLanguage) private var language

    private var window: UsageWindow? {
        usage?.weeklyWindow
    }

    private var progressColor: Color {
        guard window != nil else { return NotchPalette.secondaryText }
        return QuotaColorScale.color(for: window?.remainingPercent ?? 0)
    }

    private var resetCredits: [ResetCredit] {
        usage?.resetCredits ?? []
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text(language.localized(chinese: "本周剩余", english: "Weekly remaining"))
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchPalette.primaryText)

                Spacer()

                Text(window.map { NotchText.percent($0.remainingPercent) } ?? "—")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
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
            .frame(height: 6)

            HStack(spacing: 8) {
                Text(resetTimestampText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(NotchPalette.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(
                    language.localized(
                        chinese: "还剩 \(resetCountdownText)",
                        english: "\(resetCountdownText) remaining"
                    )
                )
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchPalette.secondaryText)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            ResetScheduleDisclosure(
                credits: resetCredits,
                now: now,
                isExpanded: isResetScheduleExpanded,
                title: NotchText.resetCredits(usage: usage, language: language),
                onExpandedChanged: onResetScheduleExpandedChanged
            )
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .top)
        .animation(.easeInOut(duration: 0.28), value: window?.remainingPercent ?? 0)
    }

    private var resetTimestampText: String {
        guard let resetAt = window?.resetAt else {
            return language.localized(
                chinese: "重置时间暂不可用",
                english: "Reset time unavailable"
            )
        }
        return language.localized(
            chinese: "重置于 \(NotchText.resetTimestamp(resetAt))",
            english: "Resets at \(NotchText.resetTimestamp(resetAt))"
        )
    }

    private var resetCountdownText: String {
        guard let resetAt = window?.resetAt else {
            return "--:--:--"
        }
        return NotchText.resetCountdown(
            resetAt: resetAt,
            now: now,
            language: language
        )
    }
}

private struct ResetScheduleDisclosure: View {
    let credits: [ResetCredit]
    let now: Date
    let isExpanded: Bool
    let title: String
    let onExpandedChanged: (Bool) -> Void
    @Environment(\.notchAppLanguage) private var language

    var body: some View {
        VStack(spacing: NotchExpandedLayout.resetScheduleDetailSpacing) {
            Button {
                guard !credits.isEmpty else { return }
                onExpandedChanged(!isExpanded)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 10.5, weight: .semibold))

                    Text(title)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundStyle(
                    credits.isEmpty
                        ? NotchPalette.secondaryText
                        : NotchPalette.primaryText.opacity(0.82)
                )
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .background(
                    credits.isEmpty
                        ? NotchPalette.row.opacity(0.35)
                        : NotchPalette.row.opacity(0.78),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(NotchPalette.border, lineWidth: 0.5)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(NotchButtonStyle())
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityLabel(
                language.localized(
                    chinese: "重置次数：\(title)",
                    english: "Reset credits: \(title)"
                )
            )
            .accessibilityHint(
                credits.isEmpty
                    ? language.localized(
                        chinese: "接口暂未返回重置券明细",
                        english: "The service has not returned reset-credit details"
                    )
                    : language.localized(
                        chinese: "点击展开或收起对应重置次数的到期时间",
                        english: "Click to show or hide reset-credit expiry times"
                    )
            )

            if isExpanded, !credits.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(credits.enumerated()), id: \.element.id) { index, credit in
                        ResetScheduleRow(credit: credit, now: now, language: language)

                        if index < credits.count - 1 {
                            Rectangle()
                                .fill(NotchPalette.border)
                                .frame(height: NotchExpandedLayout.conversationSeparatorHeight)
                        }
                    }
                }
                .padding(.vertical, NotchExpandedLayout.resetScheduleDetailVerticalPadding)
                .background(NotchPalette.row.opacity(0.62))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(NotchPalette.border, lineWidth: 0.5)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
    }
}

private struct ResetScheduleRow: View {
    let credit: ResetCredit
    let now: Date
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 10) {
            Text(NotchText.resetCreditExpiry(credit, language: language))
                .monospacedDigit()
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(NotchPalette.primaryText)

            Spacer(minLength: 4)

            Text(
                credit.expiresAt.map {
                    language.localized(
                        chinese: "还剩 \(NotchText.resetCountdown(resetAt: $0, now: now, language: language))",
                        english: "\(NotchText.resetCountdown(resetAt: $0, now: now, language: language)) remaining"
                    )
                } ?? "—"
            )
            .monospacedDigit()
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(NotchPalette.secondaryText)
        }
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: NotchExpandedLayout.resetScheduleRowHeight)
    }
}

enum QuotaColorScale {
    struct RGB: Equatable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
    }

    static func band(for remainingPercent: Double) -> WeeklyQuotaLevel {
        WeeklyQuotaLevel(remainingPercent: remainingPercent)
    }

    static func components(for remainingPercent: Double) -> RGB {
        switch band(for: remainingPercent) {
        case .healthy:
            return RGB(red: 0.29, green: 0.84, blue: 0.43)
        case .warning:
            return RGB(red: 1.0, green: 0.76, blue: 0.18)
        case .critical:
            return RGB(red: 0.86, green: 0.12, blue: 0.18)
        case .unavailable:
            return RGB(red: 0.86, green: 0.12, blue: 0.18)
        }
    }

    static func color(for remainingPercent: Double) -> Color {
        let components = components(for: remainingPercent)
        return Color(
            red: components.red,
            green: components.green,
            blue: components.blue
        )
    }
}

private enum NotchPalette {
    static let background = Color.black
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.6)
    static let row = Color.white.opacity(0.09)
    static let border = Color.white.opacity(0.1)
    static let track = Color.white.opacity(0.13)
    static let accent = Color(red: 0.38, green: 0.66, blue: 1.0)
    static let warning = Color(red: 1.0, green: 0.68, blue: 0.28)
    static let success = Color(red: 0.34, green: 0.88, blue: 0.55)
    static let completionCoral = Color(red: 1.0, green: 0.31, blue: 0.22)
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
    static func windowLabel(
        _ kind: UsageWindowKind,
        language: AppLanguage = .chinese
    ) -> String {
        switch kind {
        case let .rolling(hours):
            return language.localized(
                chinese: "滚动 \(hours)h",
                english: "Rolling \(hours)h"
            )
        case .daily:
            return language.localized(chinese: "每日", english: "Daily")
        case .weekly:
            return language.localized(chinese: "每周", english: "Weekly")
        case let .custom(seconds):
            return formatDuration(seconds: seconds)
        }
    }

    static func compactWindow(
        _ window: UsageWindow,
        language: AppLanguage = .chinese
    ) -> String {
        language.localized(
            chinese: "\(windowLabel(window.kind, language: language))余\(percent(window.remainingPercent))",
            english: "\(windowLabel(window.kind, language: language)) \(percent(window.remainingPercent)) left"
        )
    }

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    static func quotaNumber(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    static func quotaSubtitle(
        usage: UsageSnapshot?,
        language: AppLanguage = .chinese
    ) -> String {
        guard let usage, let window = usage.windows.first else {
            return language.localized(
                chinese: "额度暂不可用",
                english: "Quota unavailable"
            )
        }
        return language.localized(
            chinese: "\(windowLabel(window.kind, language: language))剩余 \(percent(window.remainingPercent)) · 已用 \(percent(window.usedPercent))",
            english: "\(windowLabel(window.kind, language: language)) \(percent(window.remainingPercent)) remaining · \(percent(window.usedPercent)) used"
        )
    }

    static func resetCredits(
        usage: UsageSnapshot?,
        language: AppLanguage = .chinese
    ) -> String {
        guard let credits = usage?.resetCreditsAvailable else {
            return language.localized(chinese: "重置 —", english: "Resets —")
        }
        return language.localized(
            chinese: "可重置 \(credits) 次",
            english: "\(credits) resets available"
        )
    }

    static func resetCreditTitle(
        _ credit: ResetCredit,
        language: AppLanguage = .chinese
    ) -> String {
        let title = credit.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty
            ? language.localized(chinese: "使用限额重置", english: "Usage reset")
            : title
    }

    static func resetCreditExpiry(
        _ credit: ResetCredit,
        timeZone: TimeZone = .current,
        language: AppLanguage = .chinese
    ) -> String {
        guard let expiresAt = credit.expiresAt else {
            return language.localized(
                chinese: "到期时间暂不可用",
                english: "Expiry unavailable"
            )
        }
        return language.localized(
            chinese: "到期 \(resetTimestamp(expiresAt, timeZone: timeZone))",
            english: "Expires \(resetTimestamp(expiresAt, timeZone: timeZone))"
        )
    }

    static func sessionSubtitle(
        _ session: SessionActivity,
        now: Date,
        language: AppLanguage = .chinese
    ) -> String {
        language.localized(
            chinese: "\(projectName(cwd: session.cwd, language: language)) · 已运行 \(formatDuration(seconds: max(0, now.timeIntervalSince(session.startedAt))))",
            english: "\(projectName(cwd: session.cwd, language: language)) · Running for \(formatDuration(seconds: max(0, now.timeIntervalSince(session.startedAt))))"
        )
    }

    static func projectName(
        cwd: String?,
        language: AppLanguage = .chinese
    ) -> String {
        guard let cwd, !cwd.isEmpty else {
            return language.localized(chinese: "未命名任务", english: "Unnamed task")
        }
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? cwd : name
    }

    static func relativeTime(
        from date: Date,
        now: Date,
        language: AppLanguage = .chinese
    ) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date).rounded(.down)))
        if seconds < 60 {
            return language.localized(chinese: "刚刚", english: "just now")
        }
        if seconds < 3_600 {
            return language.localized(
                chinese: "\(seconds / 60)分钟前",
                english: "\(seconds / 60)m ago"
            )
        }
        if seconds < 86_400 {
            return language.localized(
                chinese: "\(seconds / 3_600)小时前",
                english: "\(seconds / 3_600)h ago"
            )
        }
        return language.localized(
            chinese: "\(seconds / 86_400)天前",
            english: "\(seconds / 86_400)d ago"
        )
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

    static func resetCountdown(
        resetAt: Date,
        now: Date,
        language: AppLanguage = .chinese
    ) -> String {
        let total = max(0, Int(resetAt.timeIntervalSince(now).rounded(.down)))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60

        if days > 0 {
            return language.localized(
                chinese: String(format: "%d天 %02d:%02d:%02d", days, hours, minutes, seconds),
                english: String(format: "%dd %02d:%02d:%02d", days, hours, minutes, seconds)
            )
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private static func formatDuration(seconds: Int) -> String {
        formatDuration(seconds: TimeInterval(seconds))
    }
}
