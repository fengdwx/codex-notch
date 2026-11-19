import AppKit
import SwiftUI

enum NotchSettingsLayout {
    static let windowWidth: CGFloat = 720
    static let windowHeight: CGFloat = 540
    static let sidebarWidth: CGFloat = 186
    static let topBarHeight: CGFloat = 40
    static let sheetInset: CGFloat = 10
    static let sheetCornerRadius: CGFloat = 14
}

/// Dedicated AppKit drag surface so transparent-titlebar Settings windows can
/// always be dragged cleanly across the top strip and empty header areas,
/// letting AppKit's native window drag handle movement without custom loops.
struct SettingsWindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DragHandleView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragHandleView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
    }
}

/// Fallback chrome configuration when NotchSettingsView is hosted inside a
/// SwiftUI Settings scene rather than SettingsWindowPresenter's native NSWindow.
/// Configures each window at most once on attachment and never mutates frame
/// geometry during SwiftUI updates or drags.
struct SettingsWindowChromeAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowObservingView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private static func configureOnce(_ window: NSWindow) {
        if window.titleVisibility != .hidden {
            window.titleVisibility = .hidden
        }
        if !window.titlebarAppearsTransparent {
            window.titlebarAppearsTransparent = true
        }
        window.titlebarSeparatorStyle = .none
        if window.toolbar == nil {
            let toolbar = NSToolbar(identifier: "com.david.codexnotch.settings.toolbar")
            toolbar.allowsUserCustomization = false
            toolbar.autosavesConfiguration = false
            window.toolbar = toolbar
        }
        window.toolbarStyle = .unifiedCompact
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }
        if window.styleMask.contains(.resizable) {
            window.styleMask.remove(.resizable)
        }
        window.isMovable = true
        window.isMovableByWindowBackground = true
    }

    private final class WindowObservingView: NSView {
        private weak var configuredWindow: NSWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, configuredWindow !== window else { return }
            configuredWindow = window
            SettingsWindowChromeAccessor.configureOnce(window)
        }
    }
}

/// Redirects any system-restored or shortcut-triggered SwiftUI `Settings` scene
/// into `SettingsWindowPresenter.showNativeSettings()` so macOS can never display
/// a stray non-full-bleed SwiftUI Settings window alongside the native window.
struct SettingsSceneRedirectView: View {
    var body: some View {
        RedirectRepresentable()
            .frame(width: 1, height: 1)
    }

    private struct RedirectRepresentable: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
            RedirectView()
        }

        func updateNSView(_ nsView: NSView, context: Context) {}

        private final class RedirectView: NSView {
            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                guard let window else { return }
                window.identifier = NSUserInterfaceItemIdentifier("com.david.codexnotch.settings.redirect")
                window.title = ""
                window.isRestorable = false
                window.alphaValue = 0
                DispatchQueue.main.async {
                    let wasVisible = window.isVisible
                    window.orderOut(nil)
                    window.close()
                    if wasVisible {
                        SettingsWindowPresenter.showNativeSettings()
                    }
                }
            }
        }
    }
}

/// Unified modern macOS Tahoe cool-neutral window shell spanning the top header
/// bar, left sidebar, and outer inset margin with zero desktop wallpaper tint bleed.
struct SettingsWindowShellBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                Color(red: 0.086, green: 0.086, blue: 0.094)
            } else {
                Color(red: 0.969, green: 0.969, blue: 0.973)
            }
            SettingsWindowDragArea()
        }
    }
}

/// Inset continuous-rounded white/elevated detail sheet sitting cleanly inside
/// the unified window shell below the top header bar.
struct SettingsDetailSheet<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    private var fillColor: Color {
        colorScheme == .dark
            ? Color(red: 0.125, green: 0.125, blue: 0.135)
            : Color.white
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.095)
            : Color(red: 0.875, green: 0.875, blue: 0.886)
    }

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: NotchSettingsLayout.sheetCornerRadius,
            style: .continuous
        )

        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(fillColor)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(borderColor, lineWidth: 0.5)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0 : 0.025),
                radius: 2.5,
                y: 1
            )
    }
}

/// Calm, softly tinted hairline-bordered grouped surface card inside the white inset sheet.
struct SettingsSurfaceCard<Content: View>: View {
    var padding: CGFloat = 14
    var accentBorder: Color? = nil
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    private var fillColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.042)
            : Color(red: 0.976, green: 0.976, blue: 0.982)
    }

    private var borderColor: Color {
        accentBorder ?? (colorScheme == .dark ? Color.white.opacity(0.085) : Color.black.opacity(0.068))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 0.5)
        )
    }
}

/// Quiet one-line contextual description at the top of an inset settings sheet.
struct SettingsSheetIntro: View {
    let subtitle: String

    var body: some View {
        Text(subtitle)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// CodexNotch's frameless brand mark (matching `Resources/AppIcon.svg` without
/// an enclosing square tile or shadow) using a crisp rounded-rectangle notch
/// silhouette (`rx = 160`), tight camera cutout with subtle 16-unit shoulder
/// fillets, and obsidian surface depth.
struct CodexNotchBrandIcon: View {
    var width: CGFloat = 32
    @Environment(\.colorScheme) private var colorScheme

    private static let aspectRatio: CGFloat = 438.0 / 896.0

    var body: some View {
        let height = width * Self.aspectRatio

        Canvas { context, canvasSize in
            // Map AppIcon.svg notch-shell bounds (x: 64..960, y: 300..738) into canvasSize
            // with 0.5pt inset so stroke edges never clip.
            let pad: CGFloat = 0.5
            let availW = max(1, canvasSize.width - pad * 2)
            let availH = max(1, canvasSize.height - pad * 2)
            let s = min(availW / 896.0, availH / 438.0)
            let ox = pad + (availW - 896.0 * s) / 2.0 - 64.0 * s
            let oy = pad + (availH - 438.0 * s) / 2.0 - 300.0 * s

            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: ox + x * s, y: oy + y * s)
            }

            // Rounded-rectangle notch pill (r = 160) with tight filleted camera cutout
            var shell = Path()
            shell.move(to: pt(224, 300))
            shell.addLine(to: pt(396, 300))
            shell.addQuadCurve(to: pt(414, 316), control: pt(410, 300))
            shell.addCurve(to: pt(512, 398), control1: pt(424, 356), control2: pt(462, 398))
            shell.addCurve(to: pt(610, 316), control1: pt(562, 398), control2: pt(600, 356))
            shell.addQuadCurve(to: pt(628, 300), control: pt(614, 300))
            shell.addLine(to: pt(800, 300))
            shell.addArc(
                center: pt(800, 460),
                radius: 160 * s,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            shell.addLine(to: pt(960, 578))
            shell.addArc(
                center: pt(800, 578),
                radius: 160 * s,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            shell.addLine(to: pt(224, 738))
            shell.addArc(
                center: pt(224, 578),
                radius: 160 * s,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            shell.addLine(to: pt(64, 460))
            shell.addArc(
                center: pt(224, 460),
                radius: 160 * s,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
            shell.closeSubpath()

            context.fill(
                shell,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.130, green: 0.135, blue: 0.150),
                        Color(red: 0.035, green: 0.035, blue: 0.042)
                    ]),
                    startPoint: pt(512, 300),
                    endPoint: pt(512, 738)
                )
            )
            context.stroke(
                shell,
                with: .color(Color.white.opacity(colorScheme == .dark ? 0.22 : 0.08)),
                style: StrokeStyle(lineWidth: 0.6, lineJoin: .round)
            )

            var prompt = Path()
            prompt.move(to: pt(264, 454))
            prompt.addLine(to: pt(352, 528))
            prompt.addLine(to: pt(264, 602))
            prompt.move(to: pt(400, 614))
            prompt.addLine(to: pt(482, 614))
            context.stroke(
                prompt,
                with: .color(.white),
                style: StrokeStyle(lineWidth: max(1.15, 32 * s), lineCap: .round, lineJoin: .round)
            )

            var sparkle = Path()
            sparkle.move(to: pt(790, 410))
            sparkle.addCurve(to: pt(894, 514), control1: pt(804, 472), control2: pt(832, 500))
            sparkle.addCurve(to: pt(790, 618), control1: pt(832, 528), control2: pt(804, 556))
            sparkle.addCurve(to: pt(686, 514), control1: pt(776, 556), control2: pt(748, 528))
            sparkle.addCurve(to: pt(790, 410), control1: pt(748, 500), control2: pt(776, 472))
            sparkle.closeSubpath()

            context.fill(
                sparkle,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.573, green: 0.906, blue: 0.333),
                        Color(red: 0.208, green: 0.722, blue: 0.373)
                    ]),
                    startPoint: pt(710, 404),
                    endPoint: pt(886, 610)
                )
            )
        }
        .frame(width: width, height: height)
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2.5) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control()
        }
        .padding(.vertical, 9)
    }
}

struct SettingsHairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.07))
            .frame(height: 0.5)
    }
}

/// Sleek dark MacBook screen-top stage shared by Appearance and Floating Bar previews.
struct DarkPreviewStage<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.15),
                    Color(red: 0.11, green: 0.14, blue: 0.21),
                    Color(red: 0.07, green: 0.09, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle ambient top light glow for depth
            RadialGradient(
                colors: [
                    Color(red: 0.30, green: 0.52, blue: 0.96).opacity(0.16),
                    Color.clear
                ],
                center: .top,
                startRadius: 10,
                endRadius: 210
            )

            content()
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
    }
}

struct SettingsSegmentedControl<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    var darkAppearance: Bool = false
    var fixedWidth: CGFloat? = nil
    var equalWidth: Bool = false
    let titleProvider: (Item) -> String
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var usesDarkStyle: Bool {
        darkAppearance || colorScheme == .dark
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection == item
                Button {
                    if reduceMotion {
                        selection = item
                    } else {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selection = item
                        }
                    }
                } label: {
                    Text(titleProvider(item))
                        .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(textColor(isSelected: isSelected))
                        .lineLimit(1)
                        .frame(maxWidth: equalWidth ? .infinity : nil)
                        .padding(.horizontal, equalWidth ? 4 : 11)
                        .frame(height: 22)
                        .background(
                            Capsule()
                                .fill(thumbFill(isSelected: isSelected))
                                .shadow(
                                    color: Color.black.opacity(isSelected ? (usesDarkStyle ? 0.30 : 0.11) : 0),
                                    radius: 2,
                                    y: 0.75
                                )
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(thumbBorder(isSelected: isSelected), lineWidth: 0.5)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .frame(width: fixedWidth, height: 26)
        .background(
            Capsule()
                .fill(usesDarkStyle ? Color.white.opacity(0.09) : Color.black.opacity(0.065))
        )
    }

    private func textColor(isSelected: Bool) -> Color {
        if usesDarkStyle {
            return isSelected ? .white : .white.opacity(0.62)
        }
        return isSelected ? .primary : .secondary
    }

    private func thumbFill(isSelected: Bool) -> Color {
        guard isSelected else { return .clear }
        return usesDarkStyle ? Color.white.opacity(0.18) : Color.white
    }

    private func thumbBorder(isSelected: Bool) -> Color {
        guard isSelected else { return .clear }
        return usesDarkStyle ? Color.white.opacity(0.14) : Color.black.opacity(0.04)
    }
}

enum SettingsActionTone {
    case prominent(Color = .accentColor)
    case secondary
    case destructive

    func fillColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .prominent(let color): return color
        case .secondary:
            return colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
        case .destructive: return Color.red
        }
    }

    var textColor: Color {
        switch self {
        case .prominent, .destructive: return .white
        case .secondary: return .primary
        }
    }

    func borderColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .prominent, .destructive: return .clear
        case .secondary:
            return colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10)
        }
    }

    var isSecondary: Bool {
        if case .secondary = self { return true }
        return false
    }
}

struct SettingsActionButton: View {
    let title: String
    var systemImage: String? = nil
    var tone: SettingsActionTone = .secondary
    var fixedWidth: CGFloat? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.72)
                        .tint(tone.textColor)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(tone.textColor)
            .padding(.horizontal, 12)
            .frame(width: fixedWidth, height: 26)
            .background(
                Capsule()
                    .fill(
                        tone.isSecondary && isHovered && !isDisabled
                            ? (colorScheme == .dark ? Color.white.opacity(0.12) : Color(red: 0.965, green: 0.965, blue: 0.975))
                            : tone.fillColor(for: colorScheme).opacity(isHovered && !isDisabled ? 0.88 : 1.0)
                    )
                    .shadow(
                        color: Color.black.opacity(tone.isSecondary && colorScheme != .dark ? 0.045 : 0),
                        radius: 1.5,
                        y: 0.75
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(tone.borderColor(for: colorScheme), lineWidth: 0.5)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.45 : 1.0)
        .onHover { isHovered = $0 }
    }
}

struct SettingsIconButton: View {
    let systemName: String
    var tint: Color = .secondary
    var isActive: Bool = false
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var helpText: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.72)
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(isActive ? Color.accentColor : tint)
                }
            }
            .frame(width: 26, height: 26)
            .background(
                Circle()
                    .fill(
                        isActive
                            ? Color.accentColor.opacity(0.14)
                            : (isHovered && !isDisabled ? Color.primary.opacity(0.065) : Color.clear)
                    )
            )
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.45 : 1.0)
        .onHover { isHovered = $0 }
        .help(helpText ?? "")
    }
}

/// Custom capsule toggle switch that keeps its vibrant accent-blue active track
/// even when the Settings window temporarily loses key focus (for example, to
/// a screenshot utility or after a click inside the `.nonactivatingPanel` notch).
struct SettingsCapsuleToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        SwitchBody(configuration: configuration)
    }

    private struct SwitchBody: View {
        let configuration: Configuration
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private var trackFill: Color {
            if configuration.isOn {
                return Color.accentColor
            }
            return colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.13)
        }

        var body: some View {
            Button {
                configuration.isOn.toggle()
            } label: {
                Capsule()
                    .fill(trackFill)
                    .frame(width: 36, height: 20)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .shadow(color: Color.black.opacity(0.16), radius: 1.5, y: 0.75)
                            .padding(2)
                    }
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.20, dampingFraction: 0.82),
                        value: configuration.isOn
                    )
            }
            .buttonStyle(.plain)
            .opacity(isEnabled ? 1.0 : 0.45)
            .contentShape(Capsule())
        }
    }
}
