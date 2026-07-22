import AppKit
import Foundation

enum ChatGPTMarkAsset {
    static let templateImage: NSImage? = {
        guard let data = Data(
            base64Encoded: embeddedTemplatePNGBase64,
            options: .ignoreUnknownCharacters
        ), let image = NSImage(data: data) else {
            return nil
        }

        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()

    // Keep the notch mark inside CodexNotch so rendering it never requires
    // reading another application's bundle or requesting App Management.
    private static let embeddedTemplatePNGBase64 = """
    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
    """
}
