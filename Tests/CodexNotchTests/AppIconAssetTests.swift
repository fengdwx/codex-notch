import Foundation
import XCTest
@testable import CodexNotch

final class AppIconAssetTests: XCTestCase {
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

    func testNotchMarkUsesEmbeddedTemplateWithoutReadingAnotherAppBundle() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let notchViewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/CodexNotch/UI/NotchView.swift"
            ),
            encoding: .utf8
        )
        let image = try XCTUnwrap(ChatGPTMarkAsset.templateImage)

        XCTAssertEqual(image.size.width, 18)
        XCTAssertEqual(image.size.height, 18)
        XCTAssertTrue(image.isTemplate)
        XCTAssertTrue(notchViewSource.contains("ChatGPTMarkAsset.templateImage"))
        XCTAssertFalse(notchViewSource.contains("Bundle(url: appURL)"))
        XCTAssertFalse(notchViewSource.contains("chatgptTemplate"))
    }
}
