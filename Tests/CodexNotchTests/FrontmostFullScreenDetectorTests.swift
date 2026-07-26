import CoreGraphics
import XCTest
@testable import CodexNotch

final class FrontmostFullScreenDetectorTests: XCTestCase {
    private let screenBounds = CGRect(x: 0, y: 0, width: 1512, height: 982)

    func testFrontmostLayerZeroWindowCoveringTheNotchScreenSuppressesThePanel() {
        XCTAssertTrue(
            FrontmostFullScreenDetector.shouldSuppressNotch(
                frontmostProcessIdentifier: 42,
                screenBounds: screenBounds,
                windows: [
                    FrontmostWindowSnapshot(
                        ownerProcessIdentifier: 42,
                        layer: 0,
                        bounds: screenBounds
                    )
                ]
            )
        )
    }

    func testOrdinaryMaximizedWindowBelowTheMenuBarDoesNotSuppressThePanel() {
        XCTAssertFalse(
            FrontmostFullScreenDetector.shouldSuppressNotch(
                frontmostProcessIdentifier: 42,
                screenBounds: screenBounds,
                windows: [
                    FrontmostWindowSnapshot(
                        ownerProcessIdentifier: 42,
                        layer: 0,
                        bounds: CGRect(x: 0, y: 25, width: 1512, height: 900)
                    )
                ]
            )
        )
    }

    func testBackgroundApplicationsCannotSuppressThePanel() {
        XCTAssertFalse(
            FrontmostFullScreenDetector.shouldSuppressNotch(
                frontmostProcessIdentifier: 42,
                screenBounds: screenBounds,
                windows: [
                    FrontmostWindowSnapshot(
                        ownerProcessIdentifier: 84,
                        layer: 0,
                        bounds: screenBounds
                    )
                ]
            )
        )
    }

    func testOverlayWindowFromFrontmostApplicationDoesNotCountAsFullScreenContent() {
        XCTAssertFalse(
            FrontmostFullScreenDetector.shouldSuppressNotch(
                frontmostProcessIdentifier: 42,
                screenBounds: screenBounds,
                windows: [
                    FrontmostWindowSnapshot(
                        ownerProcessIdentifier: 42,
                        layer: 25,
                        bounds: screenBounds
                    )
                ]
            )
        )
    }
}
