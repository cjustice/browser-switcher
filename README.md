# Browser Switcher

A tiny macOS menu bar app that automatically swaps your default browser on a weekday schedule, with a manual override. Supports any installed browser plus Chrome-style profiles.

The idea: keep work tabs in one browser/profile during work hours, push everything else (link previews from chat, idle tabs at night, weekend browsing) to another — without having to remember to change anything.

## What it does

- Two configurable "slots": **inside work hours** (weekdays, configurable window — default `9:00 AM – 6:00 PM`) and **outside work hours / weekends**.
- Each slot is a browser + optional profile. Browsers are auto-discovered from your installed apps. For Chromium-based browsers (Chrome, Edge, Brave, Arc, Vivaldi), profiles are auto-discovered too.
- One-click override from the menu bar. The override holds until the next schedule boundary, then the schedule resumes.
- Optional launch at login.

## How it works

Browser Switcher drives [Finicky](https://github.com/johnste/finicky) — Finicky is the URL-routing engine that actually dispatches links to the right browser + profile. This app generates Finicky's `~/.finicky.js` config file whenever the active slot or override changes; Finicky's file watcher auto-reloads.

You need to:
1. `brew install --cask finicky`
2. Set Finicky as your default web browser in **System Settings → Default web browser**.
3. Launch Browser Switcher and configure your two slots.

## Menu

```
Now: Chrome — Work
─────────────
Use Chrome — Work  (In-window)         ⌘1
Use Firefox  (Out-of-window)           ⌘2
─────────────
Schedule: 9:00 AM – 6:00 PM Mon–Fri
Override active until 6:00 PM      (only when override is set)
Pause schedule
─────────────
Settings…                              ⌘,
Quit Browser Switcher                  ⌘Q
```

## Install (from source)

Requirements: macOS 13+, Xcode command-line tools (`xcode-select --install`).

```sh
git clone https://github.com/cjustice/browser-switcher.git
cd browser-switcher
./scripts/build-app.sh
open "build/Browser Switcher.app"
```

To install permanently:

```sh
cp -R "build/Browser Switcher.app" /Applications/
```

Then open it from `/Applications` and enable **Launch at login** in Settings.

### Cutting a new release

```sh
./scripts/release.sh 0.2.0
```

Builds, tags `v0.2.0`, and creates a GitHub Release with the zipped `.app` attached.

## Internals

A `Timer` runs every 30 seconds. Each tick: evaluate the schedule (or active override), resolve the active slot to a `BrowserChoice`, and atomically rewrite `~/.finicky.js`. Finicky's fsnotify watcher reloads automatically (~500ms debounce). The schedule logic itself is pure and has unit coverage in `Tests/SchedulerTests`.

State (schedule window, slot choices, override, paused flag) is persisted in `UserDefaults` under bundle ID `com.connorjustice.BrowserSwitcher`.

## Limitations

- **Requires Finicky.** Install with `brew install --cask finicky` and set it as your default browser in System Settings.
- **Profile auto-discovery is Chromium-only.** Chrome, Edge, Brave, Arc, Vivaldi work. Safari has no profiles. Firefox has profiles but Finicky's Firefox profile dispatch is alpha-only as of Finicky 4.2.2.
- **Unsigned binary.** Built locally with ad-hoc signing. macOS Gatekeeper will warn on first launch — right-click the app → **Open**, or go to **System Settings → Privacy & Security** and click *Open Anyway*.
- **Launch at login** uses `SMAppService`, which can silently fail for unsigned apps on some macOS versions. If the toggle doesn't stick, the Settings window surfaces the error.

## Project layout

```
Package.swift
Sources/BrowserSwitcher/
  BrowserSwitcherApp.swift   # @main + SwiftUI App scene
  AppDelegate.swift          # NSApplicationDelegate, tick loop, settings window
  MenuBarController.swift    # NSStatusItem + menu construction
  BrowserChoice.swift        # Slot enum + BrowserChoice value type
  BrowserDiscovery.swift     # Installed browsers + Chromium profile enumeration
  FinickyConfigWriter.swift  # Writes ~/.finicky.js + checks Finicky status
  Scheduler.swift            # Pure schedule logic (returns active slot)
  SettingsStore.swift        # UserDefaults persistence + override semantics
  SettingsView.swift         # SwiftUI settings form
  Resources/Info.plist
Tests/SchedulerTests/        # 8 unit tests for the scheduler
scripts/build-app.sh         # swift build + assemble .app bundle
scripts/release.sh           # Tag + build + create GitHub Release
```
