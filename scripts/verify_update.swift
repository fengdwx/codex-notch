import CryptoKit
import Foundation

// Public-key-only verification: this tool never opens the Keychain.
final class FeedReader: NSObject, XMLParserDelegate {
    var enclosures: [[String: String]] = []
    var values: [String: String] = [:]
    private var element = ""
    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        element = elementName
        if elementName == "enclosure" { enclosures.append(attributeDict) }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        values[element, default: ""] += string
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        element = ""
    }
}

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw NSError(domain: "CodexNotch.Release", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: message]) }
}

do {
    try require(CommandLine.arguments.count == 4,
                "usage: swift verify_update.swift appcast.xml archive.zip Info.plist")
    let args = CommandLine.arguments
    let info = try PropertyListSerialization.propertyList(
        from: Data(contentsOf: URL(fileURLWithPath: args[3])), format: nil
    ) as? [String: Any] ?? [:]
    let feed = FeedReader()
    let parser = XMLParser(data: try Data(contentsOf: URL(fileURLWithPath: args[1])))
    parser.shouldResolveExternalEntities = false
    parser.delegate = feed
    try require(parser.parse(), "Invalid appcast XML")
    try require(feed.enclosures.count == 1, "Expected exactly one full update archive")
    let enclosure = feed.enclosures[0]
    let archive = try Data(contentsOf: URL(fileURLWithPath: args[2]))
    let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation:
        Data(base64Encoded: info["SUPublicEDKey"] as? String ?? "") ?? Data())
    let signature = Data(base64Encoded: enclosure["sparkle:edSignature"] ?? "") ?? Data()
    try require(publicKey.isValidSignature(signature, for: archive),
                "Update signature invalid or missing; archive or publisher key does not match")
    try require(Int(enclosure["length"] ?? "") == archive.count, "Update length mismatch")
    let version = info["CFBundleShortVersionString"] as? String ?? ""
    let build = info["CFBundleVersion"] as? String ?? ""
    try require(feed.values["sparkle:version"]?.trimmingCharacters(in: .whitespacesAndNewlines) == build,
                "Archive build does not match current app build")
    try require(feed.values["sparkle:shortVersionString"]?.trimmingCharacters(in: .whitespacesAndNewlines) == version,
                "Archive version does not match current app version")
    let expectedURL = "https://github.com/fengdwx/codex-notch/releases/download/v\(version)/" +
        URL(fileURLWithPath: args[2]).lastPathComponent
    try require(enclosure["url"] == expectedURL, "Unexpected release download URL")
    print("Verified update: v\(version) (\(build)), Ed25519 signature and archive length valid")
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
