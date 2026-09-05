import AppKit
import Foundation

enum CodexMarkAsset {
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

    // The 36px white Codex silhouette is embedded so the notch never reads
    // another app's bundle at runtime merely to render decorative status UI.
    private static let embeddedTemplatePNGBase64 = """
    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
    """
}
