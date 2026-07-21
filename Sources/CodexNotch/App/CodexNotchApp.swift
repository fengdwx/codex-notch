import SwiftUI

@main
struct CodexNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(AppLanguage.storageKey)
    private var appLanguageRaw = AppLanguage.defaultLanguage.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage.fromStoredValue(appLanguageRaw)
    }

    var body: some Scene {
        Settings {
            NotchSettingsView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsLink {
                    Text(appLanguage.localized(chinese: "设置…", english: "Settings…"))
                }
            }
        }
    }
}
