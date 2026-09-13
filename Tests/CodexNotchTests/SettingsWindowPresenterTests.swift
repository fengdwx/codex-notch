import AppKit
import XCTest
@testable import CodexNotch

final class SettingsWindowPresenterTests: XCTestCase {
    @MainActor
    func testRepeatedRequestsRevealTheSameSettingsWindow() async throws {
        _ = NSApplication.shared
        let window = makeWindow(settings: true)
        window.collectionBehavior = [.fullScreenNone]
        defer { dispose(window) }
        let originalLevel = window.level
        var createdWindows = 0

        for _ in 0..<3 {
            window.orderOut(nil)
            XCTAssertFalse(window.isVisible)
            SettingsWindowPresenter.show { createdWindows += 1 }
            try await Task.sleep(for: .milliseconds(50))
            XCTAssertTrue(window.isVisible)
        }

        XCTAssertEqual(createdWindows, 0, "Reopening must reuse the existing Settings scene")
        XCTAssertEqual(window.level, originalLevel, "Settings must not become permanently floating")
    }

    @MainActor
    func testUnrelatedWindowDoesNotPreventCreatingSettings() async throws {
        _ = NSApplication.shared
        let other = makeWindow(settings: false)
        var settings: NSWindow?
        defer {
            dispose(other)
            if let settings { dispose(settings) }
        }
        var createdWindows = 0

        SettingsWindowPresenter.show {
            createdWindows += 1
            settings = makeWindow(settings: true)
        }
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(createdWindows, 1)
        XCTAssertTrue(try XCTUnwrap(settings).isVisible)
        XCTAssertFalse(other.isVisible)
    }

    @MainActor
    private func makeWindow(settings: Bool) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 220, height: 120),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier(
            settings ? "com_apple_SwiftUI_Settings_window" : "unrelated-test-window"
        )
        return window
    }

    @MainActor
    private func dispose(_ window: NSWindow) {
        window.identifier = nil
        window.close()
    }
}
