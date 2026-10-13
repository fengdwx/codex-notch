import Foundation
import XCTest
@testable import CodexNotch

final class CodexUsageClientTests: XCTestCase {
    func testProductionSessionDoesNotPersistSensitiveResponses() {
        XCTAssertNil(CodexUsageClient.defaultSession.configuration.urlCache)
        XCTAssertNil(CodexUsageClient.defaultSession.configuration.urlCredentialStorage)
    }

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

    func testResetCreditDetailsUseTheDedicatedEndpointAndKeepAvailableCredits() async throws {
        let usageData = try Data(contentsOf: fixtureURL("usage-weekly-only.json"))
        let resetCreditData = try Data(contentsOf: fixtureURL("rate-limit-reset-credits.json"))
        MockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/backend-api/wham/usage":
                return (self.response(status: 200), usageData)
            case "/backend-api/wham/rate-limit-reset-credits":
                return (self.response(status: 200), resetCreditData)
            default:
                XCTFail("Unexpected endpoint: \(request.url?.absoluteString ?? "nil")")
                return (self.response(status: 404), Data())
            }
        }

        let snapshot = try await makeClient().fetch()

        XCTAssertEqual(snapshot.resetCreditsAvailable, 5)
        XCTAssertEqual(snapshot.resetCredits.map(\.id), [
            "credit-july-18",
            "credit-july-27",
            "credit-august-1",
            "credit-august-12",
            "credit-august-13"
        ])
        XCTAssertEqual(snapshot.resetCredits.map(\.title), Array(repeating: "Full reset", count: 5))
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

    func testAuthoritativeEmptyCreditsClearPreviouslyReportedCredits() async throws {
        let usageData = Data("""
        {"rate_limit_reset_credits":{"available_count":1,"credits":[
          {"id":"previous-credit","status":"available"}
        ]}}
        """.utf8)
        MockURLProtocol.requestHandler = { request in
            let data = request.url?.lastPathComponent == "usage"
                ? usageData : Data(#"{"available_count":0,"credits":[]}"#.utf8)
            return (self.response(status: 200), data)
        }

        let snapshot = try await makeClient().fetch()

        XCTAssertEqual(snapshot.resetCreditsAvailable, 0)
        XCTAssertTrue(snapshot.resetCredits.isEmpty)
    }

    func testForbiddenIsNotReportedAsExpiredAuthentication() async throws {
        MockURLProtocol.requestHandler = { _ in
            (self.response(status: 403), Data())
        }
        do {
            _ = try await makeClient().fetch()
            XCTFail("Expected a forbidden error")
        } catch let error as CodexUsageError {
            XCTAssertEqual(error, .httpStatus(403))
        }
    }

    func testCancelledDetailsRequestDoesNotReturnSuccessfulUsage() async throws {
        let usageData = try Data(contentsOf: fixtureURL("usage-weekly-only.json"))
        MockURLProtocol.requestHandler = { request in
            if request.url?.lastPathComponent != "usage" {
                throw URLError(.cancelled)
            }
            return (self.response(status: 200), usageData)
        }
        do {
            _ = try await makeClient().fetch()
            XCTFail("Cancellation must propagate")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .cancelled)
        }
    }

    func testMissingDetailListPreservesUsageCount() async throws {
        let usageData = try Data(contentsOf: fixtureURL("usage-weekly-only.json"))
        MockURLProtocol.requestHandler = { request in
            let data = request.url?.lastPathComponent == "usage" ? usageData : Data("{}".utf8)
            return (self.response(status: 200), data)
        }
        let snapshot = try await makeClient().fetch()
        XCTAssertEqual(snapshot.resetCreditsAvailable, 2)
        XCTAssertEqual(snapshot.weeklyWindow?.usedPercent, 5)
    }

    func testFailedDetailsPreserveUsageCountAndQuota() async throws {
        let usageData = try Data(contentsOf: fixtureURL("usage-weekly-only.json"))
        MockURLProtocol.requestHandler = { request in
            request.url?.lastPathComponent == "usage"
                ? (self.response(status: 200), usageData)
                : (self.response(status: 503), Data())
        }
        let snapshot = try await makeClient().fetch()
        XCTAssertEqual(snapshot.resetCreditsAvailable, 2)
        XCTAssertEqual(snapshot.weeklyWindow?.usedPercent, 5)
    }

    func testStrictRefreshDoesNotReportDetailFailureAsRefreshed() async throws {
        let usageData = try Data(contentsOf: fixtureURL("usage-weekly-only.json"))
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            return request.url?.lastPathComponent == "usage"
                ? (self.response(status: 200), usageData)
                : (self.response(status: 503), Data())
        }
        do {
            _ = try await makeClient().fetch(requireResetCredits: true)
            XCTFail("Both quota and credit details must refresh successfully")
        } catch let error as CodexUsageError {
            XCTAssertEqual(error, .httpStatus(503))
        }
    }

    func testStrictRefreshRequiresDetailsEvenWhenSummaryCountIsAvailable() async throws {
        let usageData = try Data(contentsOf: fixtureURL("usage-weekly-only.json"))
        MockURLProtocol.requestHandler = { request in
            let data = request.url?.lastPathComponent == "usage"
                ? usageData : Data(#"{"available_count":1}"#.utf8)
            return (self.response(status: 200), data)
        }
        do {
            _ = try await makeClient().fetch(requireResetCredits: true)
            XCTFail("A count alone cannot confirm refreshed credit details")
        } catch let error as CodexUsageError {
            XCTAssertEqual(error, .decodingFailed)
        }
    }

    func testStrictRefreshAcceptsAuthoritativeEmptyCreditDetails() async throws {
        let usageData = try Data(contentsOf: fixtureURL("usage-weekly-only.json"))
        MockURLProtocol.requestHandler = { request in
            let data = request.url?.lastPathComponent == "usage"
                ? usageData : Data(#"{"available_count":0,"credits":[]}"#.utf8)
            return (self.response(status: 200), data)
        }
        let snapshot = try await makeClient().fetch(requireResetCredits: true)
        XCTAssertEqual(snapshot.resetCreditsAvailable, 0)
        XCTAssertTrue(snapshot.resetCredits.isEmpty)
    }

    func testDirectDetailsFetchAndRedemptionIdentityValidation() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.lastPathComponent, "rate-limit-reset-credits")
            return (self.response(status: 200), Data("""
            {"available_count":6,"credits":[
              {"id":"real-id","status":"available","expires_at":"2030-01-01T00:00:00.000Z"},
              {"status":"available"},
              {"id":" ","status":"available"},
              {"id":"expired","status":"available","expires_at":"2020-01-01T00:00:00Z"},
              {"id":"invalid-expiry","status":"available","expires_at":"invalid"},
              {"id":"nonexpiring","status":"available","expires_at":null},
              {"id":"used","status":"redeemed"}
            ]}
            """.utf8))
        }
        let details = try await makeClient().fetchResetCredits()
        let credits = details.availableCredits
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(credits.count, 6)
        XCTAssertEqual(credits[0].redemptionID, "real-id")
        XCTAssertNil(credits[1].redemptionID)
        XCTAssertEqual(credits.map { $0.canRedeem(at: now) }, [true, false, false, false, false, true])
        XCTAssertFalse(credits[0].canRedeem(at: try XCTUnwrap(credits[0].expiresAt)))
        XCTAssertEqual(ResetCredit(id: "constructed").redemptionID, "constructed")
    }

    func testConsumeSendsSelectedCreditAndStableKeyOnceWithAccountHeaders() async throws {
        var requestCount = 0
        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/backend-api/wham/rate-limit-reset-credits/consume")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-access-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "acct_fixture")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: self.requestBody(request)) as? [String: String])
            XCTAssertEqual(body, ["credit_id": "selected-credit", "redeem_request_id": "stable-attempt-id"])
            return (self.response(status: 200), Data(#"{"code":"reset","windows_reset":2}"#.utf8))
        }
        let outcome = try await makeClient().consumeResetCredit(
            creditID: "selected-credit", idempotencyKey: "stable-attempt-id"
        )
        XCTAssertEqual(outcome, .reset)
        XCTAssertEqual(requestCount, 1)
    }

    func testConsumeMapsAllNonResetOutcomesWithoutReportingNewReset() async throws {
        let cases: [(String, ResetCreditConsumptionOutcome)] = [
            ("nothing_to_reset", .nothingToReset),
            ("no_credit", .noCredit),
            ("already_redeemed", .alreadyRedeemed)
        ]
        for (code, expected) in cases {
            MockURLProtocol.requestHandler = { _ in
                (self.response(status: 200), Data("{\"code\":\"\(code)\",\"windows_reset\":0}".utf8))
            }
            let outcome = try await makeClient().consumeResetCredit(creditID: "credit", idempotencyKey: "attempt")
            XCTAssertEqual(outcome, expected)
        }
    }

    func testUnknownOrMissingConsumeOutcomeFailsClosed() async throws {
        for body in [#"{"code":"new_unknown_code"}"#, "{}", "not-json"] {
            MockURLProtocol.requestHandler = { _ in (self.response(status: 200), Data(body.utf8)) }
            do {
                _ = try await makeClient().consumeResetCredit(creditID: "credit", idempotencyKey: "attempt")
                XCTFail("An unrecognized response cannot confirm a reset")
            } catch let error as CodexUsageError {
                XCTAssertEqual(error, .decodingFailed)
            }
        }
    }

    func testConsumeRejectsEmptyIdentifiersWithoutRequest() async throws {
        MockURLProtocol.requestHandler = { _ in
            XCTFail("Invalid requests must not reach the backend")
            return (self.response(status: 200), Data())
        }
        for (creditID, key) in [("", "attempt"), ("credit", ""), (" \n", "attempt")] {
            do {
                _ = try await makeClient().consumeResetCredit(creditID: creditID, idempotencyKey: key)
                XCTFail("Expected validation failure")
            } catch let error as CodexUsageError {
                XCTAssertEqual(error, .invalidResetRequest)
            }
        }
    }

    func testConsumeFailureKeepsOnlySafeStatusAndCodeAndDoesNotRetry() async throws {
        var requestCount = 0
        MockURLProtocol.requestHandler = { _ in
            requestCount += 1
            return (self.response(status: 403), Data(#"{"error":{"code":"forbidden","message":"fixture-private-server-message"}}"#.utf8))
        }
        do {
            _ = try await makeClient().consumeResetCredit(creditID: "credit", idempotencyKey: "attempt")
            XCTFail("Expected forbidden result")
        } catch let error as CodexUsageError {
            XCTAssertEqual(error, .resetHTTPStatus(status: 403, code: "forbidden"))
            XCTAssertFalse(String(describing: error).contains("fixture-private-server-message"))
        }
        XCTAssertEqual(requestCount, 1)
    }

    func testConsumeDoesNotExposeArbitraryServerCodeOrBody() async throws {
        MockURLProtocol.requestHandler = { _ in
            (self.response(status: 500), Data(#"{"code":"fixture-private-value","message":"fixture-private-body"}"#.utf8))
        }
        do {
            _ = try await makeClient().consumeResetCredit(creditID: "credit", idempotencyKey: "attempt")
            XCTFail("Expected server failure")
        } catch let error as CodexUsageError {
            XCTAssertEqual(error, .resetHTTPStatus(status: 500, code: nil))
        }
    }

    func testConsumeUnauthorizedRequiresReauthentication() async throws {
        MockURLProtocol.requestHandler = { _ in (self.response(status: 401), Data()) }
        do {
            _ = try await makeClient().consumeResetCredit(creditID: "credit", idempotencyKey: "attempt")
            XCTFail("Expected authentication failure")
        } catch let error as CodexUsageError {
            XCTAssertEqual(error, .reauthenticationRequired)
        }
    }

    func testConsumeDetailCodeIsAlsoRestrictedToSafeKnownValues() async throws {
        for code in ["permission_denied", "fixture-private-code"] {
            MockURLProtocol.requestHandler = { _ in
                (self.response(status: 403), Data("{\"detail\":{\"code\":\"\(code)\"}}".utf8))
            }
            do {
                _ = try await makeClient().consumeResetCredit(creditID: "credit", idempotencyKey: "attempt")
                XCTFail("Expected forbidden result")
            } catch let error as CodexUsageError {
                XCTAssertEqual(error, .resetHTTPStatus(
                    status: 403, code: code == "permission_denied" ? code : nil
                ))
            }
        }
    }

    func testConsumeTimeoutDoesNotRetry() async throws {
        var requestCount = 0
        MockURLProtocol.requestHandler = { _ in
            requestCount += 1
            throw URLError(.timedOut)
        }
        do {
            _ = try await makeClient().consumeResetCredit(creditID: "credit", idempotencyKey: "attempt")
            XCTFail("Expected timeout")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        }
        XCTAssertEqual(requestCount, 1)
    }

    private func requestBody(_ request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            result.append(contentsOf: buffer.prefix(count))
        }
        return result
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
