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
    func testShowNativeSettingsOpensVisibleFullSizeWindowEvenWhenHiddenSwiftUISettingsWindowExists() async throws {
        _ = NSApplication.shared
        SettingsWindowPresenter.disposeOwnedSettingsWindowForTesting()
        defer { SettingsWindowPresenter.disposeOwnedSettingsWindowForTesting() }

        let hiddenSwiftUISettings = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        hiddenSwiftUISettings.isReleasedWhenClosed = false
        hiddenSwiftUISettings.identifier = NSUserInterfaceItemIdentifier("com_apple_SwiftUI_Settings_window")
        hiddenSwiftUISettings.alphaValue = 0
        defer { dispose(hiddenSwiftUISettings) }

        SettingsWindowPresenter.showNativeSettings()
        let nativeWindow = SettingsWindowPresenter.createNativeSettingsWindow()
        XCTAssertTrue(nativeWindow !== hiddenSwiftUISettings)
        XCTAssertTrue(
            nativeWindow.isVisible,
            "Native Settings window must activate and order front synchronously inside the user's click event"
        )
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertTrue(nativeWindow.isVisible, "Native Settings window must remain visible after activation settles")
        XCTAssertEqual(nativeWindow.alphaValue, 1, accuracy: 0.01)
        XCTAssertEqual(nativeWindow.frame.width, NotchSettingsLayout.windowWidth, accuracy: 1)
        XCTAssertEqual(nativeWindow.frame.height, NotchSettingsLayout.windowHeight, accuracy: 1)
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
