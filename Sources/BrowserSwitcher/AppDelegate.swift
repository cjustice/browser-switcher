import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = SettingsStore.shared
    let switcher = BrowserSwitcher()
    var menuBar: MenuBarController!
    private var settingsWindow: NSWindow?
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        menuBar = MenuBarController(
            store: store,
            switcher: switcher,
            onChange: { [weak self] in self?.evaluateAndApply() },
            onShowSettings: { [weak self] in self?.showSettings() }
        )
        evaluateAndApply()

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateAndApply()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func evaluateAndApply() {
        let now = Date()

        if let ov = store.override, now >= ov.expiresAt {
            store.clearOverride()
        }

        guard let target = store.currentTarget(now: now) else {
            menuBar?.render()
            return
        }

        if switcher.isInstalled(target), switcher.currentDefault() != target {
            switcher.setDefault(target)
        }

        menuBar?.render()
    }

    func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(store: store) { [weak self] in
                self?.evaluateAndApply()
            }
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Browser Switcher"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
