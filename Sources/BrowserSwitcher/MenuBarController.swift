import AppKit
import SwiftUI

@MainActor
public final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let store: SettingsStore
    private let configWriter: FinickyConfigWriter
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
        configWriter: FinickyConfigWriter,
        onChange: @escaping () -> Void,
        onShowSettings: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.store = store
        self.configWriter = configWriter
        self.onChange = onChange
        self.onShowSettings = onShowSettings
        super.init()
        statusItem.menu = NSMenu()
        statusItem.menu?.delegate = self
        render()
    }

    public func render() {
        guard let button = statusItem.button else { return }
        let current = store.currentChoice()
        let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Browser Switcher")
        image?.isTemplate = true
        button.image = image
        button.toolTip = current.map { "Default browser: \($0.displayLabel)" } ?? "Default browser: (paused)"
        rebuildMenu(current: current)
    }

    private func rebuildMenu(current: BrowserChoice?) {
        let menu = statusItem.menu ?? NSMenu()
        menu.removeAllItems()

        let header = NSMenuItem(title: "Now: \(current?.displayLabel ?? "—")", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let sched = store.schedule
        addSlotItem(to: menu, slot: .inWindow, label: "In-window", current: current, keyEquivalent: "1", paused: !sched.enabled)
        addSlotItem(to: menu, slot: .outsideWindow, label: "Out-of-window", current: current, keyEquivalent: "2", paused: !sched.enabled)
        menu.addItem(.separator())

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

        if !configWriter.isFinickyInstalled() {
            let warn = NSMenuItem(title: "⚠ Finicky is not installed", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
        } else if !configWriter.isFinickyDefaultBrowser() {
            let warn = NSMenuItem(title: "⚠ Finicky is not the default browser", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
        }

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit Browser Switcher", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func addSlotItem(
        to menu: NSMenu,
        slot: Slot,
        label: String,
        current: BrowserChoice?,
        keyEquivalent: String,
        paused: Bool
    ) {
        let choice = store.choice(for: slot)
        let title: String
        if let choice {
            title = "Use \(choice.displayLabel)  (\(label))"
        } else {
            title = "Use \(label) — not configured"
        }
        let item = NSMenuItem(title: title, action: #selector(useSlot(_:)), keyEquivalent: keyEquivalent)
        item.target = self
        item.representedObject = slot.rawValue
        item.state = (current == choice && choice != nil) ? .on : .off
        item.isEnabled = (choice != nil) && !paused
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

    @objc private func useSlot(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let slot = Slot(rawValue: raw),
              let choice = store.choice(for: slot) else { return }
        store.applyOverride(choice)
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
