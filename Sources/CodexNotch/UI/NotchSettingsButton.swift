import SwiftUI

/// The same explicit presentation request is used by the card and both menus.
struct NotchSettingsButton<Label: View>: View {
    @Environment(\.openSettings) private var openSettings
    private let label: Label

    init(@ViewBuilder label: () -> Label) {
        self.label = label()
    }

    var body: some View {
        Button {
            SettingsWindowPresenter.show { openSettings() }
        } label: {
            label
        }
    }
}
