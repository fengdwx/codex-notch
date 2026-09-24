import AppKit
import SwiftUI
import XCTest
@testable import CodexNotch

final class NotchHeightViewTests: XCTestCase {
    @MainActor
    func testBothQuotaIndicatorsStayCenteredAtMeasuredHeights() throws {
        try checkHostedIndicators(hasFiveHourWindow: true)
    }

    @MainActor
    func testStatusMarkAndWeeklyQuotaStayCenteredAtMeasuredHeights() throws {
        try checkHostedIndicators(hasFiveHourWindow: false)
    }

    @MainActor
    private func checkHostedIndicators(hasFiveHourWindow: Bool) throws {
        _ = NSApplication.shared
        let suite = "NotchHeightViewTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(QuotaDisplayStyle.clockwiseRing.rawValue, forKey: QuotaDisplayStyle.storageKey)
        defaults.set(StatusIconStyle.codex.rawValue, forKey: StatusIconStyle.storageKey)

        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let session = SessionActivity(
            threadID: "height-fixture", turnID: "height-fixture", title: "Height fixture",
            cwd: "/demo", originator: nil, startedAt: now, lastActivityAt: now
        )
        let usage = UsageSnapshot(windows: [
            UsageWindow(id: "weekly", kind: .weekly, usedPercent: 40)
        ] + (hasFiveHourWindow ? [
            UsageWindow(id: "five-hour", kind: .rolling(hours: 5), usedPercent: 20)
        ] : []))

        // These are synthetic sizes, not a mapping of MacBook models. Host the
        // production view so this guard observes layout, not just geometry inputs.
        for height: CGFloat in [24, 38] {
            for expanded in [false, true] {
                let state: NotchPresentationState = expanded ? .expanded(ExpandedContent(
                    sessions: [session], conversations: [], headerConversation: nil, usage: usage
                )) : .workingCompact(primary: session, count: 1, usage: usage)
                let size = expanded ? CGSize(width: 420, height: 300 + height)
                    : CGSize(width: 257, height: height)
                let model = NotchViewModel(
                    state: state, now: now, layoutMode: .notch, cameraSafeAreaInset: height,
                    compactWidth: 257, compactHeight: height, surfaceSize: size,
                    animationsEnabled: true
                )
                let hosting = NSHostingView(rootView: NotchView(model: model)
                    .defaultAppStorage(defaults)
                    // Match a Retina notch even on a headless CI display.
                    .environment(\.displayScale, 2)
                    .frame(width: size.width, height: size.height))
                hosting.sizingOptions = []
                hosting.frame = NSRect(origin: .zero, size: size)
                hosting.layoutSubtreeIfNeeded()

                let context = "height=\(height), expanded=\(expanded), fiveHour=\(hasFiveHourWindow)"
                let leftCenter = hosting.bounds.midX - 257 / 2 + 23
                let rightCenter = hosting.bounds.midX + 257 / 2 - 23
                let gradients = descendants(of: QuotaGradientLayerView.self, in: hosting)
                // Each quota has a gradient arc and a concentric inner glint.
                XCTAssertEqual(gradients.count, hasFiveHourWindow ? 4 : 2, context)
                let leftGradients = gradients.filter {
                    $0.convert($0.bounds, to: hosting).midX < hosting.bounds.midX
                }
                XCTAssertEqual(leftGradients.count, hasFiveHourWindow ? 2 : 0, context)
                for gradient in gradients {
                    let rect = gradient.convert(gradient.bounds, to: hosting)
                    assertIndicator(rect, centerX: rect.midX < hosting.bounds.midX ? leftCenter : rightCenter,
                                    height: height, diameter: 22, context: context)
                }

                let marks = descendants(of: StatusMarkEchoLayerView.self, in: hosting)
                XCTAssertEqual(marks.count, hasFiveHourWindow ? 0 : 1, context)
                for mark in marks {
                    // The running echo shares the selected status artwork's frame.
                    assertIndicator(mark.convert(mark.bounds, to: hosting), centerX: leftCenter,
                                    height: height, diameter: 18, context: context)
                }
            }
        }
    }

    @MainActor
    private func descendants<T: NSView>(of type: T.Type, in view: NSView) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants(of: type, in: $0) }
    }

    private func assertIndicator(
        _ rect: NSRect, centerX: CGFloat, height: CGFloat, diameter: CGFloat, context: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(rect.midX, centerX, accuracy: 0.01, context, file: file, line: line)
        XCTAssertEqual(rect.midY, height / 2, accuracy: 0.01, context, file: file, line: line)
        XCTAssertEqual(rect.width, diameter, accuracy: 0.01, context, file: file, line: line)
        XCTAssertEqual(rect.height, diameter, accuracy: 0.01, context, file: file, line: line)
        XCTAssertGreaterThanOrEqual(rect.minY, 0, context, file: file, line: line)
        XCTAssertLessThanOrEqual(rect.maxY, height, context, file: file, line: line)
    }
}
