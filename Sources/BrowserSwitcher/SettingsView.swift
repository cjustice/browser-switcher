import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    var onChange: () -> Void

    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var enabled: Bool = true
    @State private var launchAtLogin: Bool = false
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section("Schedule") {
                Toggle("Schedule enabled", isOn: $enabled)
                    .onChange(of: enabled) { newValue in
                        store.setPaused(!newValue)
                        onChange()
                    }
                DatePicker("Start", selection: $startDate, displayedComponents: .hourAndMinute)
                    .disabled(!enabled)
                    .onChange(of: startDate) { _ in commitSchedule() }
                DatePicker("End", selection: $endDate, displayedComponents: .hourAndMinute)
                    .disabled(!enabled)
                    .onChange(of: endDate) { _ in commitSchedule() }
                Text("Chrome during this window on weekdays. Firefox otherwise.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            try store.setLaunchAtLogin(newValue)
                            launchAtLoginError = nil
                        } catch {
                            launchAtLoginError = error.localizedDescription
                            launchAtLogin = store.launchAtLoginEnabled
                        }
                    }
                if let err = launchAtLoginError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear { loadFromStore() }
    }

    private func loadFromStore() {
        let s = store.schedule
        let cal = Calendar.current
        var sComps = DateComponents(); sComps.hour = s.startHour; sComps.minute = s.startMinute
        var eComps = DateComponents(); eComps.hour = s.endHour;   eComps.minute = s.endMinute
        startDate = cal.date(from: sComps) ?? Date()
        endDate   = cal.date(from: eComps) ?? Date()
        enabled = s.enabled
        launchAtLogin = store.launchAtLoginEnabled
    }

    private func commitSchedule() {
        let cal = Calendar.current
        let sH = cal.component(.hour, from: startDate)
        let sM = cal.component(.minute, from: startDate)
        let eH = cal.component(.hour, from: endDate)
        let eM = cal.component(.minute, from: endDate)
        var s = store.schedule
        s.startHour = sH; s.startMinute = sM
        s.endHour = eH;   s.endMinute = eM
        store.schedule = s
        onChange()
    }
}
