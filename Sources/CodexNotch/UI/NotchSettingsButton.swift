import SwiftUI

/// The same explicit presentation request is used by the card and both menus.
struct NotchSettingsButton<Label: View>: View {
    private let label: Label

    init(@ViewBuilder label: () -> Label) {
        self.label = label()
    }

    var body: some View {
        Button {
            SettingsWindowPresenter.showNativeSettings()
        } label: {
            label
        }
    }
}
