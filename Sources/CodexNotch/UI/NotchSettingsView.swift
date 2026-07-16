import SwiftUI

struct NotchSettingsView: View {
    @AppStorage(QuotaDisplayStyle.storageKey)
    private var quotaDisplayStyleRaw = QuotaDisplayStyle.defaultStyle.rawValue

    private var selectedStyle: QuotaDisplayStyle {
        QuotaDisplayStyle.fromStoredValue(quotaDisplayStyleRaw)
    }

    private var selectedStyleBinding: Binding<QuotaDisplayStyle> {
        Binding(
            get: { selectedStyle },
            set: { quotaDisplayStyleRaw = $0.rawValue }
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

                Text("数字固定显示在指标内；波浪球会用独立读数镜片隔开液面动画。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("刘海显示")
            }

            Section {
                QuotaStylePreview(style: selectedStyle)
            } header: {
                Text("预览")
            }

            Section {
                Label(
                    "设置会立即应用到刘海，不需要重启。右键刘海也可以打开本窗口。",
                    systemImage: "info.circle"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 430)
        .padding(.vertical, 12)
    }
}

private struct QuotaStylePreview: View {
    let style: QuotaDisplayStyle

    private let previewPercent = 58.0
    private let previewProgress = 0.58

    var body: some View {
        HStack(spacing: 14) {
            QuotaStylePreviewGraphic(
                style: style,
                progress: previewProgress
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Codex")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("本周剩余 \(Int(previewPercent))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                Text(style.subtitle)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        }
    }
}

private struct QuotaStylePreviewGraphic: View {
    let style: QuotaDisplayStyle
    let progress: CGFloat

    var body: some View {
        graphic
            .frame(width: 52, height: 52)
    }

    @ViewBuilder
    private var graphic: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.1))

            switch style {
            case .clockwiseRing:
                let trim = QuotaRingMath.clockwiseTrim(progress: progress)
                Circle()
                    .trim(from: trim.from, to: trim.to)
                    .stroke(
                        QuotaColorScale.color(for: progress * 100),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(QuotaRingMath.clockwiseStartAngleDegrees))
            case .waveBall:
                PreviewWaveShape(fillProgress: progress, phase: 0)
                    .fill(QuotaColorScale.color(for: progress * 100))
                    .clipShape(Circle())
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }

            previewQuotaValue
        }
        .frame(width: 52, height: 52)
    }

    @ViewBuilder
    private var previewQuotaValue: some View {
        if style == .waveBall {
            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.7))
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.17), lineWidth: 0.7)
                    }
                    .shadow(color: .black.opacity(0.46), radius: 1.4, x: 0, y: 0.6)
                previewQuotaText
            }
            .frame(width: 31, height: 23)
        } else {
            previewQuotaText
        }
    }

    private var previewQuotaText: some View {
        Text("58")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .monospacedDigit()
            .shadow(color: .black.opacity(0.9), radius: 1.2)
    }
}

private struct PreviewWaveShape: Shape {
    let fillProgress: CGFloat
    let phase: CGFloat

    func path(in rect: CGRect) -> Path {
        let level = rect.maxY - rect.height * min(max(fillProgress, 0), 1)
        let amplitude = rect.height * 0.08
        let samples = 24

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: level))
        for index in 0...samples {
            let fraction = CGFloat(index) / CGFloat(samples)
            let x = rect.minX + rect.width * fraction
            let y = level + sin(fraction * .pi * 2.0 + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
