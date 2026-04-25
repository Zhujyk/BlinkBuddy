# BlinkBuddy

BlinkBuddy is a lightweight macOS menu bar app that nudges the user toward the 20-20-20 rule without turning into a busy always-updating utility. The current implementation focuses on trustworthy core timing: count active screen time, pause when the user is away, and keep the menu bar presence quiet by default.

## Current Status

- Menu-bar-only app shell using `MenuBarExtra` and `LSUIElement`
- `BreakEngine` as the single source of truth for reminder state
- `ActivityMonitor` for `NSWorkspace` lifecycle boundaries and sparse idle recovery checks
- Extracted menu bar view with coarse state/actions instead of a permanent second-by-second countdown
- Break reminder popup or notification delivery is still future work, so the current break prompt stays inside the menu experience

## Architecture

- `BlinkBuddy/BlinkBuddyApp.swift`: boots the menu bar scene and owns one long-lived `BreakEngine`
- `BlinkBuddy/Logic/BreakEngine.swift`: deadline-based state machine for `ready`, `tracking`, `idlePaused`, and `breakDue`
- `BlinkBuddy/Logic/ActivityMonitor.swift`: lifecycle observation plus coarse idle validation
- `BlinkBuddy/Views/MenuBarView.swift`: menu content and core actions
- `BlinkBuddy/Views/BreakupPopupView.swift`: lightweight in-menu break prompt boundary while richer reminder UI is deferred

## Build And Test

```bash
xcodebuild -project BlinkBuddy.xcodeproj -scheme BlinkBuddy -sdk macosx -derivedDataPath /tmp/BlinkBuddyDerived build
xcodebuild -project BlinkBuddy.xcodeproj -scheme BlinkBuddy -sdk macosx -derivedDataPath /tmp/BlinkBuddyDerived test
```

## Product Notes

- BlinkBuddy aims to count active work time, not naive wall-clock time.
- The implementation avoids a permanent 1-second polling loop for normal operation.
- All reminder logic is local to the Mac; there are no runtime network dependencies.
- The current hosted macOS XCTest setup covers the activity monitor and break-due path; three `BreakEngine` cases are intentionally skipped while a test-host teardown crash is investigated.
