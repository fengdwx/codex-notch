import Combine
import XCTest
@testable import CodexNotch

final class NotchRuntimePerformanceTests: XCTestCase {
    func testEventDrivenActivityKeepsOneSecondClocksAndCheapRecoveryPolling() {
        XCTAssertEqual(NotchRuntimeCoordinator.sessionPollInterval, 1)
        XCTAssertEqual(NotchRuntimeCoordinator.rolloutRescanInterval, 5)
        XCTAssertEqual(NotchRuntimeCoordinator.titleRefreshInterval, 15)
        XCTAssertEqual(RolloutActivityMonitor.eventScanCoalescingInterval, 0.1)
        XCTAssertEqual(FSEventChangeSource.deliveryLatency, 0.1)
    }

    func testEquivalentViewModelUpdateDoesNotPublishAnotherViewRefresh() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let model = NotchViewModel(
            state: .hidden,
            now: now,
            animationsEnabled: false
        )
        var updateCount = 0
        let observation = model.objectWillChange.sink { _ in
            updateCount += 1
        }
        defer { observation.cancel() }

        model.update(
            state: .hidden,
            now: now,
            animationsEnabled: false
        )

        XCTAssertEqual(updateCount, 0)
    }

    func testViewModelCarriesTheFloatingBarLayoutModeIntoTheSurface() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let model = NotchViewModel(
            state: .hidden,
            now: now,
            animationsEnabled: false
        )

        model.update(
            state: .hidden,
            now: now,
            layoutMode: .floatingBar,
            animationsEnabled: false
        )

        XCTAssertEqual(model.layoutMode, .floatingBar)
    }

    func testFloatingBarReclaimsExpandedTransparentCanvasAfterCollapse() {
        XCTAssertTrue(
            NotchPanelFramePolicy.shouldSettleAfterCollapse(
                layoutMode: .notch
            )
        )
        XCTAssertTrue(
            NotchPanelFramePolicy.shouldSettleAfterCollapse(
                layoutMode: .floatingBar
            )
        )
        XCTAssertFalse(
            NotchPanelFramePolicy.shouldSettleAfterCollapse(
                layoutMode: .menuBarFallback
            )
        )
    }

    func testClockUpdatesAtWholeSecondPrecisionOnly() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let model = NotchViewModel(state: .hidden, now: now)
        var updateCount = 0
        let observation = model.objectWillChange.sink { _ in
            updateCount += 1
        }
        defer { observation.cancel() }

        model.updateClock(now: now.addingTimeInterval(0.8))
        model.updateClock(now: now.addingTimeInterval(1))

        XCTAssertEqual(updateCount, 1)
        XCTAssertEqual(model.now, now.addingTimeInterval(1))
    }
}
