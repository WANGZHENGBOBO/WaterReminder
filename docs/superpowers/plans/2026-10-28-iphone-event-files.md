# iPhone Event Files Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace unreliable shared-file appends with one JSON file per iPhone drink.

**Architecture:** The Shortcut saves a unique event under `Sync/Events`. Mac scans, validates, de-duplicates and merges those events alongside the shared CSV.

**Tech Stack:** Swift 6, SwiftPM, Apple Shortcuts/Cherri, Python plist validation

**Spec:** `docs/superpowers/specs/2026-10-28-iphone-event-files-design.md`

## Global Constraints

- Keep data in the user's iCloud Drive.
- Mac remains authoritative for the daily goal.
- Ignore invalid, empty and duplicate event files.

## Review Focus

- Empty or malformed JSON must not block valid events.
- Duplicate IDs must count once.
- Amounts outside 1...2000 must be ignored.
- Existing CSV events must remain supported.
- Shortcut Save File input must point directly to generated JSON text.

---

### Task 1: Mac event-file importer

**Files:** `Sources/WaterCore/DrinkSyncFilesystem.swift`, `Sources/WaterReminder/Stores/WaterStore.swift`, `Tests/WaterCoreTests/ReminderTests.swift`

- [ ] Add failing tests for valid, empty, malformed, duplicate and invalid-amount files.
- [ ] Implement `loadEvents()` scanning `Sync/Events` and merge its result during every sync tick.
- [ ] Run `WaterCoreChecks` and commit.

### Task 2: Shortcut event-file writer

**Files:** `docs/iphone-shortcut/喝水BO～.cherri`, `scripts/patch_shortcut_event_save.py`, `Tests/ShortcutTests/validate_event_save.py`

- [ ] Add a failing artifact test requiring no Append File and direct JSON-to-Save File input.
- [ ] Generate a unique JSON event filename and post-process Cherri output to direct action output.
- [ ] Compile, patch, validate and sign version 1.1.7.

### Task 3: Install and verify

- [ ] Build/install the Mac app if needed, import Shortcut 1.1.7 and verify iCloud artifacts without adding a fake drink.
- [ ] Commit docs and build tooling.
