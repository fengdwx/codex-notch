import AppKit
import XCTest
@testable import CodexNotch

final class ResetCreditDialogPresenterTests: XCTestCase {
    @MainActor
    func testHoverHighlightsOnlyConfirmationWithoutSubmittingAndRestoresOnExitAndDismiss() throws {
        _ = NSApplication.shared
        let presenter = ResetCreditDialogPresenter()
        defer { presenter.dismiss() }
        var decisions: [Bool] = []
        presenter.confirm(language: .english) { decisions.append($0) }
        let window = try XCTUnwrap(presenter.window)
        let use = try XCTUnwrap(buttons(in: window.contentView).first { $0.title == "Use reset" })
        let cancel = try XCTUnwrap(buttons(in: window.contentView).first { $0.title == "Cancel" })
        let area = try XCTUnwrap(use.trackingAreas.first { $0.owner is ResetConfirmationHoverFeedback })
        let feedback = try XCTUnwrap(area.owner as? ResetConfirmationHoverFeedback)
        XCTAssertFalse(cancel.trackingAreas.contains { $0.owner is ResetConfirmationHoverFeedback })
        XCTAssertTrue(feedback.highlight.isHidden)
        XCTAssertNil(feedback.highlight.hitTest(.zero), "Feedback must not intercept the button")
        let event = try XCTUnwrap(NSEvent.enterExitEvent(
            with: .mouseEntered, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0,
            trackingNumber: 0, userData: nil
        ))

        feedback.mouseEntered(with: event)
        XCTAssertFalse(feedback.highlight.isHidden)
        XCTAssertTrue(decisions.isEmpty, "Hover must never submit a reset")
        XCTAssertTrue(presenter.isPresenting)
        XCTAssertNil(window.defaultButtonCell)
        XCTAssertEqual(use.keyEquivalent, "")

        feedback.mouseExited(with: event)
        XCTAssertTrue(feedback.highlight.isHidden)
        XCTAssertTrue(decisions.isEmpty)

        use.isEnabled = false
        feedback.mouseEntered(with: event)
        XCTAssertTrue(feedback.highlight.isHidden, "Disabled actions must not invite a click")
        use.isEnabled = true
        feedback.mouseEntered(with: event)
        cancel.performClick(nil)
        XCTAssertEqual(decisions, [false])
        XCTAssertTrue(feedback.highlight.isHidden)
        XCTAssertNil(feedback.highlight.superview)
        XCTAssertFalse(use.trackingAreas.contains { $0 === area })
        feedback.mouseEntered(with: event)
        XCTAssertTrue(feedback.highlight.isHidden, "A stale tracking event cannot revive feedback")
        XCTAssertEqual(decisions, [false])
    }

    @MainActor
    func testConfirmationReturnsToMainQueueAndCancelDoesNotSubmit() async throws {
        _ = NSApplication.shared
        let presenter = ResetCreditDialogPresenter()
        defer { presenter.dismiss() }
        var decisions: [Bool] = []
        presenter.confirm(language: .english) { decisions.append($0) }
        let window = try XCTUnwrap(presenter.window)
        XCTAssertTrue(window.isVisible)
        XCTAssertTrue(window.canBecomeKey)
        XCTAssertGreaterThan(window.level.rawValue, NSWindow.Level.popUpMenu.rawValue)
        XCTAssertNil(NSApp.modalWindow, "The status app must not enter an app-modal loop")
        XCTAssertTrue(decisions.isEmpty, "Showing confirmation cannot submit a reset")

        let hoverTimer = expectation(description: "main-queue hover-collapse timer is serviced")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { hoverTimer.fulfill() }
        await fulfillment(of: [hoverTimer], timeout: 1)

        let cancel = try XCTUnwrap(buttons(in: window.contentView).first { $0.title == "Cancel" })
        let use = try XCTUnwrap(buttons(in: window.contentView).first { $0.title == "Use reset" })
        XCTAssertLessThan(cancel.convert(cancel.bounds, to: nil).maxX,
                          use.convert(use.bounds, to: nil).minX,
                          "Cancel must be to the left of Use reset; cancel=\(cancel.convert(cancel.bounds, to: nil)), confirm=\(use.convert(use.bounds, to: nil))")
        cancel.performClick(nil)
        XCTAssertEqual(decisions, [false])
        XCTAssertFalse(window.isVisible)
        XCTAssertFalse(presenter.isPresenting)
    }

    @MainActor
    func testExplicitConfirmationCompletesOnceAndWindowCloseCancelsNextAttempt() throws {
        _ = NSApplication.shared
        let presenter = ResetCreditDialogPresenter()
        defer { presenter.dismiss() }
        var decisions: [Bool] = []
        presenter.confirm(language: .chinese) { decisions.append($0) }
        let window = try XCTUnwrap(presenter.window)
        let use = try XCTUnwrap(buttons(in: window.contentView).first { $0.title == "使用重置" })
        let cancel = try XCTUnwrap(buttons(in: window.contentView).first { $0.title == "取消" })
        XCTAssertLessThan(cancel.convert(cancel.bounds, to: nil).maxX,
                          use.convert(use.bounds, to: nil).minX,
                          "取消 must be to the left of 使用重置; cancel=\(cancel.convert(cancel.bounds, to: nil)), confirm=\(use.convert(use.bounds, to: nil))")
        XCTAssertEqual(use.keyEquivalent, "", "Return must not accidentally consume a credit")
        use.performClick(nil)
        use.performClick(nil)
        XCTAssertEqual(decisions, [true])

        presenter.confirm(language: .chinese) { decisions.append($0) }
        try XCTUnwrap(presenter.window).performClose(nil)
        XCTAssertEqual(decisions, [true, false])
        XCTAssertFalse(presenter.isPresenting)
    }

    @MainActor
    func testResultWindowIsNonmodalAndCanBeDismissed() async throws {
        _ = NSApplication.shared
        let presenter = ResetCreditDialogPresenter()
        defer { presenter.dismiss() }
        presenter.showResult(message: "Fixture outcome", language: .english)
        let window = try XCTUnwrap(presenter.window)
        XCTAssertNil(NSApp.modalWindow)
        XCTAssertTrue(window.isVisible)
        let tick = expectation(description: "main queue remains available after result")
        DispatchQueue.main.async { tick.fulfill() }
        await fulfillment(of: [tick], timeout: 1)
        try XCTUnwrap(buttons(in: window.contentView).first { $0.title == "OK" }).performClick(nil)
        XCTAssertFalse(window.isVisible)
        XCTAssertFalse(presenter.isPresenting)
    }

    @MainActor
    func testBringingExistingDialogForwardPreservesWindowAndPendingDecision() throws {
        _ = NSApplication.shared
        let presenter = ResetCreditDialogPresenter()
        defer { presenter.dismiss() }
        var decisions: [Bool] = []
        presenter.confirm(language: .english) { decisions.append($0) }
        let confirmation = try XCTUnwrap(presenter.window)
        confirmation.orderOut(nil)
        XCTAssertFalse(confirmation.isVisible)

        presenter.bringToFront()
        XCTAssertTrue(presenter.window === confirmation)
        XCTAssertTrue(confirmation.isVisible)
        XCTAssertTrue(decisions.isEmpty, "Restoring the existing dialog cannot confirm or cancel")
        XCTAssertNil(NSApp.modalWindow)

        presenter.dismiss()
        XCTAssertEqual(decisions, [false])
        presenter.showResult(message: "Fixture outcome", language: .english)
        let result = try XCTUnwrap(presenter.window)
        result.orderOut(nil)
        presenter.bringToFront()
        XCTAssertTrue(presenter.window === result)
        XCTAssertTrue(result.isVisible)
        XCTAssertEqual(decisions, [false])
        XCTAssertEqual(buttons(in: result.contentView).map(\.title), ["OK"])

        presenter.dismiss()
        presenter.bringToFront()
        XCTAssertNil(presenter.window, "Restoring a dismissed dialog must not create one")
        XCTAssertEqual(decisions, [false])
    }

    @MainActor
    func testReturnDoesNotConfirmAndEscapeCancelsThroughWindowKeyRouting() throws {
        _ = NSApplication.shared
        let presenter = ResetCreditDialogPresenter()
        defer { presenter.dismiss() }
        var decisions: [Bool] = []
        presenter.confirm(language: .english) { decisions.append($0) }
        let window = try XCTUnwrap(presenter.window)
        let returnKey = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36
        ))
        _ = window.performKeyEquivalent(with: returnKey)
        XCTAssertTrue(decisions.isEmpty)
        XCTAssertTrue(presenter.isPresenting)

        let escapeKey = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil,
            characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53
        ))
        XCTAssertTrue(window.performKeyEquivalent(with: escapeKey))
        XCTAssertEqual(decisions, [false])
        XCTAssertFalse(presenter.isPresenting)
        XCTAssertFalse(window.isVisible)
    }

    @MainActor
    private func buttons(in view: NSView?) -> [NSButton] {
        guard let view else { return [] }
        return (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { buttons(in: $0) }
    }
}
