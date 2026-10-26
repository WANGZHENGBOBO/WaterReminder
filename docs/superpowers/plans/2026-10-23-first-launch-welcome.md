# First Launch Welcome Implementation Plan

> **For agentic workers:** Implement natively in this session with `superpowers:executing-plans`; keep the existing menu-bar-only app and user data intact.

**Goal:** Show a concise welcome window on a genuinely new installation, explain the menu bar location, privacy, adjustable settings, and one-cup recording habit, and allow reopening it from settings.

**Architecture:** A pure WaterCore eligibility rule decides whether to show. A narrow AppKit window owner presents a SwiftUI welcome view at launch, since this macOS 14 menu-bar-only app has no normal main window. Completion is stored in UserDefaults; existing `state.json` skips the automatic introduction.

**Tech Stack:** SwiftPM, SwiftUI, AppKit, Foundation.

**Spec:** Approved conversation design: standalone one-time welcome window; menu-bar pointer, local-only privacy, adjustable target/cup/reminder settings, measured-cup habit; existing users not interrupted; reopen from Settings.

## Global Constraints

- Do not delete or rewrite existing drink records or preferences.
- Retain `LSUIElement` and the current MenuBarExtra.
- No network calls or new dependencies.
- Build Apple Silicon only; Intel deferred by user.

## Review Focus

- Legacy `state.json` but no welcome flag: skip automatic window.
- Fresh install without state or flag: show once.
- Completed welcome: do not show on relaunch.
- Reopening from Settings: show even if completed.
- Closing the window without finishing: show again next launch.

### Task 1: Eligibility

**Files:** Add `Sources/WaterCore/WelcomePolicy.swift`; modify `Tests/WaterCoreTests/ReminderTests.swift`.

- [ ] Add test for fresh, legacy, and completed eligibility. Run `swift run WaterCoreChecks` and witness failure.
- [ ] Implement `WelcomePolicy.shouldShow(completed: Bool, existingState: Bool) -> Bool`.
- [ ] Run all core checks and confirm pass.

### Task 2: Welcome window

**Files:** Add `Sources/WaterReminder/Views/WelcomeView.swift`, `Sources/WaterReminder/App/WelcomeWindow.swift`; modify app entrypoint and Settings view.

- [ ] Wire a single `NSWindow` hosting SwiftUI, shown at launch only through Task 1 policy; completion flag is set only by the primary button.
- [ ] Add a Settings button to reopen the guide; keep the UI compact with clear menu-bar, privacy, and cup-measurement copy.
- [ ] Build, install one official app, inspect welcome/reopen/close behavior without touching drinks, verify package and signature.

