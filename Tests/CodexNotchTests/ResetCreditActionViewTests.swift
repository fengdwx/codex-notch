import AppKit
import SwiftUI
import XCTest
@testable import CodexNotch

final class ResetCreditActionViewTests: XCTestCase {
    private static let enhancedUI = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")

    override func tearDown() {
        MainActor.assumeIsolated {
            NSApp.accessibilitySetValue(false, forAttribute: Self.enhancedUI)
        }
        super.tearDown()
    }

    @MainActor
    func testViewingResetDetailsDoesNotUseACredit() throws {
        var expanded = false
        var usedCredits: [String] = []
        let credit = ResetCredit(id: "available-credit", expiresAt: now.addingTimeInterval(3_600))
        let hosting = host(credits: [credit], isExpanded: false,
                           onExpandedChanged: { expanded = $0 },
                           onUseResetCredit: { usedCredits.append($0.id) })
        defer { hosting.close() }

        let disclosure = try XCTUnwrap(buttons(in: hosting).first)
        XCTAssertEqual(buttons(in: hosting).count, 1,
                       "A collapsed disclosure must not expose a use action")
        XCTAssertEqual(disclosure.accessibilityPerformPress?(), true)
        XCTAssertTrue(expanded)
        XCTAssertTrue(usedCredits.isEmpty, "Viewing expiry details must never consume a credit")
    }

    @MainActor
    func testUseActionPassesTheSelectedCreditAndKeepsBothTimesVisible() throws {
        for language in [AppLanguage.english, .chinese] {
            var usedCredits: [String] = []
            let credits = [
                ResetCredit(id: "first", expiresAt: now.addingTimeInterval(3_600)),
                ResetCredit(id: "second", expiresAt: now.addingTimeInterval(7_200))
            ]
            let hosting = host(credits: credits, language: language,
                               onUseResetCredit: { usedCredits.append($0.id) })
            defer { hosting.close() }
            let title = language.localized(chinese: "使用重置", english: "Use reset")
            let useButtons = buttons(in: hosting).filter { $0.accessibilityLabel?() == title }
            XCTAssertEqual(useButtons.count, 2)
            XCTAssertEqual(try XCTUnwrap(useButtons.last).accessibilityPerformPress?(), true)
            XCTAssertEqual(usedCredits, ["second"])

            let labels = accessibilityElements(in: hosting).compactMap(accessibleText)
            for credit in credits {
                XCTAssertTrue(labels.contains(NotchText.resetCreditExpiry(credit, language: language)))
                let countdown = NotchText.resetCountdown(resetAt: try XCTUnwrap(credit.expiresAt),
                                                        now: now, language: language)
                XCTAssertTrue(labels.contains { $0.contains(countdown) },
                              "Adding the action must retain the second-level expiry countdown")
            }
        }
    }

    @MainActor
    func testInFlightAndExpiredCreditsCannotBeUsed() throws {
        let available = ResetCredit(id: "available-credit", expiresAt: now.addingTimeInterval(3_600))
        let expired = ResetCredit(id: "expired-credit", expiresAt: now)
        for (credit, isUsing) in [(available, true), (expired, false)] {
            var usedCount = 0
            let hosting = host(credits: [credit], isUsing: isUsing,
                               onUseResetCredit: { _ in usedCount += 1 })
            defer { hosting.close() }
            let title = isUsing ? "Using…" : "Use reset"
            let button = try XCTUnwrap(buttons(in: hosting).first { $0.accessibilityLabel?() == title })
            XCTAssertEqual(button.isAccessibilityEnabled?(), false)
            _ = button.accessibilityPerformPress?()
            XCTAssertEqual(usedCount, 0)
        }
    }

    @MainActor
    func testPendingConfirmationIsLabelledAndCannotStartAnotherReset() throws {
        for language in [AppLanguage.english, .chinese] {
            var usedCount = 0
            let hosting = host(
                credits: [ResetCredit(id: "available", expiresAt: now.addingTimeInterval(3_600))],
                isUsing: true, isAwaitingConfirmation: true, language: language,
                onUseResetCredit: { _ in usedCount += 1 }
            )
            defer { hosting.close() }
            let title = language.localized(chinese: "待确认…", english: "Confirm…")
            let button = try XCTUnwrap(buttons(in: hosting).first { $0.accessibilityLabel?() == title })
            XCTAssertEqual(button.isAccessibilityEnabled?(), false)
            _ = button.accessibilityPerformPress?()
            XCTAssertEqual(usedCount, 0)
            XCTAssertFalse(buttons(in: hosting).contains {
                $0.accessibilityLabel?() == language.localized(chinese: "使用中…", english: "Using…")
            }, "Waiting for confirmation must not imply that a reset has already been submitted")
        }
    }

    @MainActor
    func testMissingServiceIDKeepsDetailsVisibleButDisablesUse() throws {
        let response = try JSONDecoder().decode(ResetCreditsDTO.self, from: Data(
            #"{"available_count":1,"credits":[{"status":"available","expires_at":"2030-01-01T00:00:00Z"}]}"#.utf8
        ))
        var usedCount = 0
        let hosting = host(credits: response.availableCredits,
                           onUseResetCredit: { _ in usedCount += 1 })
        defer { hosting.close() }
        let button = try XCTUnwrap(buttons(in: hosting).first { $0.accessibilityLabel?() == "Use reset" })
        XCTAssertEqual(button.isAccessibilityEnabled?(), false)
        _ = button.accessibilityPerformPress?()
        XCTAssertEqual(usedCount, 0, "A generated display identity cannot authorize redemption")
    }

    @MainActor
    func testResetActionTextKeepsContrastInBothAppearancesAndDisabledStates() throws {
        let available = ResetCredit(id: "available", expiresAt: now.addingTimeInterval(3_600))
        let expired = ResetCredit(id: "expired", expiresAt: now)
        for scheme in [ColorScheme.light, .dark] {
            for language in [AppLanguage.english, .chinese] {
                for (credit, isUsing, isAwaiting) in [
                    (available, false, false), (available, true, false),
                    (available, true, true), (expired, false, false)
                ] {
                    let renderer = ImageRenderer(content:
                        ResetScheduleRow(
                            credit: credit, now: now, language: language,
                            isUsingResetCredit: isUsing,
                            isAwaitingResetConfirmation: isAwaiting,
                            onUseResetCredit: { _ in }
                        )
                        .frame(width: 384, height: NotchExpandedLayout.resetScheduleRowHeight)
                        .background(Color.black)
                        .environment(\.colorScheme, scheme)
                    )
                    renderer.scale = 2
                    let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
                    // Sample only the action's right-side text area. Expiry
                    // labels on the left cannot make an invisible button pass.
                    let background = try XCTUnwrap(bitmap.colorAt(
                        x: 740, y: bitmap.pixelsHigh / 2
                    )?.usingColorSpace(.sRGB))
                    let backgroundLuminance = relativeLuminance(background)
                    var readableTextPixels = 0
                    for y in 12..<(bitmap.pixelsHigh - 12) {
                        for x in 610..<736 {
                            let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                            let luminance = relativeLuminance(color)
                            if (luminance + 0.05) / (backgroundLuminance + 0.05) >= 4.5 {
                                readableTextPixels += 1
                            }
                        }
                    }
                    XCTAssertGreaterThan(readableTextPixels, 30,
                        "Reset text must remain readable in \(scheme), \(language), busy=\(isUsing), awaiting=\(isAwaiting), available=\(credit.canRedeem(at: now))")
                }
            }
        }
    }

    private func relativeLuminance(_ color: NSColor) -> CGFloat {
        func linear(_ component: CGFloat) -> CGFloat {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.redComponent)
            + 0.7152 * linear(color.greenComponent)
            + 0.0722 * linear(color.blueComponent)
    }

    private var now: Date { Date(timeIntervalSince1970: 1_790_000_000) }

    @MainActor
    private func host(
        credits: [ResetCredit],
        isExpanded: Bool = true,
        isUsing: Bool = false,
        isAwaitingConfirmation: Bool = false,
        language: AppLanguage = .english,
        onExpandedChanged: @escaping (Bool) -> Void = { _ in },
        onUseResetCredit: @escaping (ResetCredit) -> Void
    ) -> NSWindow {
        _ = NSApplication.shared
        // SwiftUI lazily creates its accessibility tree only while accessibility
        // is active. Enable it for this test process, then restore in tearDown.
        NSApp.accessibilitySetValue(true, forAttribute: Self.enhancedUI)
        let height = 32 + (isExpanded
            ? NotchExpandedLayout.resetScheduleDetailSpacing
                + 2 * NotchExpandedLayout.resetScheduleDetailVerticalPadding
                + CGFloat(credits.count) * NotchExpandedLayout.resetScheduleRowHeight
                + CGFloat(max(0, credits.count - 1)) * NotchExpandedLayout.conversationSeparatorHeight
            : 0)
        let view = ResetScheduleDisclosure(
            credits: credits, now: now, isExpanded: isExpanded,
            isUsingResetCredit: isUsing,
            isAwaitingResetConfirmation: isAwaitingConfirmation,
            title: "\(credits.count) resets available",
            onExpandedChanged: onExpandedChanged, onUseResetCredit: onUseResetCredit
        )
        .environment(\.notchAppLanguage, language)
        .frame(width: 384, height: height)
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = []
        hosting.frame = NSRect(x: 0, y: 0, width: 384, height: height)
        let window = NSWindow(contentRect: NSRect(x: -10_000, y: 1_000, width: 384, height: height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderFront(nil)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        return window
    }

    @MainActor
    private func buttons(in view: Any) -> [AnyObject] {
        accessibilityElements(in: view).filter { $0.accessibilityRole?() == .button }
    }

    @MainActor
    private func accessibilityElements(in element: Any) -> [AnyObject] {
        // SwiftUI nodes implement these public Objective-C methods without
        // declaring NSAccessibilityProtocol conformance.
        let accessible = element as AnyObject
        return [accessible] + (accessible.accessibilityChildren?() ?? []).flatMap {
            accessibilityElements(in: $0)
        }
    }

    @MainActor
    private func accessibleText(_ element: AnyObject) -> String? {
        if let label = element.accessibilityLabel?() { return label }
        let selector = #selector(NSAccessibilityProtocol.accessibilityValue)
        guard let object = element as? NSObject, object.responds(to: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue() as? String
    }
}
