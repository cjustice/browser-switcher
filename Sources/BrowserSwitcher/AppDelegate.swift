import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = SettingsStore.shared
    let configWriter = FinickyConfigWriter()
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        NSSetUncaughtExceptionHandler { exc in
            NSLog("BrowserSwitcher uncaught: \(exc.name.rawValue) — \(exc.reason ?? "(no reason)")")
        }

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

        if let choice = store.currentChoice(now: now) {
            do {
                try configWriter.write(choice)
            } catch {
                NSLog("Browser Switcher: failed to write Finicky config: \(error)")
            }
        }
    }
}
