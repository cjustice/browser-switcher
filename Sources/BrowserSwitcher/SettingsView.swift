import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    var onChange: () -> Void

    private let discovery = BrowserDiscovery()
    private let configWriter = FinickyConfigWriter()

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var enabled: Bool
    @State private var launchAtLogin: Bool
    @State private var launchAtLoginError: String?

    @State private var inWindowChoice: BrowserChoice?
    @State private var outsideWindowChoice: BrowserChoice?

    @State private var browsers: [(bundleID: String, appName: String, url: URL)]

    // External state — must be refreshed on activation / after API calls
    // because SwiftUI can't observe changes that happen outside the view graph.
    @State private var finickyInstalled: Bool
    @State private var finickyIsDefault: Bool

    init(store: SettingsStore, onChange: @escaping () -> Void) {
        self.store = store
        self.onChange = onChange

        let s = store.schedule
        let cal = Calendar.current
        var sComps = DateComponents(); sComps.hour = s.startHour; sComps.minute = s.startMinute
        var eComps = DateComponents(); eComps.hour = s.endHour;   eComps.minute = s.endMinute
        _startDate = State(initialValue: cal.date(from: sComps) ?? Date())
        _endDate   = State(initialValue: cal.date(from: eComps) ?? Date())
        _enabled = State(initialValue: s.enabled)
        _launchAtLogin = State(initialValue: store.launchAtLoginEnabled)

        let discovered = BrowserDiscovery().installedBrowsers()
        _browsers = State(initialValue: discovered)
        _inWindowChoice = State(initialValue: store.choice(for: .inWindow))
        _outsideWindowChoice = State(initialValue: store.choice(for: .outsideWindow))

        let writer = FinickyConfigWriter()
        _finickyInstalled = State(initialValue: writer.isFinickyInstalled())
        _finickyIsDefault = State(initialValue: writer.isFinickyDefaultBrowser())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                warningBanner
                scheduleCard

                slotCard(
                    title: "Inside work hours",
                    subtitle: "Mon–Fri during the window above",
                    accent: .blue,
                    slot: .inWindow,
                    binding: $inWindowChoice
                )

                slotCard(
                    title: "Outside work hours",
                    subtitle: "Evenings and weekends",
                    accent: .orange,
                    slot: .outsideWindow,
                    binding: $outsideWindowChoice
                )

                startupCard
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 480, minHeight: 540)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            refreshFinickyStatus()
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // App regained focus — likely after the system "Make default browser?" dialog closed.
            refreshFinickyStatus()
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Browser Switcher").font(.title2).bold()
                Text("Drives Finicky to swap browsers on a schedule.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var warningBanner: some View {
        if !finickyInstalled {
            banner(
                tint: .orange,
                icon: "exclamationmark.triangle.fill",
                title: "Finicky is not installed",
                detail: "Install it with `brew install --cask finicky`, then re-launch this app.",
                action: nil
            )
        } else if !finickyIsDefault {
            banner(
                tint: .orange,
                icon: "exclamationmark.triangle.fill",
                title: "Finicky must be the default browser",
                detail: "macOS will ask for confirmation, then Finicky will route every link.",
                action: ("Make Finicky default", promptMakeFinickyDefault)
            )
        }
    }

    private func banner(
        tint: Color,
        icon: String,
        title: String,
        detail: String,
        action: (String, () -> Void)?
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline).bold()
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if let action {
                Button(action.0) { action.1() }
                    .controlSize(.small)
            }
        }
        .padding(14)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var scheduleCard: some View {
        card(title: "Schedule") {
            Toggle("Active on weekdays", isOn: $enabled)
                .onChange(of: enabled) { _, newValue in
                    store.setPaused(!newValue)
                    onChange()
                }
            HStack(spacing: 12) {
                Text("Start").frame(width: 60, alignment: .leading)
                DatePicker("", selection: $startDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(minWidth: 120)
                    .fixedSize()
                    .disabled(!enabled)
                    .onChange(of: startDate) { _, _ in commitSchedule() }
                Spacer()
            }
            HStack(spacing: 12) {
                Text("End").frame(width: 60, alignment: .leading)
                DatePicker("", selection: $endDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(minWidth: 120)
                    .fixedSize()
                    .disabled(!enabled)
                    .onChange(of: endDate) { _, _ in commitSchedule() }
                Spacer()
            }
        }
    }

    private func slotCard(
        title: String,
        subtitle: String,
        accent: Color,
        slot: Slot,
        binding: Binding<BrowserChoice?>
    ) -> some View {
        card(title: title, subtitle: subtitle, accent: accent) {
            if browsers.isEmpty {
                Text("No browsers detected.").foregroundStyle(.secondary)
            } else {
                let currentBundle = binding.wrappedValue?.bundleID
                    ?? browsers.first?.bundleID
                    ?? ""

                HStack(spacing: 12) {
                    Text("Browser").frame(width: 60, alignment: .leading)
                    Picker("", selection: Binding(
                        get: { currentBundle },
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
                    .labelsHidden()
                }

                let profiles = discovery.profiles(for: currentBundle)
                if !profiles.isEmpty {
                    let currentProfileDir = binding.wrappedValue?.profileDirectory ?? ""
                    HStack(spacing: 12) {
                        Text("Profile").frame(width: 60, alignment: .leading)
                        Picker("", selection: Binding(
                            get: { currentProfileDir },
                            set: { newDir in
                                guard var updated = binding.wrappedValue else { return }
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
                            Text("Default").tag("")
                            ForEach(profiles, id: \.directory) { p in
                                Text(p.displayName).tag(p.directory)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }
        }
    }

    private var startupCard: some View {
        card(title: "Startup") {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
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

    // MARK: Card primitive

    @ViewBuilder
    private func card<Content: View>(
        title: String,
        subtitle: String? = nil,
        accent: Color? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let accent {
                    Circle().fill(accent).frame(width: 8, height: 8)
                }
                Text(title).font(.headline)
            }
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            content()
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.gray.opacity(0.15))
        )
    }

    // MARK: Actions

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

    private func promptMakeFinickyDefault() {
        guard let finickyURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: FinickyConfigWriter.finickyBundleID
        ) else { return }

        // macOS shows its standard confirmation dialog. We register http and
        // https — Finicky needs both to handle every URL.
        NSWorkspace.shared.setDefaultApplication(at: finickyURL, toOpenURLsWithScheme: "https") { error in
            if let error {
                NSLog("Browser Switcher: setDefaultApplication(https) failed: \(error)")
                return
            }
            NSWorkspace.shared.setDefaultApplication(at: finickyURL, toOpenURLsWithScheme: "http") { error in
                if let error {
                    NSLog("Browser Switcher: setDefaultApplication(http) failed: \(error)")
                }
                DispatchQueue.main.async {
                    refreshFinickyStatus()
                }
            }
        }
    }

    private func refreshFinickyStatus() {
        finickyInstalled = configWriter.isFinickyInstalled()
        finickyIsDefault = configWriter.isFinickyDefaultBrowser()
    }
}
