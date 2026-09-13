import ServiceManagement
import XCTest
@testable import CodexNotch

final class LaunchAtLoginTests: XCTestCase {
    @MainActor
    func testOpeningSettingsDoesNotOptIn() async {
        let service = LoginItemStub()
        let model = service.makeModel()
        model.refresh()
        XCTAssertFalse(model.isRequested)
        XCTAssertEqual(service.mutations, 0)
    }

    @MainActor
    func testInitiallyMissingLoginItemCanBeRegistered() async {
        let service = LoginItemStub()
        service.status = .notFound
        let model = service.makeModel()
        XCTAssertFalse(model.isRequested)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(service.mutations, 0)
        model.setEnabled(true)
        XCTAssertEqual(model.status, .enabled)
        XCTAssertNil(model.errorMessage)
    }

    @MainActor
    func testToggleRegistersAndRemovesLoginItem() async {
        let service = LoginItemStub()
        let model = service.makeModel()
        model.setEnabled(true)
        XCTAssertEqual(model.status, .enabled)
        XCTAssertTrue(model.isRequested)
        model.setEnabled(false)
        XCTAssertEqual(model.status, .notRegistered)
        XCTAssertFalse(model.isRequested)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(service.mutations, 2)
    }

    @MainActor
    func testExternalDisableIsReadBackWithoutRegisteringAgain() async {
        let service = LoginItemStub()
        service.status = .enabled
        let model = service.makeModel()
        XCTAssertTrue(model.isRequested)
        service.status = .notRegistered
        model.refresh()
        XCTAssertFalse(model.isRequested)
        XCTAssertEqual(service.mutations, 0)
    }

    @MainActor
    func testPendingApprovalIsExplicitAndCanBeCancelled() async {
        let service = LoginItemStub()
        service.registrationResult = .requiresApproval
        let model = service.makeModel()
        model.setEnabled(true)
        XCTAssertEqual(model.status, .requiresApproval)
        XCTAssertNotEqual(model.status, .enabled)
        XCTAssertTrue(model.isRequested)
        model.setEnabled(false)
        XCTAssertFalse(model.isRequested)
        XCTAssertEqual(service.status, .notRegistered)
    }

    @MainActor
    func testApprovalGrantedOutsideAppIsReflectedOnRefresh() async {
        let service = LoginItemStub()
        service.status = .requiresApproval
        let model = service.makeModel()
        service.status = .enabled
        model.refresh()
        XCTAssertEqual(model.status, .enabled)
        XCTAssertEqual(service.mutations, 0)
    }

    @MainActor
    func testFailedRegistrationDoesNotShowSuccessAndCanBeRetried() async {
        let service = LoginItemStub()
        service.shouldFail = true
        let model = service.makeModel()
        model.setEnabled(true)
        XCTAssertFalse(model.isRequested)
        XCTAssertNotNil(model.errorMessage)
        service.shouldFail = false
        model.setEnabled(true)
        XCTAssertEqual(model.status, .enabled)
        XCTAssertNil(model.errorMessage)
    }

    @MainActor
    func testFailedRemovalRetainsActualEnabledState() async {
        let service = LoginItemStub()
        service.status = .enabled
        service.shouldFail = true
        let model = service.makeModel()
        model.setEnabled(false)
        XCTAssertEqual(model.status, .enabled)
        XCTAssertTrue(model.isRequested)
        XCTAssertNotNil(model.errorMessage)
    }
}

@MainActor
private final class LoginItemStub {
    var status: SMAppService.Status = .notRegistered
    var registrationResult: SMAppService.Status = .enabled
    var shouldFail = false
    var mutations = 0

    func makeModel() -> LaunchAtLogin {
        LaunchAtLogin(
            readStatus: { self.status },
            register: {
                self.mutations += 1
                if self.shouldFail { throw CocoaError(.fileWriteNoPermission) }
                self.status = self.registrationResult
            },
            unregister: {
                self.mutations += 1
                if self.shouldFail { throw CocoaError(.fileWriteNoPermission) }
                self.status = .notRegistered
            }
        )
    }
}
