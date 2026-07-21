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
}
