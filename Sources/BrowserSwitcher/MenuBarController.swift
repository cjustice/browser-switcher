import AppKit
import SwiftUI

@MainActor
public final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let store: SettingsStore
    private let switcher: BrowserSwitcher
    private let onChange: () -> Void
    private let onShowSettings: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    public init(
        store: SettingsStore,
        switcher: BrowserSwitcher,
        onChange: @escaping () -> Void,
        onShowSettings: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.store = store
        self.switcher = switcher
        self.onChange = onChange
        self.onShowSettings = onShowSettings
        super.init()
        statusItem.menu = NSMenu()
        statusItem.menu?.delegate = self
        render()
    }

    public func render() {
        guard let button = statusItem.button else { return }
        let current = switcher.currentDefault()
        let symbolName: String
        switch current {
        case .chrome:  symbolName = "globe.americas.fill"
        case .firefox: symbolName = "globe.europe.africa.fill"
        case .none:    symbolName = "globe"
        }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Browser Switcher")
        image?.isTemplate = true
        button.image = image
        button.toolTip = current.map { "Default browser: \($0.displayName)" } ?? "Default browser: unknown"

        rebuildMenu(current: current)
    }

    private func rebuildMenu(current: Browser?) {
        let menu = statusItem.menu ?? NSMenu()
        menu.removeAllItems()

        let header = NSMenuItem(title: "Now: \(current?.displayName ?? "—")", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        addBrowserItem(to: menu, browser: .chrome, current: current, keyEquivalent: "1")
        addBrowserItem(to: menu, browser: .firefox, current: current, keyEquivalent: "2")
        menu.addItem(.separator())

        let sched = store.schedule
        let scheduleLine: String
        if sched.enabled {
            scheduleLine = "Schedule: \(formatTime(hour: sched.startHour, minute: sched.startMinute)) – \(formatTime(hour: sched.endHour, minute: sched.endMinute)) Mon–Fri"
        } else {
            scheduleLine = "Schedule: paused"
        }
        let scheduleItem = NSMenuItem(title: scheduleLine, action: nil, keyEquivalent: "")
        scheduleItem.isEnabled = false
        menu.addItem(scheduleItem)

        if let ov = store.override {
            let line = "Override active until \(Self.timeFormatter.string(from: ov.expiresAt))"
            let item = NSMenuItem(title: line, action: #selector(clearOverride), keyEquivalent: "")
            item.target = self
            item.toolTip = "Click to clear override"
            menu.addItem(item)
        }

        let pauseItem = NSMenuItem(
            title: sched.enabled ? "Pause schedule" : "Resume schedule",
            action: #selector(togglePause),
            keyEquivalent: ""
        )
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit Browser Switcher", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func addBrowserItem(to menu: NSMenu, browser: Browser, current: Browser?, keyEquivalent: String) {
        let item = NSMenuItem(
            title: "Use \(browser.displayName)",
            action: #selector(useBrowser(_:)),
            keyEquivalent: keyEquivalent
        )
        item.target = self
        item.representedObject = browser.rawValue
        item.state = (current == browser) ? .on : .off
        item.isEnabled = switcher.isInstalled(browser)
        if !item.isEnabled {
            item.toolTip = "\(browser.displayName) is not installed"
        }
        menu.addItem(item)
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let cal = Calendar.current
        let date = cal.date(from: comps) ?? Date()
        return Self.timeFormatter.string(from: date)
    }

    // MARK: Actions

    @objc private func useBrowser(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let browser = Browser(rawValue: raw) else { return }
        if store.schedule.enabled {
            store.applyOverride(browser)
        }
        switcher.setDefault(browser)
        onChange()
    }

    @objc private func clearOverride() {
        store.clearOverride()
        onChange()
    }

    @objc private func togglePause() {
        store.setPaused(store.schedule.enabled)
        onChange()
    }

    @objc private func openSettings() {
        onShowSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
