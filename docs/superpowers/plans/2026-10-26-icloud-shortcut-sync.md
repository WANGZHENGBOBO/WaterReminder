# iCloud Shortcut Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sync drink and undo records between the existing macOS app and an iPhone Shortcut through the user's iCloud Drive at no additional cost.

**Architecture:** Add an append-only JSON event protocol to `WaterCore`, then let the Mac store reconcile those events into its existing `state.json` cache. Mac writes go to an outbox first and flush to iCloud; the iPhone Shortcut creates the same event files and calculates today's progress from the event folder.

**Tech Stack:** Swift 5 / SwiftPM, Foundation file APIs, iCloud Drive, Apple Shortcuts

**Spec:** `docs/icloud-shortcut-sync-design.md`

## Global Constraints

- Preserve all existing local records and settings.
- Do not use CloudKit, a third-party backend, paid APIs, or a Developer Program membership.
- Keep macOS 13 as the minimum Mac version.
- Store user-visible quantities in ml while preserving the legacy `grams` property for compatibility.
- Treat iCloud as append-only event storage; never resolve concurrent changes by overwriting a shared drink collection.
- Keep personal records and settings out of distributable app bundles and source control.

## Review Focus

- Duplicate copies of the same event must import exactly once.
- A delete event arriving before its matching drink event must still suppress that drink.
- Malformed or out-of-range event files must be ignored without blocking valid records.
- Existing local history must survive first-run migration and not be duplicated on later launches.
- Events created offline must remain queued and upload when iCloud becomes available.

---

### Task 1: Define and validate the sync event protocol

**Files:**
- Create: `Sources/WaterCore/DrinkSyncEvent.swift`
- Modify: `Tests/WaterCoreTests/ReminderTests.swift`

**Interfaces:**
- Produces: `DrinkSyncEvent`, `DrinkSyncEvent.Kind`, `DrinkSyncMerge.apply(events:to:)`, and stable JSON encode/decode helpers used by the Mac adapter.

- [ ] **Step 1: Write failing protocol and merge tests**

Add tests for round-trip JSON, duplicate drink IDs, delete-before-drink ordering, invalid 0/2001ml amounts, and malformed data being rejected.

- [ ] **Step 2: Run the checks and verify failure**

Run: `swift run WaterCoreChecks`
Expected: compilation fails because sync types do not exist.

- [ ] **Step 3: Implement the event and pure merge types**

Create versioned Codable events with exact kinds `drink` and `delete`; merge deterministically by ID and sort retained drinks by date.

- [ ] **Step 4: Run the checks and verify success**

Run: `swift run WaterCoreChecks`
Expected: all existing groups plus the sync protocol group pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/WaterCore/DrinkSyncEvent.swift Tests/WaterCoreTests/ReminderTests.swift
git commit -m "feat: define iCloud drink sync events"
```

### Task 2: Add filesystem reconciliation and offline outbox

**Files:**
- Create: `Sources/WaterReminder/Services/ICloudDrinkSync.swift`
- Modify: `Sources/WaterReminder/Stores/WaterStore.swift`
- Modify: `Tests/WaterCoreTests/ReminderTests.swift`

**Interfaces:**
- Consumes: `DrinkSyncEvent` and `DrinkSyncMerge.apply(events:to:)` from Task 1.
- Produces: `ICloudDrinkSync.loadEvents()`, `enqueue(_:)`, `flushOutbox()`, and `publishSettings(goal:serving:)`.

- [ ] **Step 1: Write failing path, migration, and reconciliation tests**

Use temporary directories to assert duplicate imports, delete-before-drink suppression, ignored malformed files, repeat-safe migration, and retained outbox files after an unavailable destination.

- [ ] **Step 2: Run the checks and verify failure**

Run: `swift run WaterCoreChecks`
Expected: compilation fails because the filesystem adapter does not exist.

- [ ] **Step 3: Implement the filesystem adapter**

Resolve `~/Library/Mobile Documents/com~apple~CloudDocs/喝水BO～/Sync`, write atomically named event files, quarantine nothing, skip invalid JSON, and retain pending files until a verified copy exists in iCloud.

- [ ] **Step 4: Integrate reconciliation into `WaterStore`**

On launch and the existing five-second tick: flush, import, merge, and save only when state changed. On add/remove: update local state, enqueue the matching event, and flush without making iCloud availability a prerequisite for the local action.

- [ ] **Step 5: Run checks and build**

Run: `swift run WaterCoreChecks && bash script/build_and_run.sh --build-only`
Expected: all checks pass and the app bundle builds successfully.

- [ ] **Step 6: Commit**

```bash
git add Sources/WaterReminder/Services/ICloudDrinkSync.swift Sources/WaterReminder/Stores/WaterStore.swift Tests/WaterCoreTests/ReminderTests.swift
git commit -m "feat: sync drink events through iCloud Drive"
```

### Task 3: Build and document the iPhone Shortcut

**Files:**
- Create: `docs/iphone-shortcut/README.md`
- Create: `dist/喝水BO～.shortcut`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: Task 1's JSON schema and Task 2's `settings.json` contract.
- Produces: an installable Shortcut that records 197ml or a validated custom amount and reports today's total and percentage.

- [ ] **Step 1: Create the Shortcut actions**

Build the shortcut in Apple Shortcuts with a two-choice menu, integer validation, unique event ID, ISO-8601 timestamp, JSON event save to `iCloud Drive/喝水BO～/Sync`, valid-event scan for today's non-deleted total, and a completion notification.

- [ ] **Step 2: Export and sign the Shortcut for sharing**

Export the shortcut and run `shortcuts sign --mode anyone` so it can be installed on the user's iPhone without a paid developer account.

- [ ] **Step 3: Write concise installation and privacy instructions**

Document AirDrop/iCloud transfer, Add to Home Screen, the two recording choices, the iCloud folder, and how to remove the shortcut without deleting records.

- [ ] **Step 4: Verify the artifact contains no personal records**

Inspect the signed shortcut and distribution folder; confirm no `state.json`, drink event files, user identifiers, or credentials are packaged.

- [ ] **Step 5: Commit source documentation only**

```bash
git add .gitignore docs/iphone-shortcut/README.md
git commit -m "docs: add iPhone shortcut setup"
```

### Task 4: End-to-end compatibility and distribution verification

**Files:**
- Modify: `README.md`
- Modify: `docs/icloud-shortcut-sync-design.md`

**Interfaces:**
- Consumes: all preceding tasks.
- Produces: verified Apple Silicon app and Shortcut handoff with recovery notes.

- [ ] **Step 1: Exercise a temporary two-device simulation**

Using isolated temporary local/outbox/iCloud folders, add on Mac, add as Shortcut, delete on Mac, repeat imports, and verify identical final drink IDs and totals.

- [ ] **Step 2: Run full regression verification**

Run: `swift run WaterCoreChecks && bash script/build_and_run.sh --build-only`
Expected: all checks pass; `dist/喝水BO～.app` is arm64-compatible and signed.

- [ ] **Step 3: Verify clean distribution contents**

Inspect the app bundle and shortcut artifact for personal data; confirm the existing local `state.json` was not modified by temporary tests.

- [ ] **Step 4: Update user-facing documentation**

Add the optional iPhone Shortcut/iCloud sync feature, privacy boundary, and first-run migration behavior without claiming a native iPhone app.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/icloud-shortcut-sync-design.md
git commit -m "docs: explain private iCloud sync"
```
