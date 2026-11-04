import AppKit
import SwiftUI
import XCTest
@testable import CodexNotch

/// FLOATING-STYLES-062: rendered static shapes remain readable without motion.
final class FloatingStyleRefinementTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    @MainActor
    func testSignatureMarksUseOneSlotWithRunningBarsAndHorizontalIdleCue() throws {
        _ = NSApplication.shared
        let running = try render(FloatingActivityMark(activity: .running))
        let idle = try render(FloatingActivityMark(activity: .idle))
        let completed = try render(FloatingActivityMark(activity: .completed))
        for bitmap in [running, idle, completed] {
            XCTAssertEqual(bitmap.pixelsWide, 32)
            XCTAssertEqual(bitmap.pixelsHigh, 32)
            let bounds = try visibleBounds(bitmap)
            XCTAssertEqual(bounds.midX, 8, accuracy: 0.75)
            XCTAssertEqual(bounds.midY, 8, accuracy: 0.75)
        }
        let bars = try visibleBounds(running)
        XCTAssertEqual(bars.width, 14, accuracy: 0.5)
        XCTAssertGreaterThan(bars.height, 8)
        let dash = try visibleBounds(idle)
        XCTAssertEqual(dash.width, 6, accuracy: 0.5)
        XCTAssertEqual(dash.height, 1.5, accuracy: 0.5)
        let check = try visibleBounds(completed)
        XCTAssertGreaterThan(check.width, 6)
        XCTAssertGreaterThan(check.height, 6,
                             "The completion cue must remain a check, not another line")
    }

    func testRunningBarsHaveDifferentHeightsAndChangeWithTime() {
        XCTAssertEqual(FloatingActivityBars.count, 4)
        let first = (0..<FloatingActivityBars.count).map { FloatingActivityBars.height(index: $0, time: 0) }
        let later = (0..<FloatingActivityBars.count).map { FloatingActivityBars.height(index: $0, time: 0.3) }
        XCTAssertGreaterThan(Set(first).count, 1)
        XCTAssertNotEqual(first, later)
        for time in 0..<100 {
            for index in 0..<FloatingActivityBars.count {
                let height = FloatingActivityBars.height(index: index, time: Double(time) / 20)
                XCTAssertGreaterThanOrEqual(height, 3.5)
                XCTAssertLessThanOrEqual(height, 11.5)
                XCTAssertEqual(height, FloatingActivityBars.height(index: index, time: Double(time) / 20 + 3.0), accuracy: 0.0001)
            }
        }
    }

    @MainActor
    func testOrbitKeepsAStaticBeadWhenMotionIsOffAndReplacesTheRingOnCompletion() throws {
        _ = NSApplication.shared
        let running = try render(FloatingOrbitActivityMark(activity: .running, isAnimating: false))
        let idle = try render(FloatingOrbitActivityMark(activity: .idle, isAnimating: false))
        let completed = try render(FloatingOrbitActivityMark(activity: .completed, isAnimating: false))
        for bitmap in [running, idle, completed] {
            XCTAssertEqual(bitmap.pixelsWide, 32)
            XCTAssertEqual(bitmap.pixelsHigh, 32)
        }
        let center = CGRect(x: 12, y: 14, width: 8, height: 4)
        XCTAssertEqual(visiblePixelCount(running, in: center), 0,
                       "A stopped orbit keeps its bead on the ring, not a second activity symbol inside")
        XCTAssertGreaterThan(visiblePixelCount(idle, in: center), 12,
                             "Idle keeps a static horizontal dash inside the quiet ring")
        for bitmap in [running, idle] {
            for ringSide in [CGRect(x: 2, y: 12, width: 6, height: 8),
                             CGRect(x: 24, y: 12, width: 6, height: 8)] {
                XCTAssertGreaterThan(visiblePixelCount(bitmap, in: ringSide), 4,
                                     "Both sides of the ring remain visible without native animation")
            }
        }
        XCTAssertGreaterThan(brightness(running, in: CGRect(x: 11, y: 0, width: 10, height: 9)),
                             brightness(running, in: CGRect(x: 11, y: 23, width: 10, height: 9)) * 1.5,
                             "Motion off must retain the bright bead, not an indistinguishable empty ring")
        let check = try render(FloatingActivityMark(activity: .completed))
        assertSamePixels(completed, check, "Completion replaces the orbit entirely with the shared check")
    }

    @MainActor
    func testSignatureAndOrbitReserveTheSameSingleMarkSlotAndTextPosition() throws {
        _ = NSApplication.shared
        for activity in [QuotaRingActivity.running, .idle, .completed] {
            let signature = try center(.signature, activity: activity, hosted: true)
            let orbit = try center(.orbit, activity: activity, hosted: true)
            let signatureText = try separatedTextRegion(signature)
            let orbitText = try separatedTextRegion(orbit)
            XCTAssertEqual(signatureText, orbitText,
                           "A second orbit symbol must not shift or compress the signature text")
            assertSamePixels(signature, orbit, firstRegion: signatureText, secondRegion: orbitText,
                             "The two signature modes share the same proportional text treatment")
        }
        let running = try center(.signature, activity: .running, hosted: true)
        let idle = try center(.signature, activity: .idle, hosted: true)
        let runningText = try separatedTextRegion(running)
        let idleText = try separatedTextRegion(idle)
        XCTAssertEqual(runningText, idleText, "Changing state must not resize or move the stored signature")
        XCTAssertGreaterThan(brightness(running, in: runningText), brightness(idle, in: idleText) * 1.3,
                             "Running text stays brighter than idle even with all motion disabled")
    }

    @MainActor
    func testElapsedUsesTheTaskClockAndRestingLabelsWithoutCustomTextOrFakeTime() throws {
        _ = NSApplication.shared
        let running = try center(.elapsed, activity: .running, customText: "Ignored")
        let otherText = try center(.elapsed, activity: .running, customText: "不显示签名")
        assertSamePixels(running, otherText, "Elapsed ignores custom signature text")
        let nextSecond = try center(.elapsed, activity: .running, startedAt: now.addingTimeInterval(-139))
        XCTAssertFalse(pixelValues(running) == pixelValues(nextSecond), "The elapsed mode must show the real clock")
        let unknown = try center(.elapsed, activity: .running, startedAt: nil)
        let invalid = try center(.elapsed, activity: .running, startedAt: .distantPast)
        let zero = try center(.elapsed, activity: .running, startedAt: now)
        assertSamePixels(unknown, invalid, "Missing and invalid start times share the unknown-time placeholder")
        XCTAssertFalse(pixelValues(unknown) == pixelValues(zero), "Unknown starts must not manufacture 00:00")
        for activity in [QuotaRingActivity.idle, .completed] {
            let english = try center(.elapsed, activity: activity, startedAt: nil)
            let previousClock = try center(.elapsed, activity: activity, startedAt: now.addingTimeInterval(-999))
            assertSamePixels(english, previousClock, "A resting label must not keep displaying an old task clock")
            let chinese = try center(.elapsed, activity: activity, startedAt: nil, language: .chinese)
            XCTAssertFalse(pixelValues(english) == pixelValues(chinese), "Resting labels must follow the app language")
        }
    }

    @MainActor
    func testLongSignaturesStayInOneRowAndLeaveTheWeeklyQuotaLaneUnchanged() throws {
        _ = NSApplication.shared
        for style in [FloatingCenterStyle.signature, .orbit, .elapsed] {
            for activity in [QuotaRingActivity.running, .idle, .completed] {
                for text in ["WWWWWWWWWWWW", "这是很长的中文签名用于检查截断"] {
                    let bitmap = try center(style, activity: activity, customText: text)
                    let bounds = try visibleBounds(bitmap)
                    XCTAssertEqual(bitmap.pixelsWide, 272)
                    XCTAssertEqual(bitmap.pixelsHigh, 60)
                    XCTAssertLessThanOrEqual(bounds.height, 16,
                                             "A long label must not create a second row")
                    XCTAssertGreaterThanOrEqual(bounds.minX, 8)
                    XCTAssertLessThanOrEqual(bounds.maxX, 128)
                }
            }
            let bars = try ["Codex", "WWWWWWWWWWWW", "这是很长的中文签名用于检查截断"].map { text in
                try render(FloatingBarSettingsPreview(
                    style: style, customText: text, state: .running,
                    language: .english, animationsEnabled: false,
                    iconStyle: .off
                ).sampleBar)
            }
            let quota = CGRect(x: 348, y: 0, width: 60, height: 60)
            assertSamePixels(bars[0], bars[1], firstRegion: quota, secondRegion: quota,
                             "A long English signature must not alter the weekly lane")
            assertSamePixels(bars[0], bars[2], firstRegion: quota, secondRegion: quota,
                             "A long Chinese signature must not alter the weekly lane")
        }
    }

    @MainActor
    private func center(_ style: FloatingCenterStyle, activity: QuotaRingActivity,
                        customText: String = "Keep going",
                        startedAt: Date? = Date(timeIntervalSince1970: 862),
                        language: AppLanguage = .english,
                        hosted: Bool = false) throws -> NSBitmapImageRep {
        let content = FloatingCenterContent(
            style: style, customText: customText, activity: activity,
            startedAt: startedAt, now: now, isExpanded: false
        )
        .environment(\.notchMotionEnabled, false)
        .environment(\.notchAppLanguage, language)
        .frame(width: 136, height: 30)
        return try hosted ? renderHosted(content) : render(content)
    }

    @MainActor
    private func renderHosted<Content: View>(_ content: Content) throws -> NSBitmapImageRep {
        // ImageRenderer paints an unsupported-view placeholder for the native
        // shimmer overlay even when its layers are stopped. Capture AppKit's
        // actual view hierarchy to measure the real static label instead.
        let hosting = NSHostingView(rootView: content)
        let panel = NSPanel(contentRect: NSRect(x: -10_000, y: 1_000, width: 136, height: 30),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = hosting
        defer { panel.orderOut(nil) }
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 272, pixelsHigh: 60,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        bitmap.size = NSSize(width: 136, height: 30)
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        return bitmap
    }

    @MainActor
    private func render<Content: View>(_ content: Content) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        return NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
    }

    private func visibleBounds(_ bitmap: NSBitmapImageRep) throws -> CGRect {
        var bounds = CGRect.null
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                bounds = bounds.union(CGRect(x: CGFloat(x) / 2, y: CGFloat(y) / 2, width: 0.5, height: 0.5))
            }
        }
        XCTAssertFalse(bounds.isNull)
        return bounds
    }

    /// Locate the label after the inter-element gap, without knowing the
    /// implementation's stack or using a duplicate reference layout.
    private func separatedTextRegion(_ bitmap: NSBitmapImageRep) throws -> CGRect {
        let occupied = (0..<bitmap.pixelsWide).map { x in
            (0..<bitmap.pixelsHigh).contains { y in
                (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05
            }
        }
        let first = try XCTUnwrap(occupied.firstIndex(of: true))
        var gap = 0
        for x in (first + 1)..<occupied.count {
            if occupied[x] {
                if gap >= 8 {
                    let last = try XCTUnwrap(occupied.lastIndex(of: true))
                    return CGRect(x: x, y: 0, width: last - x + 1, height: bitmap.pixelsHigh)
                }
                gap = 0
            } else {
                gap += 1
            }
        }
        XCTFail("A single mark and readable label must have a clear gap")
        throw NSError(domain: "FloatingStyleRefinementTests", code: 1)
    }

    private func visiblePixelCount(_ bitmap: NSBitmapImageRep, in region: CGRect) -> Int {
        colors(bitmap, in: region).filter { $0.alphaComponent > 0.05 }.count
    }

    private func brightness(_ bitmap: NSBitmapImageRep, in region: CGRect) -> CGFloat {
        colors(bitmap, in: region).reduce(0) {
            $0 + max($1.redComponent, $1.greenComponent, $1.blueComponent) * $1.alphaComponent
        }
    }

    private func pixelValues(_ bitmap: NSBitmapImageRep, region: CGRect? = nil) -> [UInt8] {
        colors(bitmap, in: region ?? CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh)).flatMap {
            [$0.redComponent, $0.greenComponent, $0.blueComponent, $0.alphaComponent].map {
                UInt8(clamping: Int(($0 * 255).rounded()))
            }
        }
    }

    private func assertSamePixels(_ first: NSBitmapImageRep, _ second: NSBitmapImageRep,
                                  firstRegion: CGRect? = nil, secondRegion: CGRect? = nil,
                                  _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let firstValues = pixelValues(first, region: firstRegion)
        let secondValues = pixelValues(second, region: secondRegion)
        XCTAssertEqual(firstValues.count, secondValues.count, message, file: file, line: line)
        let differences = zip(firstValues, secondValues).filter { $0 != $1 }.count
        XCTAssertEqual(differences, 0, "\(message); \(differences) differing channel values", file: file, line: line)
    }

    private func colors(_ bitmap: NSBitmapImageRep, in region: CGRect) -> [NSColor] {
        (Int(region.minY)..<Int(region.maxY)).flatMap { y in
            (Int(region.minX)..<Int(region.maxX)).map { x in
                bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) ?? .clear
            }
        }
    }
}
