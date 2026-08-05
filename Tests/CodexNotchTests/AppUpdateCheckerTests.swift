import Foundation
import XCTest
@testable import CodexNotch

final class AppUpdateCheckerTests: XCTestCase {
    override func tearDown() {
        UpdateMockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testSemanticVersionsIgnoreVPrefixAndCompareComponents() throws {
        let current = try XCTUnwrap(AppVersion(rawValue: "v0.1.11"))
        let newer = try XCTUnwrap(AppVersion(rawValue: "0.1.12"))
        let older = try XCTUnwrap(AppVersion(rawValue: "0.1.10"))

        XCTAssertEqual(current.displayValue, "v0.1.11")
        XCTAssertTrue(newer > current)
        XCTAssertTrue(older < current)
    }

    func testMalformedSemanticVersionsAreRejected() {
        XCTAssertNil(AppVersion(rawValue: ""))
        XCTAssertNil(AppVersion(rawValue: "v0.1"))
        XCTAssertNil(AppVersion(rawValue: "0.01.2"))
        XCTAssertNil(AppVersion(rawValue: "release"))
    }

    func testNewerStableReleaseIsReportedWithoutAuthorizationHeader() async throws {
        UpdateMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
            return (
                self.response(status: 200),
                self.releaseData(tag: "v0.1.12")
            )
        }

        let result = try await makeChecker().check()

        guard case let .updateAvailable(current, release) = result else {
            return XCTFail("Expected a newer release")
        }
        XCTAssertEqual(current.displayValue, "v0.1.11")
        XCTAssertEqual(release.version.displayValue, "v0.1.12")
        XCTAssertEqual(release.url.absoluteString, "https://github.com/fengdwx/codex-notch/releases/tag/v0.1.12")
    }

    func testCurrentStableReleaseIsReportedAsUpToDate() async throws {
        UpdateMockURLProtocol.requestHandler = { _ in
            (self.response(status: 200), self.releaseData(tag: "v0.1.11"))
        }

        let result = try await makeChecker().check()

        XCTAssertEqual(
            result,
            .upToDate(current: try XCTUnwrap(AppVersion(rawValue: "0.1.11")))
        )
    }

    func testOlderStableReleaseIsReportedAsUpToDate() async throws {
        UpdateMockURLProtocol.requestHandler = { _ in
            (self.response(status: 200), self.releaseData(tag: "v0.1.10"))
        }

        let result = try await makeChecker().check()

        guard case .upToDate = result else {
            return XCTFail("An older release must not be offered as an update")
        }
    }

    func testHTTPFailureIsReported() async throws {
        UpdateMockURLProtocol.requestHandler = { _ in
            (self.response(status: 503), Data())
        }

        do {
            _ = try await makeChecker().check()
            XCTFail("Expected an HTTP error")
        } catch let error as AppUpdateError {
            XCTAssertEqual(error, .httpStatus(503))
        }
    }

    func testDraftOrPrereleaseMetadataIsRejected() async throws {
        UpdateMockURLProtocol.requestHandler = { _ in
            (self.response(status: 200), self.releaseData(tag: "v0.2.0", prerelease: true))
        }

        do {
            _ = try await makeChecker().check()
            XCTFail("Expected invalid release metadata")
        } catch let error as AppUpdateError {
            XCTAssertEqual(error, .invalidReleaseMetadata)
        }
    }

    func testReleaseLinkMustStayOnGitHub() async throws {
        UpdateMockURLProtocol.requestHandler = { _ in
            (
                self.response(status: 200),
                self.releaseData(
                    tag: "v0.2.0",
                    htmlURL: "https://example.com/codex-notch/releases/tag/v0.2.0"
                )
            )
        }

        do {
            _ = try await makeChecker().check()
            XCTFail("Expected an invalid release link")
        } catch let error as AppUpdateError {
            XCTAssertEqual(error, .invalidReleaseMetadata)
        }
    }

    private func makeChecker() throws -> AppUpdateChecker {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UpdateMockURLProtocol.self]
        return AppUpdateChecker(
            currentVersion: try XCTUnwrap(AppVersion(rawValue: "0.1.11")),
            session: URLSession(configuration: configuration),
            endpoint: URL(string: "https://api.example.test/repos/fengdwx/codex-notch/releases/latest")!
        )
    }

    private func releaseData(
        tag: String,
        draft: Bool = false,
        prerelease: Bool = false,
        htmlURL: String? = nil
    ) -> Data {
        let json: [String: Any] = [
            "tag_name": tag,
            "html_url": htmlURL ?? "https://github.com/fengdwx/codex-notch/releases/tag/\(tag)",
            "draft": draft,
            "prerelease": prerelease
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func response(status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.example.test/repos/fengdwx/codex-notch/releases/latest")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}

private final class UpdateMockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.requestHandler else {
                throw URLError(.badServerResponse)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
