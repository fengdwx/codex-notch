import Foundation
import XCTest
@testable import CodexNotch

@MainActor
final class ResetCreditRedemptionTests: XCTestCase {
    private let credentials = CodexCredentials(accessToken: "fixture-token", accountID: "fixture-account")
    private let credit = ResetCredit(id: "fixture-credit")

    func testAmbiguousFailureReusesKeyAndSuccessfulCreditCannotBeConsumedTwice() async throws {
        var keys: [String] = []
        let controller = ResetCreditRedemptionController(
            readCredentials: { self.credentials },
            fetchCredits: { _ in [self.credit] },
            consume: { _, _, key in
                keys.append(key)
                if keys.count == 1 { throw URLError(.timedOut) }
                return .reset
            }
        )
        do {
            _ = try await controller.redeem(credit, expectedCredentials: credentials)
            XCTFail("Expected timeout")
        } catch { XCTAssertEqual((error as? URLError)?.code, .timedOut) }
        XCTAssertEqual(keys.count, 1, "Never automatically retry a write")
        let outcome = try await controller.redeem(credit, expectedCredentials: credentials)
        XCTAssertEqual(outcome, .reset)
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(keys[0], keys[1])
        do {
            _ = try await controller.redeem(credit, expectedCredentials: credentials)
            XCTFail("A stale row must not consume again")
        } catch { XCTAssertEqual(error as? ResetCreditRedemptionError, .unavailable) }
        XCTAssertEqual(keys.count, 2)
    }

    func testRefreshAndAccountChangePreventConsumption() async throws {
        var current = credentials
        var consumeCount = 0
        let controller = ResetCreditRedemptionController(
            readCredentials: { current },
            fetchCredits: { _ in
                current = CodexCredentials(accessToken: "other-token", accountID: "other-account")
                return [self.credit]
            },
            consume: { _, _, _ in consumeCount += 1; return .reset }
        )
        do {
            _ = try await controller.redeem(credit, expectedCredentials: credentials)
            XCTFail("Account changed during refresh")
        } catch { XCTAssertEqual(error as? ResetCreditRedemptionError, .accountChanged) }
        XCTAssertEqual(consumeCount, 0)
    }

    func testDefiniteNoOpAllowsANewAttemptWithANewKey() async throws {
        var keys: [String] = []
        let controller = ResetCreditRedemptionController(
            readCredentials: { self.credentials },
            fetchCredits: { _ in [self.credit] },
            consume: { _, _, key in
                keys.append(key)
                return keys.count == 1 ? .nothingToReset : .reset
            }
        )
        let first = try await controller.redeem(credit, expectedCredentials: credentials)
        let second = try await controller.redeem(credit, expectedCredentials: credentials)
        XCTAssertEqual(first, .nothingToReset)
        XCTAssertEqual(second, .reset)
        XCTAssertEqual(keys.count, 2)
        XCTAssertNotEqual(keys[0], keys[1])
    }

    func testFeedbackDistinguishesConfirmedResetFromFailedReadback() {
        for language in [AppLanguage.chinese, .english] {
            let message = ResetCreditFeedback.message(.success(.reset), refreshed: false, language: language)
            XCTAssertTrue(message.contains(language.localized(chinese: "重置成功", english: "confirmed")))
            XCTAssertTrue(message.contains(language.localized(chinese: "刷新失败", english: "could not be refreshed")))
            let unknown = ResetCreditFeedback.message(.failure(URLError(.timedOut)), refreshed: true, language: language)
            XCTAssertTrue(unknown.contains(language.localized(chinese: "未能确认", english: "could not be confirmed")))
        }
    }

    func testExpiredOrUnavailableCreditNeverConsumes() async throws {
        var consumeCount = 0
        let controller = ResetCreditRedemptionController(
            readCredentials: { self.credentials },
            fetchCredits: { _ in [] },
            consume: { _, _, _ in consumeCount += 1; return .reset }
        )
        for candidate in [credit, ResetCredit(id: "expired", expiresAt: .distantPast)] {
            do {
                _ = try await controller.redeem(candidate, expectedCredentials: credentials)
                XCTFail("Unavailable credit")
            } catch { XCTAssertEqual(error as? ResetCreditRedemptionError, .unavailable) }
        }
        XCTAssertEqual(consumeCount, 0)
    }

    func testConcurrentRequestsAreRejectedBeforeSecondWrite() async throws {
        var release: CheckedContinuation<Void, Never>?
        var consumeCount = 0
        let controller = ResetCreditRedemptionController(
            readCredentials: { self.credentials },
            fetchCredits: { _ in [self.credit] },
            consume: { _, _, _ in
                consumeCount += 1
                await withCheckedContinuation { release = $0 }
                return .reset
            }
        )
        let first = Task { try await controller.redeem(credit, expectedCredentials: credentials) }
        while release == nil { await Task.yield() }
        do {
            _ = try await controller.redeem(credit, expectedCredentials: credentials)
            XCTFail("Expected busy")
        } catch { XCTAssertEqual(error as? ResetCreditRedemptionError, .busy) }
        release?.resume()
        _ = try await first.value
        XCTAssertEqual(consumeCount, 1)
        XCTAssertFalse(controller.isProcessing)
    }
}
