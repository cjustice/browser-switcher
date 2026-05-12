import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    var onChange: () -> Void

    private let discovery = BrowserDiscovery()
    private let configWriter = FinickyConfigWriter()

    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var enabled: Bool = true
    @State private var launchAtLogin: Bool = false
    @State private var launchAtLoginError: String?

    @State private var inWindowChoice: BrowserChoice?
    @State private var outsideWindowChoice: BrowserChoice?

    @State private var browsers: [(bundleID: String, appName: String, url: URL)] = []

    var body: some View {
        Form {
            if !configWriter.isFinickyInstalled() {
                Section {
                    Label("Finicky is not installed. Install it with `brew install --cask finicky` and re-launch this app.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            } else if !configWriter.isFinickyDefaultBrowser() {
                Section {
                    HStack(alignment: .top) {
                        Label("Finicky must be set as your default browser for switching to work.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.general") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }

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
            }

            Section("Inside work hours (weekdays)") {
                slotPicker(for: .inWindow, binding: $inWindowChoice)
            }

            Section("Outside work hours / weekends") {
                slotPicker(for: .outsideWindow, binding: $outsideWindowChoice)
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
        .frame(width: 420)
        .onAppear { loadFromStore() }
    }

    @ViewBuilder
    private func slotPicker(for slot: Slot, binding: Binding<BrowserChoice?>) -> some View {
        Picker("Browser", selection: Binding(
            get: { binding.wrappedValue?.bundleID ?? "" },
            set: { newBundle in
                guard let browser = browsers.first(where: { $0.bundleID == newBundle }) else { return }
                let next = BrowserChoice(bundleID: browser.bundleID, appName: browser.appName)
                binding.wrappedValue = next
                store.setChoice(next, for: slot)
                onChange()
            }
        )) {
            ForEach(browsers, id: \.bundleID) { b in
                Text(b.appName).tag(b.bundleID)
            }
        }

        let profiles = binding.wrappedValue.flatMap { discovery.profiles(for: $0.bundleID) } ?? []
        if !profiles.isEmpty, let current = binding.wrappedValue {
            Picker("Profile", selection: Binding(
                get: { current.profileDirectory ?? "" },
                set: { newDir in
                    var updated = current
                    if newDir.isEmpty {
                        updated.profileDirectory = nil
                        updated.profileDisplayName = nil
                    } else if let p = profiles.first(where: { $0.directory == newDir }) {
                        updated.profileDirectory = p.directory
                        updated.profileDisplayName = p.displayName
                    }
                    binding.wrappedValue = updated
                    store.setChoice(updated, for: slot)
                    onChange()
                }
            )) {
                Text("(default profile)").tag("")
                ForEach(profiles, id: \.directory) { p in
                    Text(p.displayName).tag(p.directory)
                }
            }
        }
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
        browsers = discovery.installedBrowsers()
        inWindowChoice = store.choice(for: .inWindow)
        outsideWindowChoice = store.choice(for: .outsideWindow)
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
