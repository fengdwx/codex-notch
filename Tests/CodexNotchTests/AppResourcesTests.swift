import Foundation
import XCTest
@testable import CodexNotch

final class AppResourcesTests: XCTestCase {
    func testInstalledAppUsesItsOwnResourcesAndNeverBuildDirectoryFallback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Relocated.app")
        let resources = app.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let plist = ["CFBundleIdentifier": "test.resources", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Contents/Info.plist"))
        let mainBundle = try XCTUnwrap(Bundle(url: app))
        XCTAssertNil(AppResources.bundle(for: mainBundle))

        let destination = resources.appendingPathComponent("CodexNotch_CodexNotch.bundle")
        let source = try XCTUnwrap(AppResources.bundle())
        try FileManager.default.copyItem(at: source.bundleURL, to: destination)
        let loaded = try XCTUnwrap(AppResources.bundle(for: mainBundle))
        XCTAssertEqual(loaded.bundleURL.standardizedFileURL, destination.standardizedFileURL)
        XCTAssertNotNil(loaded.url(forResource: "sword-wanderer", withExtension: "webp"))
    }
}
