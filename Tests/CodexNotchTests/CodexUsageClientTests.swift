import Foundation
import XCTest
@testable import CodexNotch

final class CodexUsageClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testWeeklyOnlyResponseCreatesOneWeeklyWindow() async throws {
        let responseData = try Data(contentsOf: fixtureURL("usage-weekly-only.json"))
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-access-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "acct_fixture")
            return (self.response(status: 200), responseData)
        }

        let snapshot = try await makeClient().fetch()

        XCTAssertEqual(snapshot.windows.count, 1)
        XCTAssertEqual(snapshot.windows.first?.kind, .weekly)
        XCTAssertEqual(snapshot.windows.first?.usedPercent, 5)
        XCTAssertEqual(snapshot.resetCreditsAvailable, 2)
    }

    func testMultipleWindowsAreClassifiedIndependently() async throws {
        let responseData = try Data(contentsOf: fixtureURL("usage-multiple-windows.json"))
        MockURLProtocol.requestHandler = { _ in
            (self.response(status: 200), responseData)
        }

        let snapshot = try await makeClient().fetch()

        XCTAssertEqual(snapshot.windows.map(\.kind), [.rolling(hours: 5), .weekly])
        XCTAssertEqual(snapshot.windows.map(\.id), ["primary", "secondary"])
    }

    func testCurrentResponseReadsWindowsNestedUnderRateLimit() async throws {
        let responseData = try Data(contentsOf: fixtureURL("usage-nested-rate-limit.json"))
        MockURLProtocol.requestHandler = { _ in
            (self.response(status: 200), responseData)
        }

        let snapshot = try await makeClient().fetch()

        XCTAssertEqual(snapshot.windows.count, 1)
        XCTAssertEqual(snapshot.windows.first?.kind, .weekly)
        XCTAssertEqual(snapshot.windows.first?.usedPercent, 20)
        XCTAssertEqual(snapshot.windows.first?.remainingPercent, 80)
        XCTAssertEqual(snapshot.resetCreditsAvailable, 2)
    }

    func testUnauthorizedResponseRequiresReauthentication() async throws {
        MockURLProtocol.requestHandler = { _ in
            (self.response(status: 401), Data())
        }

        do {
            _ = try await makeClient().fetch()
            XCTFail("Expected a reauthentication error")
        } catch let error as CodexUsageError {
            XCTAssertEqual(error, .reauthenticationRequired)
        }
    }

    private func makeClient() -> CodexUsageClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return CodexUsageClient(
            credentials: CodexCredentials(
                accessToken: "fixture-access-token",
                accountID: "acct_fixture"
            ),
            session: URLSession(configuration: configuration),
            endpoint: URL(string: "https://example.test/backend-api/wham/usage")!
        )
    }

    private func response(status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.test/backend-api/wham/usage")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private func fixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
    }
}

private final class MockURLProtocol: URLProtocol {
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
