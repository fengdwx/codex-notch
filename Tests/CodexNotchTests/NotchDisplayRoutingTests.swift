import XCTest
@testable import CodexNotch

final class NotchDisplayRoutingTests: XCTestCase {
    func testMirroredNoNotchCoordinateSpaceSuppressesFloatingIsland() {
        XCTAssertTrue(
            NotchDisplayRouting.shouldSuppressFloatingIsland(
                layoutMode: .floatingBar,
                displayIsInHardwareMirrorSet: true
            )
        )
    }

    func testPhysicalNotchAndOrdinaryNoNotchDisplaysKeepTheirExistingPaths() {
        XCTAssertFalse(
            NotchDisplayRouting.shouldSuppressFloatingIsland(
                layoutMode: .notch,
                displayIsInHardwareMirrorSet: true
            )
        )
        XCTAssertFalse(
            NotchDisplayRouting.shouldSuppressFloatingIsland(
                layoutMode: .floatingBar,
                displayIsInHardwareMirrorSet: false
            )
        )
        XCTAssertFalse(
            NotchDisplayRouting.shouldSuppressFloatingIsland(
                layoutMode: .menuBarFallback,
                displayIsInHardwareMirrorSet: true
            )
        )
    }
}
