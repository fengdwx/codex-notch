import AppKit
import XCTest
@testable import CodexNotch

final class StatusIconStyleTests: XCTestCase {
    func testMissingAndUnrecognizedPreferencesPreserveTheCurrentCodexIcon() {
        XCTAssertEqual(StatusIconStyle.defaultStyle, .codex)
        XCTAssertEqual(StatusIconStyle.fromStoredValue(nil), .codex)
        XCTAssertEqual(StatusIconStyle.fromStoredValue("future-icon"), .codex)
    }

    func testBothIconChoicesRoundTripWithoutChangingRuntimeDataPreferences() throws {
        let suiteName = "StatusIconStyleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let initial = NotchRuntimePreferences.read(from: defaults)

        XCTAssertEqual(StatusIconStyle.allCases.count, 2)
        for style in StatusIconStyle.allCases {
            defaults.set(style.rawValue, forKey: StatusIconStyle.storageKey)
            let reopened = try XCTUnwrap(UserDefaults(suiteName: suiteName))
            XCTAssertEqual(
                StatusIconStyle.fromStoredValue(reopened.string(forKey: StatusIconStyle.storageKey)),
                style
            )
            XCTAssertEqual(NotchRuntimePreferences.read(from: defaults), initial)
        }
    }

    func testBothEmbeddedMarksKeepTheSameTemplateGeometryAndDistinctArtwork() throws {
        var bitmaps = [Data]()
        for style in StatusIconStyle.allCases {
            let image = try XCTUnwrap(style.templateImage)
            XCTAssertTrue(image.isTemplate)
            XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
            let bitmap = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
            XCTAssertEqual(bitmap.width, 36)
            XCTAssertEqual(bitmap.height, 36)
            bitmaps.append(try XCTUnwrap(bitmap.dataProvider?.data) as Data)
        }
        XCTAssertNotEqual(bitmaps[0], bitmaps[1])
    }

    private func maskImage(from layer: CALayer) throws -> CGImage {
        let contents = try XCTUnwrap(layer.mask?.contents)
        return try XCTUnwrap(
            CFGetTypeID(contents as CFTypeRef) == CGImage.typeID
                ? (contents as! CGImage)
                : nil
        )
    }

    @MainActor
    func testSwitchingTheRunningIconUpdatesItsEchoMaskWithoutRestartingMotion() async throws {
        let view = StatusMarkEchoLayerView(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
        view.layout()
        let echo = try XCTUnwrap(view.layer?.sublayers?.first)
        let codexMask = try maskImage(from: echo)
        view.startLayerAnimation()
        let animationKeys = try XCTUnwrap(echo.animationKeys())

        view.configure(iconStyle: .chatGPT, isAnimating: true)
        let chatGPTMask = try maskImage(from: echo)
        XCTAssertNotEqual(
            try XCTUnwrap(codexMask.dataProvider?.data) as Data,
            try XCTUnwrap(chatGPTMask.dataProvider?.data) as Data
        )
        XCTAssertEqual(echo.animationKeys(), animationKeys)
        XCTAssertEqual(echo.bounds.size, NSSize(width: 18, height: 18))

        view.configure(iconStyle: .codex, isAnimating: true)
        let restoredMask = try maskImage(from: echo)
        XCTAssertEqual(
            try XCTUnwrap(restoredMask.dataProvider?.data) as Data,
            try XCTUnwrap(codexMask.dataProvider?.data) as Data
        )
        view.viewWillMove(toWindow: nil)
        XCTAssertTrue(echo.animationKeys()?.isEmpty ?? true)
    }
}
