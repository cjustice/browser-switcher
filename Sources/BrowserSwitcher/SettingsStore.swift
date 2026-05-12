import Foundation
import Combine
import ServiceManagement

public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()

    private let defaults: UserDefaults

    private enum Key {
        static let startHour    = "schedule.startHour"
        static let startMinute  = "schedule.startMinute"
        static let endHour      = "schedule.endHour"
        static let endMinute    = "schedule.endMinute"
        static let enabled      = "schedule.enabled"
        static let overrideBrowser   = "override.browser"
        static let overrideExpiresAt = "override.expiresAt"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Seed defaults on first launch.
        if defaults.object(forKey: Key.enabled) == nil {
            defaults.set(true, forKey: Key.enabled)
            defaults.set(9,  forKey: Key.startHour)
            defaults.set(0,  forKey: Key.startMinute)
            defaults.set(18, forKey: Key.endHour)
            defaults.set(0,  forKey: Key.endMinute)
        }
    }

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

    public var override: (browser: Browser, expiresAt: Date)? {
        guard
            let raw = defaults.string(forKey: Key.overrideBrowser),
            let browser = Browser(rawValue: raw),
            let expiresAt = defaults.object(forKey: Key.overrideExpiresAt) as? Date
        else { return nil }
        return (browser, expiresAt)
    }

    /// Returns the browser the system should currently default to, or `nil` if
    /// the schedule is paused (caller should leave the system default alone).
    public func currentTarget(now: Date = Date(), calendar: Calendar = .current) -> Browser? {
        let sched = schedule
        guard sched.enabled else { return nil }

        if let ov = override, ov.expiresAt > now {
            return ov.browser
        }
        return Scheduler.evaluate(sched, at: now, calendar: calendar).expected
    }

    /// Apply a manual override. No-op if the schedule already wants `browser`
    /// (we don't create override state for a choice that matches the schedule).
    public func applyOverride(_ browser: Browser, now: Date = Date(), calendar: Calendar = .current) {
        let sched = schedule
        guard sched.enabled else {
            // Paused — caller will call BrowserSwitcher directly. Don't record an override.
            return
        }
        let eval = Scheduler.evaluate(sched, at: now, calendar: calendar)
        if eval.expected == browser, override == nil {
            return
        }
        defaults.set(browser.rawValue, forKey: Key.overrideBrowser)
        defaults.set(eval.nextBoundary, forKey: Key.overrideExpiresAt)
        objectWillChange.send()
    }

    public func clearOverride() {
        defaults.removeObject(forKey: Key.overrideBrowser)
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
}
