import CoreGraphics
import XCTest
@testable import CodexNotch

final class SwordWandererBattleMotionTests: XCTestCase {
    func testBundledSwordWandererKeepsTheValidatedV2AtlasGeometry() {
        XCTAssertEqual(
            SwordWandererAsset.pixelSize,
            CGSize(width: 1_536, height: 2_288)
        )
        XCTAssertEqual(SwordWandererAsset.columns, 8)
        XCTAssertEqual(SwordWandererAsset.rows, 11)
    }

    func testBundledPixelBattleAssetsAreAvailable() {
        XCTAssertNotNil(SwordWandererAsset.swordImage)
        XCTAssertNotNil(SwordWandererAsset.slimeImage)
        XCTAssertNotNil(SwordWandererAsset.hitSparkImage)
    }

    func testNextSlimeEntersBeforeThePreviousKillScoreDisappears() {
        let sample = SwordWandererBattleMotion.sample(at: 1.30)

        XCTAssertEqual(sample.slimes.count, 2)
        XCTAssertTrue(sample.slimes.contains { $0.age < 0.10 })
        XCTAssertTrue(sample.slimes.contains { $0.scoreOpacity > 0 })
    }

    func testImpactFrameShowsSlashAndKillFeedback() {
        let sample = SwordWandererBattleMotion.sample(at: 1.08)

        XCTAssertGreaterThan(sample.slashOpacity, 0)
        XCTAssertTrue(sample.slimes.contains { $0.impactOpacity > 0 })
        XCTAssertTrue(sample.slimes.contains { $0.scoreOpacity > 0 })
    }

    func testBattleLoopKeepsTheSamePoseAtEachSpawnBoundary() {
        let first = SwordWandererBattleMotion.sample(at: 0.72)
        let next = SwordWandererBattleMotion.sample(
            at: 0.72 + SwordWandererBattleMotion.spawnInterval
        )

        XCTAssertEqual(first.warriorFrame, next.warriorFrame)
        XCTAssertEqual(first.swordAngle, next.swordAngle, accuracy: 0.001)
    }

    func testMotionPolicyHonorsBothAnimationControls() {
        XCTAssertTrue(
            SwordWandererBattleMotion.shouldAnimate(
                animationsEnabled: true,
                reduceMotion: false
            )
        )
        XCTAssertFalse(
            SwordWandererBattleMotion.shouldAnimate(
                animationsEnabled: false,
                reduceMotion: false
            )
        )
        XCTAssertFalse(
            SwordWandererBattleMotion.shouldAnimate(
                animationsEnabled: true,
                reduceMotion: true
            )
        )
    }

    func testBattleTimelineUsesAFluidButBoundedCadence() {
        XCTAssertGreaterThanOrEqual(
            SwordWandererBattleMotion.timelineFramesPerSecond,
            8
        )
        XCTAssertLessThanOrEqual(
            SwordWandererBattleMotion.timelineFramesPerSecond,
            12
        )
        XCTAssertEqual(
            SwordWandererBattleMotion.timelineInterval,
            1.0 / SwordWandererBattleMotion.timelineFramesPerSecond,
            accuracy: 0.0001
        )
    }

    func testSwordStaysProportionalToTheMenuBarCharacter() {
        XCTAssertLessThanOrEqual(
            SwordWandererBattleLayout.swordBladeLength,
            15
        )
        XCTAssertLessThanOrEqual(
            SwordWandererBattleLayout.swordTotalWidth,
            18
        )
        XCTAssertLessThanOrEqual(
            SwordWandererBattleLayout.impactX
                - SwordWandererBattleLayout.swordPivotX,
            SwordWandererBattleLayout.swordTotalWidth + 2
        )
    }

    func testWarriorKeepsForwardGazeWhileTheBodyChangesActionFrames() {
        let samples = [0.05, 0.40, 0.76, 0.96, 1.10, 1.22].map {
            SwordWandererBattleMotion.sample(at: $0)
        }

        XCTAssertTrue(
            samples.allSatisfy {
                SwordWandererBattleLayout.forwardGazeFrames.contains(
                    $0.warriorFrame
                )
            }
        )
    }

    func testWarriorTurnsIntoTheSheathAndBackIntoTheStrike() {
        let ready = SwordWandererBattleMotion.sample(at: 0.08)
        let sheathing = SwordWandererBattleMotion.sample(at: 0.38)
        let striking = SwordWandererBattleMotion.sample(at: 0.82)

        XCTAssertNotEqual(ready.warriorFrame, sheathing.warriorFrame)
        XCTAssertNotEqual(sheathing.warriorFrame, striking.warriorFrame)
        XCTAssertGreaterThan(sheathing.warriorOffsetY, ready.warriorOffsetY)
        XCTAssertLessThan(striking.warriorOffsetY, sheathing.warriorOffsetY)
    }

    func testSwordStaysRaisedUntilTheFastStrike() {
        let windup = SwordWandererBattleMotion.sample(at: 0.70)
        let strike = SwordWandererBattleMotion.sample(at: 0.95)

        XCTAssertLessThan(windup.swordAngle, -75)
        XCTAssertGreaterThan(strike.swordAngle, 0)
    }

    func testLowPixelAttackUsesFourStableKeyPoses() {
        let frames = [0.10, 0.36, 0.60, 0.82, 0.94, 1.04, 1.18].map {
            SwordWandererBattleMotion.sample(at: $0).warriorFrame
        }

        XCTAssertEqual(frames, [12, 10, 10, 13, 14, 14, 13])
        XCTAssertLessThanOrEqual(Set(frames).count, 4)
    }

    func testSwordSwingsBackwardAndForwardWithoutDisappearing() {
        let forward = SwordWandererBattleMotion.sample(at: 0.02)
        let backward = SwordWandererBattleMotion.sample(at: 0.58)
        let strike = SwordWandererBattleMotion.sample(at: 1.06)

        XCTAssertEqual(forward.swordOpacity, 1, accuracy: 0.001)
        XCTAssertEqual(backward.swordOpacity, 1, accuracy: 0.001)
        XCTAssertEqual(strike.swordOpacity, 1, accuracy: 0.001)
        XCTAssertGreaterThan(forward.swordAngle, backward.swordAngle)
        XCTAssertGreaterThan(strike.swordAngle, backward.swordAngle)
        XCTAssertLessThanOrEqual(strike.warriorOffsetX, 2.5)
    }

    func testSwordRaisesVerticallyBeforeForwardStrike() {
        let raised = SwordWandererBattleMotion.sample(at: 0.40)
        let strike = SwordWandererBattleMotion.sample(at: 1.04)

        XCTAssertLessThan(raised.swordAngle, -75)
        XCTAssertGreaterThan(strike.swordAngle, -15)
    }
}
