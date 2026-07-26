import XCTest
@testable import CodexNotch

final class SmokeTests: XCTestCase {
    func testApplicationIdentifierIsStable() {
        XCTAssertEqual(AppIdentity.bundleIdentifier, "com.david.codexnotch")
    }

    func testVisibilityShortcutUsesCommandOptionN() {
        XCTAssertEqual(NotchVisibilityShortcutConfiguration.keyCode, 0x2D)
        XCTAssertEqual(NotchVisibilityShortcutConfiguration.modifiers, 0x0900)
        XCTAssertEqual(NotchVisibilityShortcutConfiguration.displayText, "⌥⌘N")
    }
}
