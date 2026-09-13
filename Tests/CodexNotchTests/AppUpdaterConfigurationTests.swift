import CryptoKit
import Foundation
import XCTest
@testable import CodexNotch

final class AppUpdaterConfigurationTests: XCTestCase {
    func testDistributedUpdaterRequiresArchiveVerificationAndNoBackgroundActivity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/Info.plist"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        for key in ["SUEnableAutomaticChecks", "SUAutomaticallyUpdate", "SUAllowsAutomaticUpdates", "SUEnableSystemProfiling"] {
            XCTAssertEqual(plist[key] as? Bool, false, key)
        }
        XCTAssertEqual(plist["SUVerifyUpdateBeforeExtraction"] as? Bool, true)
        let publicKey = try XCTUnwrap(plist["SUPublicEDKey"] as? String)
        let bytes = try XCTUnwrap(Data(base64Encoded: publicKey))
        XCTAssertNoThrow(try Curve25519.Signing.PublicKey(rawRepresentation: bytes))
        let feed = try XCTUnwrap(URL(string: try XCTUnwrap(plist["SUFeedURL"] as? String)))
        XCTAssertEqual(feed.scheme, "https")
        XCTAssertEqual(feed.host, "raw.githubusercontent.com")
        XCTAssertEqual(feed.path, "/fengdwx/codex-notch/main/appcast.xml")
        XCTAssertNil(feed.user)
        XCTAssertNil(feed.query)
    }

    @MainActor
    func testSettingsCanCreateUpdaterWithoutStartingAnUpdateSession() {
        // Creating Settings must not start Sparkle, request permission, or check a feed.
        let updater = AppUpdater()
        XCTAssertTrue(updater.canCheckForUpdates)
        XCTAssertNil(updater.startupError)
    }
}
