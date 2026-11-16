# One-Step Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a fresh Mac installation sync by default and guide the user through one iPhone QR-code pairing without requiring settings configuration.

**Architecture:** Fresh preferences enable iCloud sync while legacy preference files remain opted out. `WaterStore` exposes a visible sync status and stores failures instead of swallowing them. The welcome view consumes that status and shows a QR code for the published Shortcut URL, with a bundled Shortcut file as fallback.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Core Image QR generation, SwiftPM, Apple Shortcuts

**Spec:** `docs/superpowers/specs/2026-10-28-one-step-setup-design.md`

## Global Constraints

- Do not silently install the Shortcut on an iPhone.
- Do not bypass iPhone iCloud Drive permission.
- Do not add accounts, servers, analytics, or third-party storage.
- Do not automatically upload records belonging to an existing local-only user.
- macOS deployment target is 13.0.
- Preserve both `arm64` and `x86_64` packaging.

## Review Focus

- A legacy `state.json` without `iCloudSyncEnabled` must remain local-only after upgrade.
- A fresh install must create its sync directory without visiting Settings.
- A phone event stored as `.txt` must continue to import and deduplicate.
- A missing or invalid Shortcut URL must not render a misleading QR code.
- A failed iCloud read/write must appear as actionable status instead of a silent failure.

---

### Task 1: Enable Sync for Fresh Installations

**Files:**
- Modify: `Sources/WaterCore/Models.swift`
- Test: `Tests/WaterCoreTests/ReminderTests.swift`

**Interfaces:**
- Consumes: `Preferences` Codable defaults.
- Produces: `Preferences().iCloudSyncEnabled == true`; decoded legacy preferences with an absent key retain `nil`.

- [ ] **Step 1: Write the failing preference migration test**

Add `suite.testFreshInstallEnablesICloudSync()` to `main`. The test asserts:

```swift
XCTAssertTrue(Preferences().iCloudSyncEnabled == true)
let legacy = try JSONDecoder().decode(Preferences.self, from: Data(oldJSON.utf8))
XCTAssertNil(legacy.iCloudSyncEnabled)
```

Use the existing legacy JSON fixture that omits `iCloudSyncEnabled`.

- [ ] **Step 2: Run the core checks and verify the fresh-install assertion fails**

Run: `/private/tmp/water-build-fix/debug/WaterCoreChecks`
Expected: failure showing the default preference is not enabled.

- [ ] **Step 3: Change only the fresh preference default**

Set `public var iCloudSyncEnabled: Bool? = true` in `Preferences`. Keep decoding behavior so a missing legacy key remains `nil`.

- [ ] **Step 4: Rebuild and run all core checks**

Run the SwiftPM `WaterCoreChecks` build, then its executable.
Expected: all test groups pass and legacy preferences remain opted out.

### Task 2: Expose Sync Health and Failures

**Files:**
- Modify: `Sources/WaterReminder/Stores/WaterStore.swift`
- Modify: `Sources/WaterReminder/Views/SettingsView.swift`
- Test: `Tests/WaterCoreTests/ReminderTests.swift`

**Interfaces:**
- Produces: `WaterStore.syncStatus`, `WaterStore.openSyncFolder()`, and `WaterStore.setICloudSyncEnabled(_:)`.
- Produces: status cases `.disabled`, `.waiting`, `.healthy(Date)`, `.failed(String)`.
- Consumes: existing `DrinkSyncFilesystem.loadEvents()`, `ICloudDrinkSync`, and `Date`.

- [ ] **Step 1: Add a core test for classifying phone-event readiness**

Add a pure helper in `WaterCore` and assert:

```swift
XCTAssertEqual(DrinkSyncReadiness.classify(enabled: false, phoneEventDates: []), .disabled)
XCTAssertEqual(DrinkSyncReadiness.classify(enabled: true, phoneEventDates: []), .waiting)
XCTAssertEqual(DrinkSyncReadiness.classify(enabled: true, phoneEventDates: [date(23, 9)]), .healthy(date(23, 9)))
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `/private/tmp/water-build-fix/debug/WaterCoreChecks`
Expected: the readiness type is missing.

- [ ] **Step 3: Implement readiness classification**

Create `Sources/WaterCore/DrinkSyncReadiness.swift` with the enum and function matching the test. Return the latest date for `.healthy`.

- [ ] **Step 4: Wire the status into `WaterStore`**

Publish `syncStatus`. Set `.disabled` when sync is off, classify iPhone drink events after a successful load, and use `.failed(error.localizedDescription)` in the sync catch block. Keep local state authoritative.

- [ ] **Step 5: Add immediate sync-toggle persistence and folder access**

Implement `setICloudSyncEnabled(_:)` to save only that preference change and trigger synchronization. In Settings, call it when the toggle changes, and add “打开同步文件夹” using the existing sync directory path.

- [ ] **Step 6: Run all core checks**

Expected: readiness tests and all existing groups pass; the `.txt` event import regression remains green.

### Task 3: Turn the Welcome Screen into a QR Pairing Screen

**Files:**
- Modify: `Sources/WaterReminder/App/WelcomeWindow.swift`
- Modify: `Sources/WaterReminder/Views/WelcomeView.swift`
- Modify: `Sources/WaterReminder/App/WaterReminderApp.swift`
- Modify: `Sources/WaterReminder/Views/SettingsView.swift`
- Create: `Sources/WaterReminder/Views/QRCodeView.swift`
- Modify: `Resources/Info.plist`
- Modify: `script/build_and_run.sh`
- Modify: `script/build_intel.sh`

**Interfaces:**
- Consumes: `WaterStore.syncStatus`, `WaterStore.preferences.iCloudSyncEnabled`, and `Preferences.goal`.
- Produces: `WelcomeWindow.show(store:)` and `WelcomeView(store:finish:)`.
- Reads: `Info.plist` key `ShortcutShareURL`.
- Reads: packaged fallback resource `Contents/Resources/喝水BO～.shortcut`.

- [ ] **Step 1: Pass the store into the welcome window**

Change `WelcomeWindow.showIfNeeded(store:)` and `show(store:)`; update startup and the Settings “重新查看使用指南” button. Existing users with `welcomeCompleted.v1` still do not see the welcome window automatically.

- [ ] **Step 2: Render the pairing flow**

Show “Mac 已准备好”, the live sync status, and these iPhone steps:

```text
1. 用 iPhone 相机扫码
2. 点“添加快捷指令”
3. 第一次运行时允许访问 iCloud Drive
```

Remove the old statement that records stay only on the Mac. Explain that records go only to the user’s own iCloud when sync is enabled.

- [ ] **Step 3: Add QR and fallback actions**

Create `QRCodeView.swift` using `CIFilter.qrCodeGenerator()`, nearest-neighbor rendering, and an accessibility label. Show the QR only when `ShortcutShareURL` is a valid `https` URL. Add “在 iPhone 上打开” and a `ShareLink` for the bundled shortcut resource when available.

- [ ] **Step 4: Package the Shortcut fallback**

Copy `dist/喝水BO～-iPhone-1.1.7.shortcut` to `Contents/Resources/喝水BO～.shortcut` in both build scripts before signing. Keep the executable’s resource lookup through `Bundle.main`.

- [ ] **Step 5: Build and visually inspect**

Build the App, relaunch it, and force the welcome window from Settings.
Expected: no clipped controls, the QR is scannable, status text updates, and the fallback button is present when no URL is configured.

### Task 4: Publish, Package, and Verify Both Architectures

**Files:**
- Modify: `Resources/Info.plist`
- Modify: `README.md`
- Modify: `docs/iphone-shortcut/README.md`

**Interfaces:**
- Consumes: published Shortcut URL from the user.
- Produces: `ShortcutShareURL` in `Info.plist`, updated installation instructions, `dist/喝水BO～-AppleSilicon.zip`, and `dist/喝水BO～-Intel.zip`.

- [ ] **Step 1: Publish Shortcut 1.1.7**

Obtain a public iCloud Shortcut link. Publishing shares the Shortcut code, not drink data.

- [ ] **Step 2: Configure and verify the QR**

Put the exact URL into `ShortcutShareURL`, rebuild, scan the QR from an iPhone, and verify it lands on the “添加快捷指令” screen.

- [ ] **Step 3: Perform one real end-to-end record**

Add the Shortcut on the iPhone, allow iCloud Drive, record one drink, and verify the Mac imports it once within approximately five seconds.

- [ ] **Step 4: Build and package both architectures**

Run the Apple Silicon build, x86_64 Release build, core checks under both architectures, codesign verification, and ZIP extraction verification.

- [ ] **Step 5: Update user documentation**

Replace manual Settings-first instructions with the QR-first flow, state the one-time iPhone permission, and explain the fallback file path.
