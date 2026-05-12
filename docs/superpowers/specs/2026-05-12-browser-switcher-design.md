# browser-switcher — Design

A macOS menu bar app that flips the default web browser between Chrome and Firefox on a weekday schedule, with manual override.

## Goals

- Default to Chrome during configured work hours on weekdays, Firefox otherwise.
- One-click manual override from the menu bar that holds until the next schedule boundary.
- Silent switch — no system confirmation dialog on each flip.
- Survives reboot; optional launch at login.

Non-goals (v1):
- Per-day custom hours.
- Multiple windows per day.
- Browsers other than Chrome and Firefox.
- Distribution outside Connor's machine (no notarization, no signing beyond local dev).

## Tech stack

- Native Swift / SwiftUI executable, packaged as a `.app` bundle.
- Swift Package Manager (`Package.swift`) with an executable target; `.app` bundle assembled via a small build script (`Info.plist` + `Contents/MacOS/<exe>`).
- `LSUIElement = true` in Info.plist — no Dock icon, no main window on launch.
- Minimum target: macOS 13 (needed for `SMAppService` launch-at-login API).

## Components

Six Swift files, each with one job.

### `AppDelegate.swift`
Wires the app together. Owns:
- the `MenuBarController`
- a `Timer` firing every 30s
- the `SettingsStore` singleton

On `applicationDidFinishLaunching`: load settings, do an immediate `evaluateAndApply()`, then start the timer. On each tick: `evaluateAndApply()`.

### `MenuBarController.swift`
Owns an `NSStatusItem`. Builds the menu (see UI section). Knows nothing about scheduling — it asks the store for "current target browser" and "override expiry" and re-renders. Handlers call into `BrowserSwitcher` and `SettingsStore` and then trigger a re-render.

### `BrowserSwitcher.swift`
Two responsibilities:
- `currentDefault() -> Browser?` — reads `LSCopyDefaultHandlerForURLScheme("https" as CFString)` and maps the bundle ID back to `.chrome`, `.firefox`, or `nil` (unknown/other).
- `setDefault(_ browser: Browser)` — calls `LSSetDefaultHandlerForURLScheme` for both `"http"` and `"https"` with the bundle ID for that browser.

LaunchServices symbols are bridged via a tiny C shim header exposed through the Swift module map (they're declared in `<CoreServices/CoreServices.h>` but not in the Swift overlay). No private framework linkage, no entitlements.

Browser presence check: `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)`. If a browser isn't installed, `setDefault` for it is a no-op and `evaluateAndApply` skips that target.

Bundle IDs:
- Chrome: `com.google.Chrome`
- Firefox: `org.mozilla.firefox`

### `Scheduler.swift`
Pure logic, no side effects, fully unit-testable.

```swift
struct Schedule {
  var start: DateComponents  // hour, minute
  var end:   DateComponents  // hour, minute
  var enabled: Bool
}

enum Browser { case chrome, firefox }

struct ScheduleEvaluation {
  let expected: Browser
  let nextBoundary: Date     // when expected would change
}

func evaluate(_ schedule: Schedule, at now: Date, calendar: Calendar) -> ScheduleEvaluation
```

`Scheduler.evaluate` assumes the schedule is enabled — the caller (`SettingsStore`) is responsible for the paused case. Rules:

- Weekend → expected is Firefox; `nextBoundary` is Monday at `start`.
- Weekday before `start` → Firefox; boundary is today at `start`.
- Weekday inside `[start, end)` → Chrome; boundary is today at `end`.
- Weekday after `end` → Firefox; boundary is the next weekday at `start`.

Uses `Calendar.current`, so DST and time zone changes are handled by the system.

### `SettingsStore.swift`
`UserDefaults`-backed, observable (`@Observable` or a simple `ObservableObject` for the Settings view).

Keys:
- `schedule.startHour: Int` (default 9)
- `schedule.startMinute: Int` (default 0)
- `schedule.endHour: Int` (default 18)
- `schedule.endMinute: Int` (default 0)
- `schedule.enabled: Bool` (default true)
- `override.browser: String?` — `"chrome"` / `"firefox"` / nil
- `override.expiresAt: Date?`
- `launchAtLogin: Bool` (mirrors `SMAppService.mainApp.status`)

Computed:
- `currentTarget(now:) -> Browser?` — returns `nil` if schedule is paused (caller will leave default unchanged); otherwise returns override if `override.expiresAt > now`, else `Scheduler.evaluate(...).expected`.
- `applyOverride(_ browser: Browser, now:)` — only valid while schedule is enabled. Sets `override.browser` and computes `expiresAt = Scheduler.evaluate(...).nextBoundary` for `now`.
- `clearOverride()` — nils both override keys.
- `setPaused(_ paused: Bool)` — sets `schedule.enabled` and clears any override when pausing.

### `SettingsView.swift`
SwiftUI `Settings` scene opened via the menu's `Settings…` item.

Form fields:
- "Schedule enabled" toggle.
- Start time `DatePicker(.hourAndMinute)`.
- End time `DatePicker(.hourAndMinute)`.
- "Launch at login" toggle backed by `SMAppService.mainApp.register()` / `.unregister()`.

Changing any value writes back to `SettingsStore` immediately and triggers `AppDelegate.evaluateAndApply()` via a notification or shared store reference.

## Core loop: `evaluateAndApply()`

Pseudocode:

```
let now = Date()

// 1. Expire override if past its boundary.
if let exp = store.override.expiresAt, now >= exp {
  store.clearOverride()
}

// 2. Pick target. nil = paused, do nothing.
guard let target = store.currentTarget(now: now) else {
  menuBarController.render()
  return
}

// 3. Apply if different and target is installed.
let current = switcher.currentDefault()
if current != target, switcher.isInstalled(target) {
  switcher.setDefault(target)
}

// 4. Re-render menu.
menuBarController.render()
```

Ticks every 30s. Also called: on app launch, after a menu click, after settings changes.

## Schedule + override semantics

- **Override expiry = next schedule boundary.** Switching to Firefox at 14:00 on a weekday with a 9–18 schedule sets `expiresAt = today 18:00`. The next tick at or after 18:00 clears the override and the schedule resumes.
- **Manual choice matching the schedule is a no-op.** If schedule already says Chrome and user clicks "Use Chrome," do not write an override. Avoids the menu showing "until 18:00" when nothing actually overrode.
- **"Pause schedule"** sets `schedule.enabled = false` and clears any override. While paused, `currentTarget` returns `nil` and `evaluateAndApply` leaves the system default alone. Clicking a browser while paused calls `BrowserSwitcher.setDefault` directly without creating an override (no boundary to expire against).

## UI

### Status item

SF Symbol `globe`, tinted blue when current default is Chrome, orange when Firefox, gray when neither (or unknown).

### Menu

```
Now: Chrome                                (disabled header)
─────────────
Use Chrome                            ⌘1
Use Firefox                           ⌘2
─────────────
Schedule: 9:00 AM – 6:00 PM Mon–Fri        (disabled)
Override active until 6:00 PM              (only if override set)
Pause schedule  /  Resume schedule          (toggle)
─────────────
Settings…
Launch at login                       ✓    (toggle)
Quit Browser Switcher                 ⌘Q
```

### Settings window

Single SwiftUI form, ~250pt wide. Closing the window just hides it; the app keeps running.

## Persistence

All state in `UserDefaults` under the app's bundle ID. No external files. `SettingsStore` is the single source of truth.

## Launch at login

`SMAppService.mainApp` (macOS 13+). Toggle in Settings calls `.register()` / `.unregister()`. The toggle UI reflects the current registration status, not just a persisted bool — query `status` each time the Settings view appears.

## Project layout

```
~/Development/browser-switcher/
├── Package.swift
├── Sources/
│   └── BrowserSwitcher/
│       ├── AppDelegate.swift
│       ├── MenuBarController.swift
│       ├── BrowserSwitcher.swift
│       ├── Scheduler.swift
│       ├── SettingsStore.swift
│       ├── SettingsView.swift
│       ├── LaunchServicesShim/      // C bridging for LS* symbols
│       │   ├── module.modulemap
│       │   └── shim.h
│       └── Resources/
│           └── Info.plist
├── Tests/
│   └── SchedulerTests/
│       └── SchedulerTests.swift
├── scripts/
│   └── build-app.sh                 // wraps `swift build` + assembles .app
└── docs/
    └── superpowers/specs/
        └── 2026-05-12-browser-switcher-design.md
```

## Testing

- `Scheduler` is pure and gets full unit coverage: each day-of-week × position-in-window combination, DST boundary days, weekend → Monday transitions.
- `SettingsStore` is tested with an in-memory `UserDefaults` (`UserDefaults(suiteName:)`).
- `BrowserSwitcher` is exercised manually — LaunchServices behavior is not unit-testable without intercepting system calls.
- Manual smoke test: install, set schedule to a 2-minute window starting in 1 minute, watch it flip, watch override hold, watch override expire.

## Risks and open questions

- **LaunchServices private-ish API.** `LSSetDefaultHandlerForURLScheme` is declared deprecated as of macOS 12 but still functional and used by other open-source utilities (e.g., `defaultbrowser` CLI). Risk: a future macOS removes it. Mitigation: if it ever breaks, fall back to invoking `defaultbrowser` CLI and accepting the one-time confirmation dialog per browser.
- **No code signing.** Running an unsigned `.app` requires right-click → Open the first time. Acceptable for a personal tool.
- **Browser uninstall mid-session.** If Chrome is uninstalled while the app is running, the next switch attempt silently no-ops. Menu shows the disabled browser grayed out on next render.
