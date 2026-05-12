import Foundation
import Combine
import AppKit
import ServiceManagement

public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()

    private let defaults: UserDefaults
    private let discovery = BrowserDiscovery()

    private enum Key {
        static let startHour    = "schedule.startHour"
        static let startMinute  = "schedule.startMinute"
        static let endHour      = "schedule.endHour"
        static let endMinute    = "schedule.endMinute"
        static let enabled      = "schedule.enabled"

        static let slotChoice   = "slot.choice."       // suffix: Slot.rawValue, value: JSON-encoded BrowserChoice
        static let overrideSlot = "override.slot"      // BrowserChoice JSON for the override
        static let overrideExpiresAt = "override.expiresAt"

        // Legacy v0.1 keys, removed during migration.
        static let legacyOverrideBrowser = "override.browser"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Key.enabled) == nil {
            defaults.set(true, forKey: Key.enabled)
            defaults.set(9,  forKey: Key.startHour)
            defaults.set(0,  forKey: Key.startMinute)
            defaults.set(18, forKey: Key.endHour)
            defaults.set(0,  forKey: Key.endMinute)
        }

        migrateLegacyKeys()
        seedDefaultSlotsIfNeeded()
    }

    // MARK: Schedule

    public var schedule: Schedule {
        get {
            Schedule(
                startHour:   defaults.integer(forKey: Key.startHour),
                startMinute: defaults.integer(forKey: Key.startMinute),
                endHour:     defaults.integer(forKey: Key.endHour),
                endMinute:   defaults.integer(forKey: Key.endMinute),
                enabled:     defaults.bool(forKey: Key.enabled)
            )
        }
        set {
            defaults.set(newValue.startHour,   forKey: Key.startHour)
            defaults.set(newValue.startMinute, forKey: Key.startMinute)
            defaults.set(newValue.endHour,     forKey: Key.endHour)
            defaults.set(newValue.endMinute,   forKey: Key.endMinute)
            defaults.set(newValue.enabled,     forKey: Key.enabled)
            objectWillChange.send()
        }
    }

    // MARK: Slot configuration

    public func choice(for slot: Slot) -> BrowserChoice? {
        let key = Key.slotChoice + slot.rawValue
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(BrowserChoice.self, from: data)
        else { return nil }
        return decoded
    }

    public func setChoice(_ choice: BrowserChoice, for slot: Slot) {
        let key = Key.slotChoice + slot.rawValue
        if let data = try? JSONEncoder().encode(choice) {
            defaults.set(data, forKey: key)
        }
        objectWillChange.send()
    }

    // MARK: Override

    public var override: (choice: BrowserChoice, expiresAt: Date)? {
        guard let data = defaults.data(forKey: Key.overrideSlot),
              let choice = try? JSONDecoder().decode(BrowserChoice.self, from: data),
              let expiresAt = defaults.object(forKey: Key.overrideExpiresAt) as? Date
        else { return nil }
        return (choice, expiresAt)
    }

    /// Returns the browser choice the system should currently default to, or `nil`
    /// if paused or no slot is configured.
    public func currentChoice(now: Date = Date(), calendar: Calendar = .current) -> BrowserChoice? {
        let sched = schedule
        guard sched.enabled else { return nil }

        if let ov = override, ov.expiresAt > now {
            return ov.choice
        }
        let eval = Scheduler.evaluate(sched, at: now, calendar: calendar)
        return choice(for: eval.slot)
    }

    public func applyOverride(_ choice: BrowserChoice, now: Date = Date(), calendar: Calendar = .current) {
        let sched = schedule
        guard sched.enabled else { return }
        let eval = Scheduler.evaluate(sched, at: now, calendar: calendar)
        let scheduledChoice = self.choice(for: eval.slot)
        if scheduledChoice == choice, override == nil {
            return
        }
        if let data = try? JSONEncoder().encode(choice) {
            defaults.set(data, forKey: Key.overrideSlot)
        }
        defaults.set(eval.nextBoundary, forKey: Key.overrideExpiresAt)
        objectWillChange.send()
    }

    public func clearOverride() {
        defaults.removeObject(forKey: Key.overrideSlot)
        defaults.removeObject(forKey: Key.overrideExpiresAt)
        objectWillChange.send()
    }

    public func setPaused(_ paused: Bool) {
        var s = schedule
        s.enabled = !paused
        schedule = s
        if paused { clearOverride() }
    }

    // MARK: Launch at login

    public var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        objectWillChange.send()
    }

    // MARK: Migration / defaults seeding

    private func migrateLegacyKeys() {
        if defaults.object(forKey: Key.legacyOverrideBrowser) != nil {
            defaults.removeObject(forKey: Key.legacyOverrideBrowser)
            defaults.removeObject(forKey: Key.overrideExpiresAt)
        }
    }

    /// On first launch (or any launch where slots are unconfigured), pick reasonable
    /// defaults from the installed browser list.
    private func seedDefaultSlotsIfNeeded() {
        let browsers = discovery.installedBrowsers()
        if choice(for: .inWindow) == nil {
            if let chrome = browsers.first(where: { $0.bundleID == "com.google.Chrome" }) {
                setChoice(BrowserChoice(bundleID: chrome.bundleID, appName: chrome.appName), for: .inWindow)
            } else if let first = browsers.first {
                setChoice(BrowserChoice(bundleID: first.bundleID, appName: first.appName), for: .inWindow)
            }
        }
        if choice(for: .outsideWindow) == nil {
            if let firefox = browsers.first(where: { $0.bundleID == "org.mozilla.firefox" }) {
                setChoice(BrowserChoice(bundleID: firefox.bundleID, appName: firefox.appName), for: .outsideWindow)
            } else if let safari = browsers.first(where: { $0.bundleID == "com.apple.Safari" }) {
                setChoice(BrowserChoice(bundleID: safari.bundleID, appName: safari.appName), for: .outsideWindow)
            } else if let alt = browsers.first(where: { $0.bundleID != choice(for: .inWindow)?.bundleID }) {
                setChoice(BrowserChoice(bundleID: alt.bundleID, appName: alt.appName), for: .outsideWindow)
            }
        }
    }
}
