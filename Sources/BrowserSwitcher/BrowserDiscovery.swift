import Foundation
import AppKit

/// Discovers installed browsers and, for Chromium-based browsers, their profiles.
public struct BrowserDiscovery {

    /// A discovered profile (directory + human name) for a given browser.
    public struct ProfileInfo: Equatable, Hashable {
        public let directory: String
        public let displayName: String
    }

    public init() {}

    /// Apps that register as URL handlers for "http://". Returns sorted by app name.
    /// Filtered to skip known non-browser handlers.
    public func installedBrowsers() -> [(bundleID: String, appName: String, url: URL)] {
        guard let probe = URL(string: "http://example.com"),
              let urls = LSCopyApplicationURLsForURL(probe as CFURL, .all)?.takeRetainedValue() as? [URL]
        else {
            return []
        }
        var seen = Set<String>()
        var results: [(String, String, URL)] = []
        for url in urls {
            guard let bundle = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier,
                  !seen.contains(bundleID) else { continue }
            seen.insert(bundleID)
            if Self.skipList.contains(bundleID) { continue }
            let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                    ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                    ?? url.deletingPathExtension().lastPathComponent
            results.append((bundleID, name, url))
        }
        return results.sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    /// Returns profiles for a given browser, if discoverable. Currently supports
    /// Chromium-based browsers via their `Local State` JSON file.
    public func profiles(for bundleID: String) -> [ProfileInfo] {
        guard let localStatePath = Self.chromiumLocalStatePath(for: bundleID) else {
            return []
        }
        guard let data = try? Data(contentsOf: localStatePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: [String: Any]]
        else {
            return []
        }
        var profiles: [ProfileInfo] = infoCache.map { directory, info in
            let name = (info["name"] as? String) ?? directory
            return ProfileInfo(directory: directory, displayName: name)
        }
        // "Default" first, then sorted by display name.
        profiles.sort { lhs, rhs in
            if lhs.directory == "Default" { return true }
            if rhs.directory == "Default" { return false }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        return profiles
    }

    public func isInstalled(bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    // MARK: Internals

    /// Bundle IDs to hide from the browser picker — apps that register as
    /// HTTP handlers but aren't general-purpose browsers.
    private static let skipList: Set<String> = [
        "com.apple.webkit.webcontent",
        "com.apple.helpviewer",
        "com.apple.dt.Xcode",
    ]

    /// Path to the Chromium `Local State` file for a given browser bundle ID.
    /// Returns nil for non-Chromium browsers.
    private static func chromiumLocalStatePath(for bundleID: String) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let appSupport = home.appendingPathComponent("Library/Application Support")
        let relative: String?
        switch bundleID {
        case "com.google.Chrome":              relative = "Google/Chrome"
        case "com.google.Chrome.canary":       relative = "Google/Chrome Canary"
        case "com.google.Chrome.beta":         relative = "Google/Chrome Beta"
        case "com.microsoft.edgemac":          relative = "Microsoft Edge"
        case "com.brave.Browser":              relative = "BraveSoftware/Brave-Browser"
        case "company.thebrowser.Browser":     relative = "Arc/User Data"
        case "com.vivaldi.Vivaldi":            relative = "Vivaldi"
        default: return nil
        }
        return appSupport.appendingPathComponent(relative!).appendingPathComponent("Local State")
    }
}
