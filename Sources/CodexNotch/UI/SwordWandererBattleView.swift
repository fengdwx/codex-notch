import AppKit
import SwiftUI

enum SwordWandererAsset {
    static let columns = 8
    static let rows = 11

    static let atlasImage: NSImage? = {
        guard let url = AppResources.bundle()?.url(
            forResource: "sword-wanderer",
            withExtension: "webp"
        ) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    static let swordImage = image(named: "pixel-sword", extension: "png")
    static let slimeImage = image(named: "pixel-slime", extension: "png")
    static let hitSparkImage = image(
        named: "pixel-hit-spark",
        extension: "png"
    )

    static let pixelSize: CGSize = {
        guard let image = atlasImage,
              let representation = image.representations.first else {
            return .zero
        }
        return CGSize(
            width: representation.pixelsWide,
            height: representation.pixelsHigh
        )
    }()

    private static func image(named name: String, extension fileExtension: String) -> NSImage? {
        guard let url = AppResources.bundle()?.url(
            forResource: name,
            withExtension: fileExtension
        ) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

struct SwordWandererBattleSample: Equatable {
    let warriorFrame: Int
    let warriorOffsetX: CGFloat
    let warriorOffsetY: CGFloat
    let swordAngle: Double
    let swordOpacity: CGFloat
    let slashOpacity: CGFloat
    let slimes: [SwordWandererSlimeSample]

    var warriorRow: Int { warriorFrame / SwordWandererAsset.columns }
    var warriorColumn: Int { warriorFrame % SwordWandererAsset.columns }
}

struct SwordWandererSlimeSample: Equatable, Identifiable {
    let id: Int
    let age: TimeInterval
    let x: CGFloat
    let y: CGFloat
    let scaleX: CGFloat
    let scaleY: CGFloat
    let bodyOpacity: CGFloat
    let impactOpacity: CGFloat
    let burstProgress: CGFloat
    let scoreOpacity: CGFloat
    let scoreRise: CGFloat
}

enum SwordWandererBattleLayout {
    static let focusedForwardFrame = 12
    static let forwardGazeFrames: Set<Int> = Set(8...15)
    static let swordPivotX: CGFloat = 29
    static let swordBladeLength: CGFloat = 14
    static let swordTotalWidth: CGFloat = 17
    static let swordHeight: CGFloat = 6
    static let impactX: CGFloat = 48
    static let slimeEntryX: CGFloat = 128
    static let slimeWidth: CGFloat = 12
    static let slimeHeight: CGFloat = 9
    static let hitSparkSize: CGFloat = 10
}

enum SwordWandererBattleMotion {
    static let spawnInterval: TimeInterval = 1.25
    static let impactTime: TimeInterval = 1.02
    static let lifeDuration: TimeInterval = 1.50
    static let timelineFramesPerSecond: Double = 12
    static let timelineInterval: TimeInterval = 1.0 / timelineFramesPerSecond

    static func shouldAnimate(
        animationsEnabled: Bool,
        reduceMotion: Bool
    ) -> Bool {
        animationsEnabled && !reduceMotion
    }

    static func sample(at elapsed: TimeInterval) -> SwordWandererBattleSample {
        let safeElapsed = max(0, elapsed)
        let phase = positiveRemainder(safeElapsed, spawnInterval)
        let pose = warriorPose(at: phase)
        let newestSpawn = Int(floor(safeElapsed / spawnInterval))
        let slimes = ((newestSpawn - 1)...newestSpawn).compactMap { index in
            slimeSample(
                id: index,
                age: safeElapsed - Double(index) * spawnInterval
            )
        }

        return SwordWandererBattleSample(
            warriorFrame: pose.frame,
            warriorOffsetX: pose.offsetX,
            warriorOffsetY: pose.offsetY,
            swordAngle: pose.swordAngle,
            swordOpacity: pose.swordOpacity,
            slashOpacity: pose.slashOpacity,
            slimes: slimes
        )
    }

    private static func warriorPose(
        at phase: TimeInterval
    ) -> (
        frame: Int,
        offsetX: CGFloat,
        offsetY: CGFloat,
        swordAngle: Double,
        swordOpacity: CGFloat,
        slashOpacity: CGFloat
    ) {
        if phase < 0.28 {
            let progress = eased(CGFloat(phase / 0.28))
            return (
                frame: SwordWandererBattleLayout.focusedForwardFrame,
                offsetX: -0.4 * progress,
                offsetY: interpolate(0, 0.4, progress),
                swordAngle: 12,
                swordOpacity: 1,
                slashOpacity: 0
            )
        }

        if phase < 0.44 {
            return (
                frame: 10,
                offsetX: -0.7,
                offsetY: 1.0,
                swordAngle: -86,
                swordOpacity: 1,
                slashOpacity: 0
            )
        }

        if phase < 0.78 {
            return (
                frame: 10,
                offsetX: -0.7,
                offsetY: 1.0,
                swordAngle: -86,
                swordOpacity: 1,
                slashOpacity: 0
            )
        }

        if phase < 0.84 {
            return (
                frame: 13,
                offsetX: 1.0,
                offsetY: -0.4,
                swordAngle: -86,
                swordOpacity: 1,
                slashOpacity: 0
            )
        }

        if phase < 0.96 {
            let progress = CGFloat((phase - 0.84) / 0.12)
            return (
                frame: 14,
                offsetX: interpolate(1.0, 2.5, progress),
                offsetY: interpolate(-0.4, -0.1, progress),
                swordAngle: interpolate(-86, 14, progress),
                swordOpacity: 1,
                slashOpacity: 0
            )
        }

        if phase < 1.10 {
            let progress = eased(CGFloat((phase - 0.96) / 0.14))
            return (
                frame: 14,
                offsetX: interpolate(2.5, 1.8, progress),
                offsetY: interpolate(-0.1, 0, progress),
                swordAngle: interpolate(14, 20, progress),
                swordOpacity: 1,
                slashOpacity: sin(progress * .pi)
            )
        }

        let progress = min(1, CGFloat((phase - 1.10) / 0.15))
        return (
            frame: progress < 0.55
                ? 13
                : SwordWandererBattleLayout.focusedForwardFrame,
            offsetX: 1.8 - progress * 1.8,
            offsetY: 0,
            swordAngle: interpolate(20, 12, progress),
            swordOpacity: 1,
            slashOpacity: 0
        )
    }

    private static func slimeSample(
        id: Int,
        age: TimeInterval
    ) -> SwordWandererSlimeSample? {
        guard age >= 0, age <= lifeDuration else { return nil }

        if age < impactTime {
            let progress = min(1, CGFloat(age / impactTime))
            let horizontalProgress = 1 - pow(1 - progress, 1.35)
            let bounce = abs(sin(progress * .pi * 2))
            let landing = 1 - min(1, bounce * 5)
            let airborneStretch = min(1, bounce * 1.15)

            return SwordWandererSlimeSample(
                id: id,
                age: age,
                x: interpolate(
                    SwordWandererBattleLayout.slimeEntryX,
                    SwordWandererBattleLayout.impactX,
                    horizontalProgress
                ),
                y: 21 - bounce * 7,
                scaleX: 1 + landing * 0.28 - airborneStretch * 0.05,
                scaleY: 1 - landing * 0.30 + airborneStretch * 0.10,
                bodyOpacity: 1,
                impactOpacity: 0,
                burstProgress: 0,
                scoreOpacity: 0,
                scoreRise: 0
            )
        }

        let impactAge = CGFloat(age - impactTime)
        let burstProgress = min(1, impactAge / 0.28)
        let scoreProgress = min(1, impactAge / 0.43)
        let scoreAppear = min(1, impactAge / 0.06)

        return SwordWandererSlimeSample(
            id: id,
            age: age,
            x: SwordWandererBattleLayout.impactX,
            y: 21,
            scaleX: 1.55 - burstProgress * 0.40,
            scaleY: 0.42 + burstProgress * 0.28,
            bodyOpacity: max(0, 1 - burstProgress * 1.3),
            impactOpacity: max(0, 1 - impactAge / 0.16),
            burstProgress: burstProgress,
            scoreOpacity: scoreAppear * max(0, 1 - scoreProgress),
            scoreRise: scoreProgress * 7
        )
    }

    private static func positiveRemainder(
        _ value: TimeInterval,
        _ divisor: TimeInterval
    ) -> TimeInterval {
        let result = value.truncatingRemainder(dividingBy: divisor)
        return result >= 0 ? result : result + divisor
    }

    private static func eased(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    private static func interpolate(
        _ start: CGFloat,
        _ end: CGFloat,
        _ progress: CGFloat
    ) -> CGFloat {
        start + (end - start) * progress
    }

    private static func interpolate(
        _ start: Double,
        _ end: Double,
        _ progress: CGFloat
    ) -> Double {
        start + (end - start) * Double(progress)
    }
}

struct SwordWandererBattleView: View {
    let compactHeight: CGFloat

    @Environment(\.notchMotionEnabled) private var motionEnabled

    var body: some View {
        Group {
            if motionEnabled {
                TimelineView(
                    // The floating panel is not a key window, so use an
                    // explicit low-frequency timer instead of a display-link
                    // schedule that can be throttled while it is idle.
                    .periodic(
                        from: .now,
                        by: SwordWandererBattleMotion.timelineInterval
                    )
                ) { context in
                    scene(
                        sample: SwordWandererBattleMotion.sample(
                            at: context.date.timeIntervalSinceReferenceDate
                        )
                    )
                }
            } else {
                scene(sample: SwordWandererBattleMotion.sample(at: 0.48))
            }
        }
        .accessibilityHidden(true)
    }

    private func scene(sample: SwordWandererBattleSample) -> some View {
        GeometryReader { proxy in
            let height = min(compactHeight, proxy.size.height)
            let spriteHeight = max(1, height - 1)
            let warriorCenterX = CGFloat(18) + sample.warriorOffsetX
            let warriorCenterY = height / 2 + sample.warriorOffsetY
            let swordPivot = CGPoint(
                x: SwordWandererBattleLayout.swordPivotX
                    + sample.warriorOffsetX,
                y: max(13, height * 0.58 + sample.warriorOffsetY * 0.65)
            )

            ZStack(alignment: .topLeading) {
                ForEach(sample.slimes) { slime in
                    SwordWandererSlimeView(sample: slime)
                }

                SwordWandererSpriteFrame(
                    row: sample.warriorRow,
                    column: sample.warriorColumn,
                    height: spriteHeight
                )
                .position(x: warriorCenterX, y: warriorCenterY)

                SwordWandererSword(
                    angle: sample.swordAngle,
                    opacity: sample.swordOpacity
                )
                .position(
                    x: swordPivot.x
                        + SwordWandererBattleLayout.swordTotalWidth / 2,
                    y: swordPivot.y
                )

                SwordWandererHitSpark(opacity: sample.slashOpacity)
                    .position(
                        x: SwordWandererBattleLayout.impactX,
                        y: swordPivot.y
                    )
            }
            .frame(width: proxy.size.width, height: height)
            .clipped()
        }
    }
}

private struct SwordWandererSpriteFrame: View {
    let row: Int
    let column: Int
    let height: CGFloat

    var body: some View {
        let frameWidth = height * 192 / 208

        Group {
            if let atlas = SwordWandererAsset.atlasImage {
                Image(nsImage: atlas)
                    .resizable()
                    .interpolation(.none)
                    .frame(
                        width: frameWidth * CGFloat(SwordWandererAsset.columns),
                        height: height * CGFloat(SwordWandererAsset.rows),
                        alignment: .topLeading
                    )
                    .offset(
                        x: -frameWidth * CGFloat(column),
                        y: -height * CGFloat(row)
                    )
            }
        }
        .frame(width: frameWidth, height: height, alignment: .topLeading)
        .clipped()
    }
}

private struct SwordWandererSword: View {
    let angle: Double
    let opacity: CGFloat

    var body: some View {
        Group {
            if let image = SwordWandererAsset.swordImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
            }
        }
        .frame(
            width: SwordWandererBattleLayout.swordTotalWidth,
            height: SwordWandererBattleLayout.swordHeight,
            alignment: .leading
        )
        .rotationEffect(.degrees(angle), anchor: .leading)
        .opacity(opacity)
    }
}

private struct SwordWandererHitSpark: View {
    let opacity: CGFloat

    var body: some View {
        Group {
            if let image = SwordWandererAsset.hitSparkImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
            }
        }
        .frame(
            width: SwordWandererBattleLayout.hitSparkSize,
            height: SwordWandererBattleLayout.hitSparkSize
        )
        .opacity(opacity)
    }
}

private struct SwordWandererSlimeView: View {
    let sample: SwordWandererSlimeSample

    var body: some View {
        ZStack {
            if let image = SwordWandererAsset.slimeImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .frame(
                        width: SwordWandererBattleLayout.slimeWidth,
                        height: SwordWandererBattleLayout.slimeHeight
                    )
                    .scaleEffect(
                        x: sample.scaleX,
                        y: sample.scaleY,
                        anchor: .bottom
                    )
                    .opacity(sample.bodyOpacity)
            }

            if sample.impactOpacity > 0 {
                SwordWandererHitSpark(opacity: sample.impactOpacity)
            }

            Text("+1")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.43, green: 0.91, blue: 0.58))
                .offset(y: -11 - sample.scoreRise)
                .opacity(sample.scoreOpacity)
        }
        .position(x: sample.x, y: sample.y)
    }
}
