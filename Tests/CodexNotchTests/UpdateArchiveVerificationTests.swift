import CryptoKit
import Foundation
import XCTest

final class UpdateArchiveVerificationTests: XCTestCase {
    func testReleaseGuardAcceptsMatchingSignatureAndRejectsTamperingAndWrongPublisher() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let archive = directory.appendingPathComponent("fixture.zip")
        let feed = directory.appendingPathComponent("appcast.xml")
        let plist = directory.appendingPathComponent("Info.plist")
        // A disposable in-memory test key; never read the publisher's Keychain.
        let key = Curve25519.Signing.PrivateKey()
        let payload = Data("release fixture".utf8)
        try payload.write(to: archive)
        let signature = try key.signature(for: payload).base64EncodedString()
        try """
        <rss><channel><item>
        <sparkle:version>19</sparkle:version>
        <sparkle:shortVersionString>0.2.1</sparkle:shortVersionString>
        <enclosure url="https://github.com/fengdwx/codex-notch/releases/download/v0.2.1/fixture.zip"
            sparkle:edSignature="\(signature)" length="\(payload.count)" />
        </item></channel></rss>
        """.write(to: feed, atomically: true, encoding: .utf8)

        func writeInfo(publicKey: Data, build: String = "19") throws {
            try PropertyListSerialization.data(fromPropertyList: [
                "SUPublicEDKey": publicKey.base64EncodedString(),
                "CFBundleShortVersionString": "0.2.1", "CFBundleVersion": build
            ], format: .xml, options: 0).write(to: plist)
        }
        func verify() throws -> (Int32, String) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
            process.arguments = [root.appendingPathComponent("scripts/verify_update.swift").path,
                                 feed.path, archive.path, plist.path]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        }
        try writeInfo(publicKey: key.publicKey.rawRepresentation)
        let valid = try verify()
        XCTAssertEqual(valid.0, 0, valid.1)

        var corrupted = payload
        corrupted[0] ^= 1 // Same length, so only cryptographic verification detects the change.
        try corrupted.write(to: archive)
        let tampered = try verify()
        XCTAssertNotEqual(tampered.0, 0)
        XCTAssertTrue(tampered.1.contains("signature invalid"), tampered.1)

        try payload.write(to: archive)
        try writeInfo(publicKey: Curve25519.Signing.PrivateKey().publicKey.rawRepresentation)
        let wrongPublisher = try verify()
        XCTAssertNotEqual(wrongPublisher.0, 0)
        XCTAssertTrue(wrongPublisher.1.contains("signature invalid"), wrongPublisher.1)

        try writeInfo(publicKey: key.publicKey.rawRepresentation, build: "20")
        let wrongBuild = try verify()
        XCTAssertNotEqual(wrongBuild.0, 0)
        XCTAssertTrue(wrongBuild.1.contains("build does not match"), wrongBuild.1)
    }
}
