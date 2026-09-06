import AppKit
import SwiftUI

enum StatusIconStyle: String, CaseIterable, Identifiable, Sendable {
    case codex
    case chatGPT = "chatgpt"

    static let storageKey = "statusIconStyle"
    static let defaultStyle: StatusIconStyle = .codex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codex: return "Codex"
        case .chatGPT: return "ChatGPT"
        }
    }

    var templateImage: NSImage? {
        switch self {
        case .codex: return CodexMarkAsset.templateImage
        case .chatGPT: return ChatGPTMarkAsset.templateImage
        }
    }

    var displayImage: NSImage? {
        self == .codex ? CodexMarkAsset.displayImage : nil
    }

    var fallbackSystemName: String {
        switch self {
        case .codex: return "terminal.fill"
        case .chatGPT: return "sparkles"
        }
    }

    static func fromStoredValue(_ rawValue: String?) -> StatusIconStyle {
        rawValue.flatMap(Self.init(rawValue:)) ?? defaultStyle
    }
}

struct StatusMark: View {
    let style: StatusIconStyle
    let size: CGFloat
    var tint = Color.white.opacity(0.96)
    var monochrome = false
    var theme: StatusIconTheme?

    var body: some View {
        Group {
            if !monochrome, style == .codex, let theme,
               let flower = style.templateImage,
               let prompt = CodexMarkAsset.promptTemplateImage {
                ZStack {
                    Image(nsImage: flower)
                        .renderingMode(.template)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .foregroundStyle(theme.flowerOutlineColor)
                    Image(nsImage: flower)
                        .renderingMode(.template)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .foregroundStyle(theme.flowerColor)
                        .scaleEffect(0.88)
                    Image(nsImage: prompt)
                        .renderingMode(.template)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .foregroundStyle(Color.white)
                }
            } else if !monochrome, let image = style.displayImage {
                Image(nsImage: image)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else if let image = style.templateImage {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .foregroundStyle(tint)
            } else {
                Image(systemName: style.fallbackSystemName)
                    .font(.system(size: size * 0.72, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
