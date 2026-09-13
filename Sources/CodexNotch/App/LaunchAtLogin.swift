import Combine
import ServiceManagement

/// System Settings owns this preference; merely opening the app never registers it.
@MainActor
final class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()

    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorMessage: String?

    private let readStatus: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () throws -> Void

    init(
        readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
        register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
        unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() }
    ) {
        self.readStatus = readStatus
        self.register = register
        self.unregister = unregister
        status = readStatus()
    }

    /// A pending request stays cancellable, but is never described as enabled.
    var isRequested: Bool { status == .enabled || status == .requiresApproval }

    func refresh() {
        status = readStatus()
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        refresh()
        guard enabled != isRequested else { return }
        do {
            if enabled {
                try register()
            } else {
                try unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        // Read back even after failure instead of optimistically saving a Boolean.
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
