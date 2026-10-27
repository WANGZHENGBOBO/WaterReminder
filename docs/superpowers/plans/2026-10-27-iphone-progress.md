# iPhone Immediate Progress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the iPhone Shortcut show the current combined daily progress immediately after recording and provide a read-only “查看今日记录” action.

**Architecture:** The Mac publishes an atomic `today-summary.json` containing its merged daily state and the number of paired iPhone log rows already included. The Shortcut combines that baseline with newer valid rows from its append-only phone logs, so phone additions appear immediately without double counting when the Mac later imports them.

**Tech Stack:** Swift 5 / SwiftPM, Foundation file APIs, iCloud Drive, Apple Shortcuts

**Spec:** `docs/superpowers/specs/2026-10-27-iphone-progress-design.md`

## Global Constraints

- Keep the menu choices “喝了 197ml”, “自定义水量”, and “查看今日记录”.
- Do not add phone-side undo.
- Use only the user's own iCloud Drive; no third-party server and no collection of user information.
- Preserve the existing `iphone-amounts.txt` and `iphone-times.txt` records.
- Missing settings use a goal of 1800ml; invalid amounts are ignored.
- Keep compatibility with the current macOS deployment target and iPhone Shortcuts actions.

## Review Focus

- A summary written before the newest phone row must add only the pending row, never all phone rows again.
- A stale summary from another date must not contribute to today's total.
- Unequal or malformed paired-log rows must not crash or enter the total.
- A goal of zero or a missing summary must still produce a safe 1800ml fallback.
- Mac delete events must be reflected in the next published total and record list.

---

### Task 1: Add the daily summary protocol

**Files:**
- Modify: `Sources/WaterCore/DrinkSyncFilesystem.swift`
- Modify: `Tests/WaterCoreTests/ReminderTests.swift`

**Interfaces:**
- Consumes: merged `[Drink]`, goal, current date, calendar, and the paired Shortcut log files.
- Produces: `DrinkSyncTodaySummary`, `DrinkSyncTodayRecord`, and `DrinkSyncFilesystem.publishTodaySummary(drinks:goal:now:calendar:)`.

- [ ] **Step 1: Write failing summary tests**

Assert that publishing for 2026-10-23 writes sorted same-day records, total, goal, day key, and `phoneLogCount == 3`; also assert another-day records are excluded, unpaired trailing rows do not inflate the cursor, and malformed paired rows do not enter the total.

- [ ] **Step 2: Run `swift test` and verify RED**

Expected: compilation fails because the summary API does not exist.

- [ ] **Step 3: Implement the minimal summary types and atomic publisher**

Use schema version 1, local `yyyy-MM-dd`, ISO-8601 timestamps, and use the number of scanned paired log rows for `phoneLogCount`.

- [ ] **Step 4: Run `swift test` and verify GREEN**

Expected: all test groups pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/WaterCore/DrinkSyncFilesystem.swift Tests/WaterCoreTests/ReminderTests.swift
git commit -m "feat: publish iPhone daily progress summary"
```

### Task 2: Publish the summary during Mac synchronization

**Files:**
- Modify: `Sources/WaterReminder/Services/ICloudDrinkSync.swift`
- Modify: `Sources/WaterReminder/Stores/WaterStore.swift`

**Interfaces:**
- Consumes: `publishTodaySummary(drinks:goal:now:calendar:)` from Task 1.
- Produces: a refreshed `today-summary.json` after every successful merge and after settings/record changes reach synchronization.

- [ ] **Step 1: Add a compile-level call through the adapter**

Add `ICloudDrinkSync.publishTodaySummary(drinks:goal:now:)` and call it after merge/save using the final `state.drinks`.

- [ ] **Step 2: Run `swift test` and `swift build -c release`**

Expected: all test groups pass and the app builds without errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/WaterReminder/Services/ICloudDrinkSync.swift Sources/WaterReminder/Stores/WaterStore.swift
git commit -m "feat: refresh phone progress during sync"
```

### Task 3: Upgrade and export the iPhone Shortcut

**Files:**
- Modify: `docs/iphone-shortcut/README.md`
- Regenerate ignored artifact: `dist/喝水BO～.shortcut`

**Interfaces:**
- Consumes: `today-summary.json`, `settings.json`, `iphone-amounts.txt`, and `iphone-times.txt`.
- Produces: an installable signed Shortcut with immediate progress and read-only today records.

- [ ] **Step 1: Add the third menu choice and shared progress calculation**

For record actions append first, then calculate; for “查看今日记录” calculate without appending. Use the summary only when its `day` equals today, then add valid phone rows after `phoneLogCount` that belong to today.

- [ ] **Step 2: Format the result**

Record result: “已记录 Nml / 今日 T / Gml / 完成 P%，还差 Rml”. Today view lists each known record time and amount followed by the same summary. Clamp remaining to zero and calculate integer percent safely.

- [ ] **Step 3: Export as “任何人” and replace the dist artifact**

Expected: the exported Shortcut installs without a paid developer account and contains no personal record files.

- [ ] **Step 4: Update setup and behavior documentation**

Document the three actions, offline semantics, immediate progress, Mac-side undo, and privacy boundary.

- [ ] **Step 5: Commit source documentation**

```bash
git add docs/iphone-shortcut/README.md docs/superpowers/specs/2026-10-27-iphone-progress-design.md docs/superpowers/plans/2026-10-27-iphone-progress.md
git commit -m "docs: explain iPhone progress shortcut"
```

### Task 4: End-to-end verification and release handoff

**Files:**
- Modify if needed: `script/build_and_run.sh`
- Update: BOBO OS `projects/water-reminder.md`

**Interfaces:**
- Consumes: the Mac summary publisher and signed Shortcut from Tasks 1–3.
- Produces: verified Apple Silicon Mac app, verified Shortcut artifact, and durable project status.

- [ ] **Step 1: Run the complete Swift test suite and release build**

Run: `swift test && swift build -c release`

Expected: all tests pass and release build succeeds.

- [ ] **Step 2: Verify the live summary without modifying personal records**

Decode `today-summary.json`; confirm its total equals Mac state for today, its phone cursor equals valid paired rows, and no repository/distribution file contains the user's state data.

- [ ] **Step 3: Install/relaunch the Apple Silicon app and test the read-only Shortcut path**

Confirm Mac remains single-instance and the Shortcut’s “查看今日记录” displays without appending a new row.

- [ ] **Step 4: Review the full diff and update long-term memory**

Record the new phone progress behavior, summary protocol, artifact location, verification result, and any open loop in the existing BOBO OS project file.

- [ ] **Step 5: Push the commits**

Run: `git push origin main`

Expected: the public GitHub repository contains only source/docs, not personal records or the ignored signed artifact.
