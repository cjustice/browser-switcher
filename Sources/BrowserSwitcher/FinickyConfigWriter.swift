import Foundation
import AppKit

/// Writes Finicky's `~/.finicky.js` config based on the current browser choice.
/// Finicky's fsnotify watcher reloads automatically (~500ms debounce).
public final class FinickyConfigWriter {

    public static let finickyBundleID = "se.johnste.finicky"

    private let configPath: URL
    private let managedMarker = "// Managed by Browser Switcher — do not edit by hand."

    public init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.configPath = home.appendingPathComponent(".finicky.js")
    }

    public var configURL: URL { configPath }

    /// Write the config in place. Returns true if a write occurred (i.e. content changed).
    ///
    /// The write is deliberately NOT atomic: a rename-replace destroys the inode
    /// Finicky's fsnotify watcher is attached to, and Finicky treats that as
    /// "config removed" and stops watching until it is relaunched. An in-place
    /// truncate+write keeps the inode, and Finicky's 500ms debounce absorbs any
    /// partially-written intermediate state.
    @discardableResult
    public func write(_ choice: BrowserChoice) throws -> Bool {
        let newContents = Self.render(managedMarker: managedMarker, choice: choice)
        if let existing = try? String(contentsOf: configPath, encoding: .utf8), existing == newContents {
            return false
        }
        try newContents.write(to: configPath, atomically: false, encoding: .utf8)
        return true
    }

    public func isFinickyInstalled() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.finickyBundleID) != nil
    }

    /// Reads the current default HTTP handler via LaunchServices. Used to check
    /// whether Finicky has been set as default.
    public func isFinickyDefaultBrowser() -> Bool {
        guard let url = URL(string: "https://example.com") else { return false }
        guard let handler = NSWorkspace.shared.urlForApplication(toOpen: url),
              let bundle = Bundle(url: handler) else { return false }
        return bundle.bundleIdentifier == Self.finickyBundleID
    }

    // MARK: Rendering

    static func render(managedMarker: String, choice: BrowserChoice) -> String {
        let appName = jsString(choice.appName)
        var lines: [String] = []
        lines.append(managedMarker)
        lines.append("// Regenerated whenever the active schedule slot or override changes.")
        lines.append("")
        lines.append("export default {")
        if let profile = choice.profileDirectory, !profile.isEmpty {
            lines.append("  defaultBrowser: {")
            lines.append("    name: \(appName),")
            lines.append("    profile: \(jsString(profile)),")
            lines.append("  },")
        } else {
            lines.append("  defaultBrowser: { name: \(appName) },")
        }
        lines.append("  options: {")
        lines.append("    hideIcon: true,")
        lines.append("  },")
        lines.append("};")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// Encode a string as a JS double-quoted literal. Escapes the small set of
    /// characters that matter for our generated values (app/profile names).
    private static func jsString(_ s: String) -> String {
        var escaped = ""
        for ch in s {
            switch ch {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            case "\n": escaped += "\\n"
            case "\r": escaped += "\\r"
            case "\t": escaped += "\\t"
            default:   escaped.append(ch)
            }
        }
        return "\"\(escaped)\""
    }
}
