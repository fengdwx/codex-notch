import AppKit
import SwiftUI
import XCTest
@testable import CodexNotch

final class FloatingCenterTextFieldTests: XCTestCase {
    private final class Input: ObservableObject {
        @Published var text = "ab"
    }

    private struct FormFixture: View {
        @ObservedObject var input: Input
        var body: some View {
            Form {
                Section {
                    FloatingCenterTextField(text: $input.text, language: .english)
                }
            }
            .formStyle(.grouped)
        }
    }

    @MainActor
    func testEachTrailingSpaceAdvancesAVisibleCaretInAStableEditor() async throws {
        _ = NSApplication.shared
        let input = Input()
        let hosting = NSHostingView(rootView: FormFixture(input: input))
        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: 1_000, width: 500, height: 160),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }
        hosting.layoutSubtreeIfNeeded()
        let field = try XCTUnwrap(editableField(in: hosting))
        field.selectText(nil)
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        editor.setSelectedRange(NSRange(location: 2, length: 0))

        let initialFrame = field.convert(field.bounds, to: hosting)
        var previousCaret = caretRect(in: editor, window: window)
        for count in 1...3 {
            editor.insertText(" ", replacementRange: editor.selectedRange())
            try await Task.sleep(for: .milliseconds(20))
            hosting.layoutSubtreeIfNeeded()
            XCTAssertEqual(input.text, "ab" + String(repeating: " ", count: count))
            let caret = caretRect(in: editor, window: window)
            XCTAssertGreaterThan(caret.minX, previousCaret.minX + 1,
                                 "Every space must immediately advance the caret")
            XCTAssertGreaterThanOrEqual(caret.minX, editor.visibleRect.minX,
                                        "The caret must not move outside the leading edge")
            XCTAssertLessThanOrEqual(caret.maxX, editor.visibleRect.maxX + 1,
                                     "Trailing-space feedback must stay inside the editor")
            XCTAssertEqual(field.convert(field.bounds, to: hosting).minX, initialFrame.minX, accuracy: 1)
            XCTAssertEqual(field.bounds.width, initialFrame.width, accuracy: 1,
                           "The input area must not shrink to the visible glyphs")
            previousCaret = caret
        }
        editor.insertText("c", replacementRange: editor.selectedRange())
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(input.text, "ab   c")

        editor.deleteBackward(nil)
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(input.text, "ab   ", "Deleting a letter must preserve preceding spaces")
        editor.setSelectedRange(NSRange(location: 1, length: 0))
        editor.insertText("中", replacementRange: editor.selectedRange())
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(input.text, "a中b   ", "Middle insertion must preserve the native selection")

        let bounded = String(repeating: "文", count: 11) + "👨‍👩‍👧‍👦"
        editor.insertText(bounded + "x", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(input.text, bounded, "The twelve-Character limit must not split a composed emoji")
        XCTAssertEqual(editor.string, bounded, "The editor must reflect the accepted value at the limit")
        editor.setSelectedRange(NSRange(location: 0, length: editor.string.utf16.count))
        editor.deleteBackward(nil)
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(input.text, "", "Blank input must remain blank in storage")
    }

    @MainActor
    private func caretRect(in editor: NSTextView, window: NSWindow) -> NSRect {
        let screenRect = editor.firstRect(
            forCharacterRange: editor.selectedRange(), actualRange: nil
        )
        return editor.convert(window.convertFromScreen(screenRect), from: nil)
    }

    @MainActor
    private func editableField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        return view.subviews.lazy.compactMap { self.editableField(in: $0) }.first
    }
}
