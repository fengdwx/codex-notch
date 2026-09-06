import AppKit
import QuartzCore
import SwiftUI
import XCTest
@testable import CodexNotch

final class StatusIconThemeTests: XCTestCase {
    @MainActor
    func testThemedCodexMarkKeepsBlackInsideAndColorOnlyOnItsFlowerOutline() throws {
        for remaining in [80.0, 20, 5] {
            let theme = StatusIconTheme(usage: usage(remaining: remaining))
            let renderer = ImageRenderer(content:
                StatusMark(style: .codex, size: 18, theme: theme)
                    .background(Color.black)
            )
            renderer.scale = 2
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
            XCTAssertEqual(bitmap.pixelsWide, 36)
            XCTAssertEqual(bitmap.pixelsHigh, 36)
            for (x, y) in [(18, 14), (18, 18), (20, 18)] {
                let center = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                XCTAssertLessThan(center.redComponent, 0.01)
                XCTAssertLessThan(center.greenComponent, 0.01)
                XCTAssertLessThan(center.blueComponent, 0.01)
            }
            var whitePromptPixels = 0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                    let channels = [color.redComponent, color.greenComponent, color.blueComponent]
                    if (14...22).contains(x), (10...22).contains(y) {
                        XCTAssertLessThan(
                            try XCTUnwrap(channels.max()) - XCTUnwrap(channels.min()), 0.01,
                            "The whole center must stay neutral, including prompt antialiasing"
                        )
                    }
                    if channels.allSatisfy({ $0 > 0.75 }) { whitePromptPixels += 1 }
                }
            }
            let coloredArea = try coloredArea(of: bitmap, accent: theme.accent)
            XCTAssertGreaterThan(coloredArea, 25, "The original flower outline stays visible")
            XCTAssertLessThan(coloredArea, 400, "Quota color must not fill the flower's center")
            XCTAssertGreaterThan(whitePromptPixels, 25, "The prompt stays white")
        }
    }

    // Integrate fractional edge coverage instead of counting every barely
    // colored antialiased pixel as fully covered. macOS 14 and 26 rasterizers
    // differ at those edges; the same 400-pixel area ceiling remains enforced.
    private func coloredArea(of bitmap: NSBitmapImageRep, accent: QuotaColorScale.RGB) throws -> Double {
        let accentChannels = [accent.red, accent.green, accent.blue]
        let fullChroma = try XCTUnwrap(accentChannels.max()) - XCTUnwrap(accentChannels.min())
        XCTAssertGreaterThan(fullChroma, 0)
        var area = 0.0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                let channels = [color.redComponent, color.greenComponent, color.blueComponent]
                area += min(1, (try XCTUnwrap(channels.max()) - XCTUnwrap(channels.min())) / fullChroma)
            }
        }
        return area
    }

    @MainActor
    func testOutlineAreaGuardRejectsAQuotaColoredSolidFlower() throws {
        let prompt = try XCTUnwrap(CodexMarkAsset.promptTemplateImage)
        for remaining in [80.0, 20, 5] {
            let theme = StatusIconTheme(usage: usage(remaining: remaining))
            let renderer = ImageRenderer(content:
                ZStack {
                    StatusMark(style: .codex, size: 18, tint: theme.flowerOutlineColor, monochrome: true)
                    Image(nsImage: prompt)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.white)
                }
                .frame(width: 18, height: 18)
                .background(Color.black)
            )
            renderer.scale = 2
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
            XCTAssertGreaterThan(try coloredArea(of: bitmap, accent: theme.accent), 400,
                                 "A solid colored flower must fail the outline area ceiling")
        }
    }

    private func usage(remaining: Double) -> UsageSnapshot {
        UsageSnapshot(windows: [
            UsageWindow(id: "five-hour", kind: .rolling(hours: 5), usedPercent: 100),
            UsageWindow(id: "weekly", kind: .weekly, usedPercent: 100 - remaining)
        ])
    }

    func testStatusThemeUsesTheSameWeeklyColorAtEveryQuotaBoundary() {
        for remaining in [100.0, 80, 20.001, 20, 10.001, 10, 5, 0] {
            XCTAssertEqual(
                StatusIconTheme(usage: usage(remaining: remaining)).accent,
                QuotaColorScale.components(for: remaining)
            )
        }
    }

    func testMissingWeeklyQuotaUsesNeutralColorInsteadOfInventingAWarnedQuota() {
        let unavailable = StatusIconTheme(usage: nil)
        XCTAssertEqual(unavailable.accent.red, unavailable.accent.green)
        XCTAssertEqual(unavailable.accent.green, unavailable.accent.blue)
        XCTAssertEqual(StatusIconTheme(usage: UsageSnapshot(windows: [
            UsageWindow(id: "five-hour", kind: .rolling(hours: 5), usedPercent: 100)
        ])), unavailable)
        XCTAssertNotEqual(unavailable, StatusIconTheme(usage: usage(remaining: 0)))
    }

    func testTheDarkThemeKeepsTheTinyWhitePromptAtHighContrast() {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        for remaining in [100.0, 20, 5, 0] {
            let fill = StatusIconTheme(usage: usage(remaining: remaining)).flowerFill
            let luminance = 0.2126 * linear(fill.red)
                + 0.7152 * linear(fill.green) + 0.0722 * linear(fill.blue)
            XCTAssertGreaterThanOrEqual(1.05 / (luminance + 0.05), 7)
        }
    }

    func testLowQuotaKeepsItsRedStaticThemeWithoutARedRunningPulse() {
        for remaining in [10.0, 5, 0] {
            let theme = StatusIconTheme(usage: usage(remaining: remaining))
            XCTAssertEqual(theme.accent, QuotaColorScale.components(for: remaining))
            XCTAssertNotEqual(theme.runningEcho, theme.accent)
            XCTAssertEqual(theme.runningEcho.red, theme.runningEcho.green)
            XCTAssertEqual(theme.runningEcho.green, theme.runningEcho.blue)
        }
        for remaining in [10.001, 20, 80] {
            let theme = StatusIconTheme(usage: usage(remaining: remaining))
            XCTAssertEqual(theme.runningEcho, theme.accent)
        }
    }

    @MainActor
    func testQuotaColorChangesUpdateTheEchoWithoutRestartingItsPulse() throws {
        let view = StatusMarkEchoLayerView(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
        view.configure(iconStyle: .codex, color: QuotaColorScale.components(for: 80), isAnimating: true)
        let echo = try XCTUnwrap(view.layer?.sublayers?.first)
        view.startLayerAnimation()
        let key = try XCTUnwrap(echo.animationKeys()?.first)
        let pulse = try XCTUnwrap(echo.animation(forKey: key)?.copy() as? CAAnimation)
        // Give the existing loop a known phase so replacing it under the same
        // animation key would still fail this assertion.
        pulse.beginTime = CACurrentMediaTime() - 0.4
        echo.add(pulse, forKey: key)
        for remaining in [20.0, 5] {
            let color = StatusIconTheme(usage: usage(remaining: remaining)).runningEcho
            view.configure(iconStyle: .codex, color: color, isAnimating: true)
            let rendered = try XCTUnwrap(NSColor(cgColor: try XCTUnwrap(echo.backgroundColor)))
                .usingColorSpace(.deviceRGB)
            XCTAssertEqual(try XCTUnwrap(rendered).redComponent, color.red, accuracy: 0.001)
            XCTAssertEqual(try XCTUnwrap(rendered).greenComponent, color.green, accuracy: 0.001)
            XCTAssertEqual(try XCTUnwrap(rendered).blueComponent, color.blue, accuracy: 0.001)
            XCTAssertEqual(try XCTUnwrap(echo.animation(forKey: key)).beginTime, pulse.beginTime)
        }
    }
}
