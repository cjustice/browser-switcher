import SwiftUI

@main
struct BrowserSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(
                store: SettingsStore.shared,
                configWriter: FinickyConfigWriter(),
                onChange: { appDelegate.evaluateAndApply() }
            )
        } label: {
            Image(systemName: "arrow.left.arrow.right")
        }

        Settings {
            SettingsView(store: SettingsStore.shared) {
                appDelegate.evaluateAndApply()
            }
        }
    }
}
