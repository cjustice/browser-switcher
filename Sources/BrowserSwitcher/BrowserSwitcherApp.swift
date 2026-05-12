import SwiftUI

@main
struct BrowserSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // SwiftUI App requires a Scene. The real settings window is managed by AppDelegate
        // because NSApp.sendAction(showSettingsWindow:) doesn't route reliably from a
        // status-bar-only app (no key window in the responder chain).
        Settings { EmptyView() }
    }
}
