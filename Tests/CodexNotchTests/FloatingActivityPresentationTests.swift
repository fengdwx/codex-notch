import AppKit
import SwiftUI
import XCTest
@testable import CodexNotch

final class FloatingActivityPresentationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    @MainActor
    func testEveryCenterStyleHasDistinctShapesWithoutColorOrAnimation() throws {
        _ = NSApplication.shared
        for language in [AppLanguage.english, .chinese] {
            for style in FloatingCenterStyle.allCases {
                let silhouettes = try [QuotaRingActivity.running, .idle, .completed].map { activity in
                    let bitmap = try render(
                        FloatingCenterContent(
                            style: style, customText: "Keep going", activity: activity,
                            startedAt: now.addingTimeInterval(-138), now: now, isExpanded: false
                        )
                        .environment(\.notchMotionEnabled, false)
                        .environment(\.notchAppLanguage, language)
                        .frame(width: 136, height: 30)
                    )
                    XCTAssertEqual(bitmap.pixelsWide, 272)
                    XCTAssertEqual(bitmap.pixelsHigh, 60)
                    // Alpha silhouettes discard RGB entirely: a color change
                    // alone cannot make identical idle/completed text pass.
                    return mask(bitmap, region: CGRect(x: 0, y: 0, width: 272, height: 60)) {
                        $0.alphaComponent > 0.3
                    }
                }
                assertDistinct(silhouettes, message: "\(style), \(language), motion off")
            }
        }
    }

    @MainActor
    func testPreviewRetainsCenterCuesWithHiddenOrQuotaLeftLaneAndStableWeeklyPosition() throws {
        _ = NSApplication.shared
        for style in FloatingCenterStyle.allCases {
            for (iconStyle, fiveHour) in [(StatusIconStyle.off, false), (.codex, true)] {
                let bitmaps = try FloatingPreviewState.allCases.map { state in
                    try render(FloatingBarSettingsPreview(
                        style: style, customText: "Keep going", state: state,
                        language: .english, animationsEnabled: false,
                        quotaStyle: .clockwiseRing, iconStyle: iconStyle,
                        showsFiveHourQuota: fiveHour
                    ).sampleBar)
                }
                for bitmap in bitmaps {
                    XCTAssertEqual(bitmap.pixelsWide, 424)
                    XCTAssertEqual(bitmap.pixelsHigh, 60)
                    if iconStyle == .off {
                        XCTAssertEqual(bitmap.colorAt(x: 8, y: 30)?.alphaComponent, 0,
                                       "Off must crop the preview's left lane like the live surface")
                    }
                }
                let centers = bitmaps.map { bitmap in
                    mask(bitmap, region: CGRect(x: 76, y: 0, width: 272, height: 60)) {
                        max($0.redComponent, $0.greenComponent, $0.blueComponent) > 0.35
                    }
                }
                assertDistinct(centers, message: "\(style), left=\(iconStyle), fiveHour=\(fiveHour)")
                let quotaRegions = bitmaps.map { bitmap in
                    mask(bitmap, region: CGRect(x: 348, y: 0, width: 60, height: 60)) {
                        max($0.redComponent, $0.greenComponent, $0.blueComponent) > 0.35
                    }
                }
                XCTAssertEqual(quotaRegions[0], quotaRegions[1], "Status must not shift or repaint fixture quota")
                XCTAssertEqual(quotaRegions[1], quotaRegions[2], "Completion keeps the weekly lane unchanged")
            }
        }
    }

    func testElapsedUsesExplicitRestingTextAndCompletionPreviewExplainsItsPurpose() {
        for language in [AppLanguage.english, .chinese] {
            let titles = [QuotaRingActivity.running, .idle, .completed].map {
                FloatingActivityPresentation.title(for: $0, language: language)
            }
            XCTAssertEqual(Set(titles).count, 3)
            XCTAssertEqual(FloatingPreviewState.completed.title(for: language),
                           language == .english ? "Completion cue" : "完成提示")
        }
        XCTAssertEqual(FloatingActivityPresentation.title(for: .idle, language: .chinese), "空闲")
        XCTAssertEqual(FloatingActivityPresentation.title(for: .completed, language: .chinese), "刚完成")
        XCTAssertFalse(FloatingCenterStyle.elapsed.usesCustomText)
        XCTAssertTrue(FloatingCenterStyle.signature.usesCustomText)
        XCTAssertTrue(FloatingCenterStyle.orbit.usesCustomText)
    }

    func testExpandedHeaderDoesNotDeriveCompletionFromRetainedHistory() {
        let session = fixtureSession()
        let history = ConversationSummary(session: session, activity: .completed(completedAt: now))
        var content = ExpandedContent(sessions: [], conversations: [history], headerConversation: history, usage: nil)
        XCTAssertEqual(ExpandedHeaderActivity.resolve(content), .idle)
        content = ExpandedContent(sessions: [session], conversations: [history], headerConversation: history, usage: nil)
        XCTAssertEqual(ExpandedHeaderActivity.resolve(content), .running)
        content.completionFeedback = CompletedSession(session: session, completedAt: now)
        XCTAssertEqual(ExpandedHeaderActivity.resolve(content), .completed,
                       "The same brief cue has priority in compact and expanded headers")
        content.completionFeedback = nil
        XCTAssertEqual(ExpandedHeaderActivity.resolve(content), .running,
                       "Expiry must reveal work that was already running")
    }

    @MainActor
    func testStoppedHistoryHasNeutralMarkAndHonestLocalizedText() throws {
        _ = NSApplication.shared
        for language in [AppLanguage.english, .chinese] {
            let stopped = ConversationRowView(
                conversation: ConversationSummary(session: fixtureSession(), activity: .stopped(completedAt: now)),
                isPrimary: false, now: now, language: language, action: {}
            )
            XCTAssertTrue(stopped.metadataText.hasPrefix(language == .english ? "Stopped" : "已停止"))
            let bitmap = try render(stopped.frame(width: 384, height: 40).background(Color.black))
            let greenPixels = mask(bitmap, region: CGRect(x: 0, y: 0, width: 80, height: 80)) {
                $0.greenComponent > $0.redComponent + 0.15 && $0.greenComponent > $0.blueComponent + 0.05
            }.filter { $0 }.count
            XCTAssertEqual(greenPixels, 0, "An aborted turn must not inherit the green completion check")
        }
    }

    private func fixtureSession() -> SessionActivity {
        SessionActivity(threadID: "ui-fixture", turnID: "turn-1", title: "Example task", cwd: nil,
                        originator: nil, startedAt: now.addingTimeInterval(-138), lastActivityAt: now)
    }

    @MainActor
    private func render<Content: View>(_ content: Content) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        return NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
    }

    private func mask(_ bitmap: NSBitmapImageRep, region: CGRect, predicate: (NSColor) -> Bool) -> [Bool] {
        (Int(region.minY)..<Int(region.maxY)).flatMap { y in
            (Int(region.minX)..<Int(region.maxX)).map { x in
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
                return predicate(color)
            }
        }
    }

    private func assertDistinct(_ masks: [[Bool]], message: String, file: StaticString = #filePath, line: UInt = #line) {
        for pair in [(0, 1), (0, 2), (1, 2)] {
            let differentPixels = zip(masks[pair.0], masks[pair.1]).filter { $0 != $1 }.count
            XCTAssertGreaterThan(differentPixels, 16, "Static states are indistinguishable: \(message)", file: file, line: line)
        }
    }
}
