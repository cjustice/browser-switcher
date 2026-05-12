import Foundation

/// Identifies which schedule slot is currently active. Each slot maps to a
/// user-configured BrowserChoice in SettingsStore.
public enum Slot: String, Codable, Sendable {
    case inWindow
    case outsideWindow
}

/// A specific browser + optional profile selection. This is what gets written
/// into the generated Finicky config.
public struct BrowserChoice: Codable, Equatable, Sendable {
    public var bundleID: String
    /// Display name as it appears in `/Applications` (Finicky matches by this name).
    public var appName: String
    /// Profile *directory* name (e.g. "Default", "Profile 1") — nil for browsers
    /// without profiles or when the user opts to use the default profile.
    public var profileDirectory: String?
    /// Human-readable profile name from the browser's metadata (e.g. "Work").
    /// Used for menu/settings display only.
    public var profileDisplayName: String?

    public init(
        bundleID: String,
        appName: String,
        profileDirectory: String? = nil,
        profileDisplayName: String? = nil
    ) {
        self.bundleID = bundleID
        self.appName = appName
        self.profileDirectory = profileDirectory
        self.profileDisplayName = profileDisplayName
    }

    public var displayLabel: String {
        if let profile = profileDisplayName, !profile.isEmpty {
            return "\(appName) — \(profile)"
        }
        return appName
    }
}
