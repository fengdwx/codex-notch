import AppKit
import Foundation
import XCTest
@testable import CodexNotch

final class AppIconAssetTests: XCTestCase {
    func testCodexPromptHasTransparentSurroundingsWithoutAFilledFlower() throws {
        let image = try XCTUnwrap(CodexMarkAsset.promptTemplateImage)
        let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        var visiblePixels = Set<Int>()
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                if color.alphaComponent > 0 {
                    visiblePixels.insert(y * bitmap.pixelsWide + x)
                    XCTAssertGreaterThan(color.redComponent, 0.95)
                    XCTAssertGreaterThan(color.greenComponent, 0.95)
                    XCTAssertGreaterThan(color.blueComponent, 0.95)
                }
            }
        }
        // The two prompt strokes must remain readable while the broad, filled
        // flower from the previous artwork is absent.
        XCTAssertGreaterThan(visiblePixels.count, 30)
        XCTAssertLessThan(visiblePixels.count, 220)
        var components = 0
        while let first = visiblePixels.first {
            components += 1
            var pending = [first]
            visiblePixels.remove(first)
            while let pixel = pending.popLast() {
                let x = pixel % bitmap.pixelsWide
                let y = pixel / bitmap.pixelsWide
                for dy in -1...1 {
                    for dx in -1...1 {
                        let nextX = x + dx
                        let nextY = y + dy
                        guard (0..<bitmap.pixelsWide).contains(nextX),
                              (0..<bitmap.pixelsHigh).contains(nextY) else { continue }
                        let neighbor = nextY * bitmap.pixelsWide + nextX
                        if visiblePixels.remove(neighbor) != nil { pending.append(neighbor) }
                    }
                }
            }
        }
        XCTAssertEqual(components, 2, "Only the chevron and underscore should remain")
        for (x, y) in [(0, 0), (18, 0), (35, 0), (0, 18), (35, 18), (0, 35), (18, 35), (35, 35)] {
            XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: x, y: y)).alphaComponent, 0)
        }
    }

    func testCodexDisplayRestoresTheDarkFlowerBehindTheOriginalWhitePrompt() throws {
        let image = try XCTUnwrap(CodexMarkAsset.displayImage)
        XCTAssertFalse(image.isTemplate)
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(
            image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        ))
        let prompt = NSBitmapImageRep(cgImage: try XCTUnwrap(
            CodexMarkAsset.promptTemplateImage?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        ))
        var darkFlowerPixels = 0
        var brightPromptPixels = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                if color.alphaComponent > 0.9 && color.redComponent < 0.2 {
                    darkFlowerPixels += 1
                }
                if try XCTUnwrap(prompt.colorAt(x: x, y: y)).alphaComponent > 0.75 {
                    XCTAssertGreaterThan(color.alphaComponent, 0.9)
                    XCTAssertGreaterThan(color.redComponent, 0.75)
                    brightPromptPixels += 1
                }
            }
        }
        XCTAssertGreaterThan(darkFlowerPixels, 650)
        XCTAssertGreaterThan(brightPromptPixels, 25)
        for (x, y) in [(0, 0), (35, 0), (0, 35), (35, 35)] {
            XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: x, y: y)).alphaComponent, 0.01)
        }
    }

    func testAppIconKeepsTheSuppliedNotchPromptAndSparkleIdentity() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Resources/AppIcon.svg"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("id=\"notch-shell\""))
        XCTAssertTrue(source.contains("id=\"prompt-mark\""))
        XCTAssertTrue(source.contains("id=\"sparkle\""))
        XCTAssertTrue(source.contains("stroke=\"#fff\""))
    }

    func testNotchMarkUsesEmbeddedWhiteCodexArtworkWithoutReadingAnotherAppBundle() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let markSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/CodexNotch/UI/StatusIconStyle.swift"
            ),
            encoding: .utf8
        )
        let notchViewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/CodexNotch/UI/NotchView.swift"
            ),
            encoding: .utf8
        )
        let image = try XCTUnwrap(CodexMarkAsset.templateImage)

        XCTAssertEqual(image.size.width, 18)
        XCTAssertEqual(image.size.height, 18)
        XCTAssertTrue(image.isTemplate)
        XCTAssertTrue(
            image.representations.contains {
                $0.pixelsWide == 36 && $0.pixelsHigh == 36
            }
        )
        XCTAssertTrue(markSource.contains("CodexMarkAsset.templateImage"))
        XCTAssertTrue(markSource.contains("ChatGPTMarkAsset.templateImage"))
        XCTAssertFalse(markSource.contains("Bundle(url: appURL)"))
        XCTAssertFalse(markSource.contains("chatgptTemplate"))
        XCTAssertFalse(notchViewSource.contains("Bundle(url: appURL)"))
        XCTAssertFalse(notchViewSource.contains("chatgptTemplate"))
    }
}
