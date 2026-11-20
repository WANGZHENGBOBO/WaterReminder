# WatchConnectivity Companion App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a privately installed iPhone + Apple Watch app that sends water amounts through WatchConnectivity, writes them to the user-selected iCloud `Events` folder, and lets the existing Mac app merge them.

**Architecture:** A shared Codable payload identifies each watch event. The watch uses `WCSession.sendMessage` when reachable and `transferUserInfo` otherwise. The iPhone deduplicates into a persistent local queue, writes each event to a security-scoped iCloud folder, and exposes state back to the watch.

**Tech Stack:** Swift 6, SwiftUI, WatchConnectivity, UniformTypeIdentifiers, XCTest, SwiftPM for shared-core tests, Xcode 27 project targets for iOS and watchOS

**Spec:** `docs/superpowers/specs/2026-11-17-watch-connectivity-companion-design.md`

## Global Constraints

- Amount range is exactly `1...2000` and the default is `197`.
- No phone number, Messages, shortcut invocation, CloudKit, App Store, TestFlight, or Bonjour.
- The user selects one iCloud folder through the system folder picker.
- Events use the existing `DrinkSyncEvent` schema and a unique event ID.
- Watch events use `source = "iphone-watch"` and `deviceShortName = "WCH"`.
- Pending events must survive app restarts.
- Physical WatchConnectivity behavior cannot be claimed without paired-device evidence.

## Review Focus

- Duplicate delivery from both `sendMessage` and `transferUserInfo` must count once.
- An unwritable or revoked iCloud folder must keep the event pending instead of losing it.
- A malformed or out-of-range watch payload must not create an event.
- Application restart must restore the pending queue and preserve event IDs.
- The generated event JSON must decode through the Mac's existing `DrinkSyncEvent` rules.

---

### Task 1: Shared Message and Event Model

**Files:**
- Create: `WaterCompanion/Package.swift`
- Create: `WaterCompanion/Shared/WatchDrinkPayload.swift`
- Create: `WaterCompanion/Shared/PhoneDrinkEvent.swift`
- Create: `WaterCompanion/Shared/PendingEventQueue.swift`
- Create: `WaterCompanion/Tests/WaterCompanionCoreTests/WaterCompanionCoreTests.swift`

**Interfaces:**
- Produces: `WatchDrinkPayload(id: UUID, timestamp: Date, milliliters: Int)` with `validated()`.
- Produces: `PhoneDrinkEvent.make(from payload: WatchDrinkPayload) -> Data`.
- Produces: `PendingEventQueue.enqueue(_:) -> Bool`, `remove(id:)`, and `events`.

- [ ] **Step 1: Write failing tests**

Tests assert default amount validation, rejection of `0`/`2001`, exact JSON keys and source fields, ISO-8601 timestamp encoding, queue deduplication by ID, and queue removal.

- [ ] **Step 2: Run tests and verify failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path WaterCompanion`
Expected: FAIL because the shared types do not exist.

- [ ] **Step 3: Implement the shared types and queue**

Use Codable/Equatable values and a sorted stable pending queue keyed by `UUID`.

- [ ] **Step 4: Run shared tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path WaterCompanion`
Expected: PASS.

### Task 2: iPhone Folder Writer

**Files:**
- Create: `WaterCompanion/iOS/FolderAccess.swift`
- Create: `WaterCompanion/iOS/PendingEventStorage.swift`
- Create: `WaterCompanion/Tests/WaterCompanionCoreTests/FolderWriterTests.swift`

**Interfaces:**
- Consumes: `PhoneDrinkEvent.make(from:)` and `PendingEventQueue`.
- Produces: `FolderAccess.save(url:)`, `FolderAccess.loadURL()`, and `FolderAccess.write(_:for:) -> URL`.
- Produces: `PendingEventStorage.load()` and `save(_:)`.

- [ ] **Step 1: Write failing tests**

Use a temporary directory to assert atomic event filenames, stable contents, and queue round-trip.

- [ ] **Step 2: Run tests and verify failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path WaterCompanion`
Expected: FAIL because the storage APIs are missing.

- [ ] **Step 3: Implement storage**

Store bookmarks and pending JSON under Application Support. Perform security-scope start/stop around writes on iOS.

- [ ] **Step 4: Run tests**

Run the same package test command.
Expected: PASS.

### Task 3: Xcode Project and iOS App

**Files:**
- Create: `WaterCompanion/WaterCompanion.xcodeproj/project.pbxproj`
- Create: `WaterCompanion/WaterCompanion.xcodeproj/xcshareddata/xcschemes/WaterCompanion.xcscheme`
- Create: `WaterCompanion/iOS/WaterCompanionApp.swift`
- Create: `WaterCompanion/iOS/PhoneSession.swift`
- Create: `WaterCompanion/iOS/PhoneContentView.swift`
- Create: `WaterCompanion/iOS/Info.plist`
- Create: `WaterCompanion/Watch/Info.plist`
- Create: `WaterCompanion/Shared/WaterCompanionShared.swift`

**Interfaces:**
- Consumes: shared payload/event/queue/folder APIs.
- Produces: iOS and watchOS targets with bundle IDs `com.bobo.WaterCompanion` and `com.bobo.WaterCompanion.watchkitapp`.

- [ ] **Step 1: Create project and target resources**

Add a host iOS application and embedded watch application, each compiling the shared source files.

- [ ] **Step 2: Build the iOS target**

Run the Xcode build with a generic iOS Simulator destination.
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Implement iPhone session and UI**

Receive both WC message paths, deduplicate, enqueue, write to the selected folder, retry pending items, and publish status through application context.

- [ ] **Step 4: Rebuild**

Expected: `BUILD SUCCEEDED` without warnings about missing required plist keys.

### Task 4: watchOS App

**Files:**
- Create: `WaterCompanion/Watch/WaterCompanionWatchApp.swift`
- Create: `WaterCompanion/Watch/WatchSession.swift`
- Create: `WaterCompanion/Watch/WatchContentView.swift`

**Interfaces:**
- Consumes: `WatchDrinkPayload`.
- Produces: `WCSession` activation, reachable `sendMessage`, queued `transferUserInfo`, and status rendering.

- [ ] **Step 1: Write the watch session and screen**

Use a crown-friendly `Stepper` from `1...2000` in steps of 50, a large amount label, one “记录” button, and concise status text.

- [ ] **Step 2: Build the watch target**

Run a generic watchOS Simulator build.
Expected: `BUILD SUCCEEDED`.

### Task 5: Mac Compatibility and Documentation

**Files:**
- Modify: `Tests/WaterCoreTests/ReminderTests.swift`
- Create: `WaterCompanion/README.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: the JSON produced in Task 1.

- [ ] **Step 1: Add a failing Mac ingestion test**

Decode an `iphone-watch`/`WCH` event and merge it twice, asserting one record.

- [ ] **Step 2: Run WaterCoreChecks**

Expected: FAIL before the fixture is made compatible.

- [ ] **Step 3: Add compatibility fixture or normalization**

Only change Mac code if the real generated JSON does not decode.

- [ ] **Step 4: Run all automated checks**

Run shared package tests, existing shortcut validators, `WaterCoreChecks`, and Xcode builds.

- [ ] **Step 5: Document private installation**

Explain Personal Team signing, folder selection, device installation, failed-sync behavior, and the need for physical watch evidence.
