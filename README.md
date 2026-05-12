# Browser Switcher

A tiny macOS menu bar app that automatically swaps your default browser between Chrome and Firefox on a weekday schedule, with a manual override.

The idea: keep work in Chrome during work hours, push everything else (link previews from chat, idle tabs at night, weekend browsing) to Firefox — without having to remember to change anything.

## What it does

- Sets your default browser to **Chrome** inside a configurable weekday window (default `9:00 AM – 6:00 PM`, Mon–Fri).
- Sets it to **Firefox** outside that window and on weekends.
- Switches silently via LaunchServices — no system confirmation dialog on each flip (after a one-time gate, see Limitations).
- One-click override from the menu bar. If you switch manually, the override holds until the next schedule boundary, then the schedule resumes.
- Optional launch at login.

## Menu

```
Now: Chrome
─────────────
Use Chrome                            ⌘1
Use Firefox                           ⌘2
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

## How it works

The app calls `LSSetDefaultHandlerForURLScheme` for the `http` and `https` schemes whenever the schedule (or an active override) says the default should change. A `Timer` runs every 30 seconds and re-evaluates; the schedule itself is pure logic with full unit test coverage in `Tests/SchedulerTests`.

State (schedule window, override expiry, paused flag) is persisted in `UserDefaults` under bundle ID `com.connorjustice.BrowserSwitcher`.

## Limitations

- **First switch may trigger a system prompt.** Modern macOS gates default-browser changes with a confirmation dialog the first time an unsigned/ad-hoc-signed app tries to set one. Accept the prompt once per browser; subsequent switches are silent.
- **Unsigned binary.** Built locally with ad-hoc signing. macOS Gatekeeper will warn on first launch — right-click the app → **Open**, or go to **System Settings → Privacy & Security** and click *Open Anyway*.
- **Launch at login** uses `SMAppService`, which can silently fail for unsigned apps on some macOS versions. If the toggle doesn't stick, the Settings window surfaces the error.
- **Chrome and Firefox only.** Adding more browsers is a small change in `Browser` (enum + bundle ID).

## Project layout

```
Package.swift
Sources/BrowserSwitcher/
  BrowserSwitcherApp.swift   # @main + SwiftUI App scene
  AppDelegate.swift          # NSApplicationDelegate, tick loop, settings window
  MenuBarController.swift    # NSStatusItem + menu construction
  BrowserSwitcher.swift      # LaunchServices wrapper
  Scheduler.swift            # Pure schedule logic
  SettingsStore.swift        # UserDefaults persistence + override semantics
  SettingsView.swift         # SwiftUI settings form
  Resources/Info.plist
Tests/SchedulerTests/        # 8 unit tests for the scheduler
scripts/build-app.sh         # swift build + assemble .app bundle
```
