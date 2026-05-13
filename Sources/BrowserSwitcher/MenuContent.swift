import SwiftUI
import AppKit

/// SwiftUI menu shown when the user clicks the menu bar item.
struct MenuContent: View {
    @ObservedObject var store: SettingsStore
    let configWriter: FinickyConfigWriter
    let onChange: () -> Void

    @Environment(\.openSettings) private var openSettings

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        let current = store.currentChoice()
        let sched = store.schedule
        let override = store.override

        Text("Now: \(current?.displayLabel ?? "—")")

        Divider()

        slotButton(slot: .inWindow, suffix: "Work hours", shortcut: "1")
        slotButton(slot: .outsideWindow, suffix: "After hours", shortcut: "2")

        Divider()

        if sched.enabled {
            Text("Schedule: \(formatHour(sched.startHour, sched.startMinute)) – \(formatHour(sched.endHour, sched.endMinute)) Mon–Fri")
        } else {
            Text("Schedule: paused")
        }

        if let ov = override {
            Button("Override active until \(Self.timeFormatter.string(from: ov.expiresAt)) — Clear") {
                store.clearOverride()
                onChange()
            }
        }

        Button(sched.enabled ? "Pause schedule" : "Resume schedule") {
            store.setPaused(sched.enabled)
            onChange()
        }

        Divider()

        if !configWriter.isFinickyInstalled() {
            Text("⚠ Finicky is not installed")
        } else if !configWriter.isFinickyDefaultBrowser() {
            Text("⚠ Finicky is not the default browser")
        }

        Button("Settings…") {
            openSettings()
        }
        .keyboardShortcut(",")

        Button("Quit Browser Switcher") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    @ViewBuilder
    private func slotButton(slot: Slot, suffix: String, shortcut: KeyEquivalent) -> some View {
        if let choice = store.choice(for: slot) {
            Button("Use \(choice.displayLabel)  (\(suffix))") {
                store.applyOverride(choice)
                onChange()
            }
            .keyboardShortcut(shortcut)
        } else {
            Text("\(suffix) — not configured")
        }
    }

    private func formatHour(_ hour: Int, _ minute: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let cal = Calendar.current
        let date = cal.date(from: comps) ?? Date()
        return Self.timeFormatter.string(from: date)
    }
}
