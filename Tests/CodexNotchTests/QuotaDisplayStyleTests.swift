import XCTest
@testable import CodexNotch

final class QuotaDisplayStyleTests: XCTestCase {
    func testOnlyRingAndWaveStylesAreAvailable() {
        XCTAssertEqual(
            QuotaDisplayStyle.allCases,
            [.clockwiseRing, .waveBall]
        )
    }

    func testStoredValueFallsBackToClockwiseRing() {
        XCTAssertEqual(
            QuotaDisplayStyle.fromStoredValue("unknown"),
            .clockwiseRing
        )
    }

    func testStyleMetadataIsUserFacing() {
        XCTAssertEqual(QuotaDisplayStyle.clockwiseRing.title, "顺时针圆环")
        XCTAssertEqual(QuotaDisplayStyle.waveBall.title, "波浪球")
        XCTAssertFalse(QuotaDisplayStyle.waveBall.subtitle.isEmpty)
    }

    func testClockwiseRingGapExpandsFromTwelveOClockAnchor() {
        let trim = QuotaRingMath.clockwiseTrim(progress: 0.43)
        XCTAssertEqual(trim.from, 0.57, accuracy: 0.0001)
        XCTAssertEqual(trim.to, 1, accuracy: 0.0001)
        XCTAssertEqual(QuotaRingMath.clockwiseStartAngleDegrees, -90)
    }

    func testCompactAppIconUsesOpticalCorrectionInsideSharedIndicatorContainer() {
        XCTAssertEqual(NotchCompactLayout.indicatorDiameter, 22)
        XCTAssertEqual(NotchCompactLayout.appMarkSize, 18)
        XCTAssertEqual(
            NotchCompactLayout.indicatorDiameter - NotchCompactLayout.appMarkSize,
            4
        )
        XCTAssertLessThan(
            NotchCompactLayout.appMarkSize,
            NotchCompactLayout.indicatorDiameter
        )
        XCTAssertLessThanOrEqual(
            NotchCompactLayout.indicatorDiameter,
            NotchCompactLayout.indicatorLaneWidth
        )
    }

    func testCompactRingUsesAThickerStrokeWithoutChangingTheWaveBallBorder() {
        XCTAssertEqual(NotchCompactLayout.indicatorDiameter, 22)
        XCTAssertEqual(
            NotchCompactLayout.quotaIndicatorLineWidth(for: .clockwiseRing),
            2.25
        )
        XCTAssertEqual(
            NotchCompactLayout.quotaIndicatorLineWidth(for: .waveBall),
            1.75
        )
        XCTAssertLessThan(
            NotchCompactLayout.quotaIndicatorLineWidth(for: .clockwiseRing),
            NotchCompactLayout.indicatorDiameter / 4
        )
    }

    func testQuotaIndicatorMotionRunsOnlyWhileATaskIsRunning() {
        XCTAssertTrue(
            QuotaIndicatorMotion.shouldAnimate(isTaskRunning: true, reduceMotion: false)
        )
        XCTAssertFalse(
            QuotaIndicatorMotion.shouldAnimate(isTaskRunning: false, reduceMotion: false)
        )
        XCTAssertFalse(
            QuotaIndicatorMotion.shouldAnimate(isTaskRunning: true, reduceMotion: true)
        )
    }

    func testCompletionParticlesUseSymmetricFullCircleLayers() throws {
        let diameter = NotchCompactLayout.indicatorDiameter
        let lineWidth = NotchCompactLayout.quotaIndicatorLineWidth(for: .clockwiseRing)
        let inset = QuotaRingMath.containedStrokeInset(lineWidth: lineWidth)
        let strokeOuterDiameter = diameter - inset * 2 + lineWidth
        let innerParticles = QuotaIndicatorMotion.completionInnerParticles
        let outerParticles = QuotaIndicatorMotion.completionOuterParticles
        let particles = innerParticles + outerParticles
        let endpointSparks = QuotaIndicatorMotion.completionEndpointSparks
        func normalizedAngle(_ angle: Double) -> Double {
            let remainder = angle.truncatingRemainder(dividingBy: 360)
            return remainder < 0 ? remainder + 360 : remainder
        }
        let outerParticlesByAngle = Dictionary(uniqueKeysWithValues:
            outerParticles.map { (normalizedAngle($0.angleDegrees), $0) }
        )
        let endpointSparksByAngle = Dictionary(uniqueKeysWithValues:
            endpointSparks.map { (normalizedAngle($0.angleDegrees), $0) }
        )

        XCTAssertEqual(innerParticles.count, 7)
        XCTAssertEqual(outerParticles.count, 12)
        XCTAssertEqual(endpointSparks.count, 8)
        XCTAssertEqual(
            outerParticlesByAngle.keys.sorted(),
            [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330]
        )
        XCTAssertEqual(
            endpointSparksByAngle.keys.sorted(),
            [0, 45, 90, 135, 180, 225, 270, 315]
        )
        XCTAssertEqual(
            outerParticles.filter { $0.tone == .coral }.count,
            2
        )
        XCTAssertEqual(
            endpointSparks.filter { $0.tone == .coral }.count,
            2
        )
        XCTAssertFalse(innerParticles.contains { $0.tone == .coral })
        XCTAssertEqual(Set(particles.map(\.angleDegrees)).count, particles.count)
        for angle in stride(from: 0.0, to: 180.0, by: 30.0) {
            let particle = try XCTUnwrap(outerParticlesByAngle[angle])
            let opposite = try XCTUnwrap(outerParticlesByAngle[angle + 180])
            XCTAssertEqual(particle.startRadius, opposite.startRadius)
            XCTAssertEqual(particle.travelDistance, opposite.travelDistance)
            XCTAssertEqual(particle.diameter, opposite.diameter)
            XCTAssertEqual(particle.delay, opposite.delay)
            XCTAssertEqual(particle.tone, opposite.tone)
        }
        for angle in stride(from: 0.0, to: 180.0, by: 45.0) {
            let spark = try XCTUnwrap(endpointSparksByAngle[angle])
            let opposite = try XCTUnwrap(endpointSparksByAngle[angle + 180])
            XCTAssertEqual(spark.radius, opposite.radius)
            XCTAssertEqual(spark.diameter, opposite.diameter)
            XCTAssertEqual(spark.delay, opposite.delay)
            XCTAssertEqual(spark.tone, opposite.tone)
        }
        XCTAssertGreaterThanOrEqual(
            particles.map(\.diameter).min() ?? 0,
            1.8
        )
        XCTAssertLessThanOrEqual(
            particles.map(\.diameter).max() ?? 0,
            2.4
        )
        XCTAssertGreaterThanOrEqual(
            QuotaIndicatorMotion.completionParticleTravelDuration,
            0.65
        )
        XCTAssertLessThanOrEqual(
            QuotaIndicatorMotion.completionFireworkTotalDuration,
            0.9
        )
        for particle in innerParticles {
            XCTAssertLessThanOrEqual(
                particle.endRadius + particle.diameter / 2,
                diameter / 2 - lineWidth
            )
        }
        for particle in outerParticles {
            let endOffset = QuotaIndicatorMotion.completionParticleOffset(
                spec: particle,
                progress: 1
            )
            let glowRadius = QuotaIndicatorMotion.completionParticleGlowRadius(
                tone: particle.tone
            )
            XCTAssertGreaterThan(
                particle.endRadius + particle.diameter / 2,
                diameter / 2
            )
            XCTAssertLessThanOrEqual(
                endOffset.width + particle.diameter / 2 + glowRadius,
                diameter / 2 + NotchCompactLayout.quotaIndicatorScreenEdgeClearance
            )
            XCTAssertLessThanOrEqual(
                abs(endOffset.height) + particle.diameter / 2,
                NotchCompactLayout.height / 2
            )
        }
        for spark in endpointSparks {
            let offset = QuotaIndicatorMotion.completionSparkOffset(spec: spark)
            XCTAssertLessThanOrEqual(
                offset.width + spark.diameter / 2
                    + QuotaIndicatorMotion.completionSparkGlowRadius,
                diameter / 2 + NotchCompactLayout.quotaIndicatorScreenEdgeClearance
            )
            XCTAssertLessThanOrEqual(
                abs(offset.height) + spark.diameter / 2,
                NotchCompactLayout.height / 2
            )
            XCTAssertLessThanOrEqual(
                spark.delay + QuotaIndicatorMotion.completionSparkDuration,
                QuotaIndicatorMotion.completionFireworkTotalDuration
            )
        }

        let particleHorizontalBounds = outerParticles.map { particle in
            let offset = QuotaIndicatorMotion.completionParticleOffset(
                spec: particle,
                progress: 1
            )
            let reach = particle.diameter / 2
                + QuotaIndicatorMotion.completionParticleGlowRadius(
                    tone: particle.tone
                )
            return (minimum: offset.width - reach, maximum: offset.width + reach)
        }
        let sparkHorizontalBounds = endpointSparks.map { spark in
            let offset = QuotaIndicatorMotion.completionSparkOffset(spec: spark)
            let reach = spark.diameter / 2
                + QuotaIndicatorMotion.completionSparkGlowRadius
            return (minimum: offset.width - reach, maximum: offset.width + reach)
        }
        let horizontalBounds = particleHorizontalBounds + sparkHorizontalBounds
        let fireworkMinimumX = horizontalBounds.map(\.minimum).min() ?? 0
        let fireworkMaximumX = horizontalBounds.map(\.maximum).max() ?? 0
        let cameraEdgeX = -(diameter / 2
            + NotchCompactLayout.quotaIndicatorCameraClearance)
        let screenEdgeX = diameter / 2
            + NotchCompactLayout.quotaIndicatorScreenEdgeClearance

        XCTAssertLessThanOrEqual(fireworkMaximumX - fireworkMinimumX, 32)
        XCTAssertLessThan(fireworkMinimumX, cameraEdgeX)
        XCTAssertEqual(
            abs(fireworkMinimumX),
            fireworkMaximumX,
            accuracy: 0.01
        )
        XCTAssertGreaterThanOrEqual(screenEdgeX - fireworkMaximumX, 8)

        XCTAssertEqual(
            QuotaIndicatorMotion.completionParticleProgress(elapsed: -1, delay: 0),
            0
        )
        XCTAssertGreaterThan(
            QuotaIndicatorMotion.completionParticleOpacity(progress: 0.35),
            0.7
        )
        XCTAssertGreaterThanOrEqual(
            QuotaIndicatorMotion.completionParticleOpacity(progress: 0.55),
            0.95
        )
        XCTAssertEqual(QuotaIndicatorMotion.completionParticleOpacity(progress: 1), 0)
        XCTAssertLessThanOrEqual(
            QuotaIndicatorMotion.completionParticleScale(progress: 0),
            0.75
        )
        XCTAssertEqual(
            QuotaIndicatorMotion.completionParticleScale(progress: 0.22),
            1,
            accuracy: 0.0001
        )
        XCTAssertGreaterThanOrEqual(
            QuotaIndicatorMotion.completionParticleScale(progress: 1),
            0.8
        )
        XCTAssertEqual(
            QuotaIndicatorMotion.completionIgnitionOpacity(progress: 0),
            0
        )
        XCTAssertGreaterThan(
            QuotaIndicatorMotion.completionIgnitionOpacity(progress: 0.5),
            0.9
        )
        XCTAssertEqual(
            QuotaIndicatorMotion.completionIgnitionOpacity(progress: 1),
            0,
            accuracy: 0.0001
        )
        XCTAssertGreaterThan(
            QuotaIndicatorMotion.completionSparkOpacity(progress: 0.5),
            0.9
        )
        XCTAssertEqual(
            QuotaIndicatorMotion.completionSparkOpacity(progress: 1),
            0
        )
        XCTAssertEqual(strokeOuterDiameter, diameter, accuracy: 0.0001)
    }

    func testRunningRingGradientCompletesOneFullOrbit() {
        XCTAssertEqual(QuotaRingGradientMotion.restingAngle, -90)
        XCTAssertEqual(QuotaRingGradientMotion.flowingAngle, 270)
        XCTAssertEqual(
            QuotaRingGradientMotion.flowingAngle - QuotaRingGradientMotion.restingAngle,
            360
        )
        XCTAssertGreaterThan(QuotaRingGradientMotion.duration, 0)
    }

    func testRunningRingGradientChangesAngleAcrossAnimationTimeline() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let quarterTurn = start.addingTimeInterval(
            QuotaRingGradientMotion.duration / 4
        )

        XCTAssertEqual(
            QuotaRingGradientMotion.angle(at: start, isAnimating: true),
            QuotaRingGradientMotion.restingAngle,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            QuotaRingGradientMotion.angle(at: quarterTurn, isAnimating: true),
            0,
            accuracy: 0.0001
        )
        XCTAssertNotEqual(
            QuotaRingGradientMotion.angle(at: start, isAnimating: true),
            QuotaRingGradientMotion.angle(at: quarterTurn, isAnimating: true)
        )
    }

    func testStoppedOrReducedMotionRingKeepsGradientAtRest() {
        let later = Date(timeIntervalSinceReferenceDate: 123.45)

        XCTAssertEqual(
            QuotaRingGradientMotion.angle(at: later, isAnimating: false),
            QuotaRingGradientMotion.restingAngle
        )
    }

    func testStoppedRingUsesSolidColorWhileRunningRingUsesGradient() {
        XCTAssertEqual(QuotaRingAppearance.colorMode(for: .running), .gradient)
        XCTAssertEqual(QuotaRingAppearance.colorMode(for: .idle), .solid)
        XCTAssertEqual(QuotaRingAppearance.colorMode(for: .completed), .solid)
    }

    func testRecentConversationLimitOffersZeroThroughFiveAndFallsBackToTwo() {
        XCTAssertEqual(
            RecentConversationLimit.allCases.map(\.rawValue),
            [0, 1, 2, 3, 4, 5]
        )
        XCTAssertEqual(
            RecentConversationLimit.fromStoredValue(99),
            .two
        )
    }

    func testRecentConversationLimitZeroHasLocalizedTitles() {
        XCTAssertEqual(
            RecentConversationLimit.none.title(for: .chinese),
            "0 条"
        )
        XCTAssertEqual(
            RecentConversationLimit.none.title(for: .english),
            "0 conversations"
        )
    }

    func testAppLanguageOffersChineseAndEnglishAndFallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.allCases, [.chinese, .english])
        XCTAssertEqual(AppLanguage.fromStoredValue("en"), .english)
        XCTAssertEqual(AppLanguage.fromStoredValue("unknown"), .english)
        XCTAssertEqual(AppLanguage.fromStoredValue(nil), .english)
        XCTAssertEqual(
            AppLanguage.english.localized(chinese: "中文", english: "English"),
            "English"
        )
    }

    func testVisibleNotchSurfaceIsAlwaysBlackAndHiddenCanvasStaysClear() {
        XCTAssertEqual(
            NotchSurfaceMaterial.resolve(isHidden: false),
            .black
        )
        XCTAssertEqual(
            NotchSurfaceMaterial.resolve(isHidden: true),
            .clear
        )
    }

}
