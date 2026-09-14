import SwiftUI

struct FloatingCenterTextField: View {
    @Binding var text: String
    let language: AppLanguage

    var body: some View {
        let label = language.localized(chinese: "自定义文字", english: "Custom text")
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
            // The grouped Form's automatic trailing-aligned field hides
            // trailing spaces. Keep native editing in a stable leading lane.
            TextField(label, text: $text, prompt: Text(FloatingCenterText.defaultText))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(label)
        }
        .onChange(of: text) { _, value in
            let limited = String(value.prefix(FloatingCenterText.maximumCharacters))
            if limited != value { text = limited }
        }
    }
}
