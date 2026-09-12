import AppKit
import XCTest
@testable import CodexNotch

final class QuotaWaveBoundaryTests: XCTestCase {
    @MainActor
    func testFullAndEmptyQuotaStayAccurateAcrossHorizontalWaveTranslation() throws {
        let view = QuotaWaveLayerView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        for progress: CGFloat in [0, 1] {
            view.configure(
                color: QuotaColorScale.RGB(red: 0, green: 1, blue: 0),
                fillProgress: progress,
                isAnimating: false,
                progressAnimationEnabled: false
            )
            let wave = try XCTUnwrap(view.layer?.sublayers?.first as? CAShapeLayer)
            let path = try XCTUnwrap(wave.path)
            for step in 0...20 {
                let translation = (24 / 1.35) * CGFloat(step) / 20
                for x: CGFloat in [6, 12, 18] {
                    let point = CGPoint(x: x + translation, y: progress == 1 ? 23.8 : 0.2)
                    XCTAssertEqual(path.contains(point), progress == 1,
                                   "Endpoint fill must remain accurate throughout translation")
                }
            }
        }
    }

    @MainActor
    func testPartialQuotaRetainsWaveAndFilledLowerHalf() throws {
        let view = QuotaWaveLayerView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        view.configure(
            color: QuotaColorScale.RGB(red: 0, green: 1, blue: 0),
            fillProgress: 0.5,
            isAnimating: false,
            progressAnimationEnabled: false
        )
        let wave = try XCTUnwrap(view.layer?.sublayers?.first as? CAShapeLayer)
        let path = try XCTUnwrap(wave.path)
        XCTAssertTrue(path.contains(CGPoint(x: 12, y: 2)))
        XCTAssertFalse(path.contains(CGPoint(x: 12, y: 22)))
        XCTAssertTrue(path.contains(CGPoint(x: 24 / 1.35 / 4, y: 12)))
        XCTAssertFalse(path.contains(CGPoint(x: 24 / 1.35 * 3 / 4, y: 12)))
    }
}
