import Foundation
import AppKit
import CoreServices

@_silgen_name("LSSetDefaultHandlerForURLScheme")
private func _LSSetDefaultHandlerForURLScheme(_ scheme: CFString, _ bundleID: CFString) -> OSStatus

@_silgen_name("LSCopyDefaultHandlerForURLScheme")
private func _LSCopyDefaultHandlerForURLScheme(_ scheme: CFString) -> Unmanaged<CFString>?

public final class BrowserSwitcher {
    public init() {}

    public func currentDefault() -> Browser? {
        guard let cfStr = _LSCopyDefaultHandlerForURLScheme("https" as CFString) else {
            return nil
        }
        let bundleID = cfStr.takeRetainedValue() as String
        let normalized = bundleID.lowercased()
        if normalized == Browser.chrome.bundleID.lowercased() { return .chrome }
        if normalized == Browser.firefox.bundleID.lowercased() { return .firefox }
        return nil
    }

    public func isInstalled(_ browser: Browser) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID) != nil
    }

    @discardableResult
    public func setDefault(_ browser: Browser) -> Bool {
        guard isInstalled(browser) else { return false }
        let bundleID = browser.bundleID as CFString
        let s1 = _LSSetDefaultHandlerForURLScheme("http" as CFString, bundleID)
        let s2 = _LSSetDefaultHandlerForURLScheme("https" as CFString, bundleID)
        return s1 == noErr && s2 == noErr
    }
}
