import Combine
import Sparkle

/// One updater for the lifetime of the app, started only by a manual check.
@MainActor
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    @Published private(set) var canCheckForUpdates = true
    @Published private(set) var startupError: String?

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
    )
    private var availability: AnyCancellable?
    private var started = false

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        startupError = nil
        if !started {
            do {
                try controller.updater.start()
                started = true
                availability = controller.updater.publisher(for: \.canCheckForUpdates)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] in self?.canCheckForUpdates = $0 }
            } catch {
                startupError = error.localizedDescription
                return
            }
        }
        controller.checkForUpdates(nil)
    }
}
