# Apple Watch 捷径入口 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Implementation update:** watchOS 26.4 之后，手表端 `Run Shortcut` 调用另一个捷径会报 `Shortcut Not Found` 或启动即退出。当前实现改为：手表把 `drink:喝水BO～<ml>` 发给自己，iPhone 的“收到消息”自动化再执行 `喝水BO～`。以下保留最初实施步骤作为历史记录，当前行为以源码、测试和 `docs/iphone-shortcut/README.md` 为准。

**Goal:** Add a thin Apple Watch Shortcut that opens at 197ml, lets the user adjust the number, and sends the amount to the existing iPhone Shortcut for iCloud and LAN synchronization.

**Architecture:** Keep `喝水BO～` as the iPhone executor. Add `喝水BO～ 手表` with one number prompt and one `Run Shortcut` action. The launcher sends `drink:<ml>` as input; the executor records that amount and skips its menu when this input is present.

**Tech Stack:** Cherri, Swift 6, SwiftPM, Apple Shortcuts plist validation in Python

**Spec:** `docs/superpowers/specs/2026-11-16-watch-shortcut-launcher-design.md`

## Global Constraints

- The Watch default amount is exactly `197`.
- Accepted amount range is `1...2000`.
- The Watch Shortcut has no menu and no “查看今日记录” action.
- The Watch Shortcut sends work to `喝水BO～` through `Run Shortcut`.
- The iPhone Shortcut keeps its existing three menu choices when it receives no input.
- No new Mac HTTP endpoint or sync event source is introduced.
- The Watch Shortcut must omit iCloud file actions such as open, save, and folder contents.

## Review Focus

- A Watch input of `drink:0`, `drink:2001`, or malformed text must stop with a visible error and must not record water.
- Running `喝水BO～` normally on iPhone with no input must keep the original three-option menu.
- The Watch runner must target the exact installed executor name `喝水BO～`.
- A missing or disconnected iPhone must produce a Shortcut error rather than a fabricated Mac record.
- The unchanged iPhone path must continue saving the iCloud event before attempting the non-blocking LAN POST.

---

### Task 1: Accept Watch Amounts in the iPhone Executor

**Files:**

- Create: `Tests/ShortcutTests/validate_watch_bridge.py`
- Modify: `Tests/ShortcutTests/validate_shortcut.sh`
- Modify: `docs/iphone-shortcut/喝水BO～.cherri:1-275`
- Regenerate: `docs/iphone-shortcut/喝水BO～_unsigned.shortcut`
- Regenerate: `docs/iphone-shortcut/喝水BO～.shortcut`
- Regenerate: `Resources/喝水BO～.shortcut`

**Interfaces:**

- Consumes: Watch input text matching `drink:<integer>`.
- Produces: An unsigned/signed `喝水BO～` Shortcut whose `ShortcutInput` is materialized in `shortcutInputText`, with parsed value `watchAmount` and boolean `watchInputPresent`.

- [ ] **Step 1: Write the failing bridge test**

Create `Tests/ShortcutTests/validate_watch_bridge.py` with assertions that load `WFWorkflowActions` and require:

```python
assert document.get("WFWorkflowHasShortcutInputVariables") is True
assert "drink:" in all_text
assert "无法识别手表输入" in all_text
```

The test must also assert that the three existing UI strings remain present.

- [ ] **Step 2: Run the bridge test to verify it fails**

Run:

```bash
python3 Tests/ShortcutTests/validate_watch_bridge.py \
  "docs/iphone-shortcut/喝水BO～_unsigned.shortcut"
```

Expected: FAIL because `WFWorkflowHasShortcutInputVariables` is false and `drink:` is absent.

- [ ] **Step 3: Add Watch input parsing and preserve the normal menu**

At the beginning of `喝水BO～.cherri`, after the includes:

1. Materialize `{ShortcutInput}` into `shortcutInputText`.
2. Split it on `:`.
3. Accept exactly two fields when the first field is `drink`.
4. Parse the second field with `getNumbers`.
5. Set `watchInputPresent = true` only for `1...2000`.
6. If input exists but is malformed or outside the range, alert `无法识别手表输入，请重新运行。`, then `stop()`.
7. Set `choiceText` to an empty string and only show the existing menu when `watchInputPresent` is false.
8. Set `amount` to `watchAmount` when Watch input is present; otherwise retain the current `197` default and custom prompt behavior.
9. Guard the existing “查看今日记录” branch with `!watchInputPresent`.

Do not duplicate the event save, LAN request, or notification code.

- [ ] **Step 4: Compile and validate the updated executor**

Run:

```bash
cherri "docs/iphone-shortcut/喝水BO～.cherri" --skip-sign
python3 scripts/patch_shortcut_event_save.py \
  "docs/iphone-shortcut/喝水BO～_unsigned.shortcut"
python3 Tests/ShortcutTests/validate_watch_bridge.py \
  "docs/iphone-shortcut/喝水BO～_unsigned.shortcut"
bash Tests/ShortcutTests/validate_shortcut.sh \
  "docs/iphone-shortcut/喝水BO～_unsigned.shortcut"
python3 Tests/ShortcutTests/validate_event_save.py \
  "docs/iphone-shortcut/喝水BO～_unsigned.shortcut"
python3 Tests/ShortcutTests/validate_lan_sync.py \
  "docs/iphone-shortcut/喝水BO～_unsigned.shortcut"
python3 Tests/ShortcutTests/validate_fast_feedback.py \
  "docs/iphone-shortcut/喝水BO～_unsigned.shortcut"
```

Expected: all commands pass.

- [ ] **Step 5: Sign and install the executor artifacts**

Run:

```bash
shortcuts sign --mode anyone \
  --input "docs/iphone-shortcut/喝水BO～_unsigned.shortcut" \
  --output "docs/iphone-shortcut/喝水BO～.shortcut"
cp "docs/iphone-shortcut/喝水BO～.shortcut" "Resources/喝水BO～.shortcut"
```

Expected: both paths contain signed Shortcut documents.

- [ ] **Step 6: Commit the executor bridge**

```bash
git add "docs/iphone-shortcut/喝水BO～.cherri" \
  "docs/iphone-shortcut/喝水BO～.shortcut" \
  "docs/iphone-shortcut/喝水BO～_unsigned.shortcut" \
  "Resources/喝水BO～.shortcut" \
  Tests/ShortcutTests/validate_watch_bridge.py \
  Tests/ShortcutTests/validate_shortcut.sh \
  docs/superpowers/specs/2026-11-16-watch-shortcut-launcher-design.md \
  docs/superpowers/plans/2026-11-16-watch-shortcut-launcher.md
git commit -m "feat: accept watch amounts in iPhone shortcut"
```

---

### Task 2: Add the Watch Amount Launcher

**Files:**

- Create: `Tests/ShortcutTests/validate_watch_shortcut.py`
- Create: `docs/iphone-shortcut/喝水BO～ 手表.cherri`
- Create: `docs/iphone-shortcut/喝水BO～ 手表_unsigned.shortcut`
- Create: `docs/iphone-shortcut/喝水BO～ 手表.shortcut`
- Create: `Resources/喝水BO～ 手表.shortcut`

**Interfaces:**

- Consumes: The user’s numeric Watch input.
- Produces: `payload: text = "drink:<amount>"`.
- Produces: One `is.workflow.actions.runworkflow` call with `WFWorkflowName = "喝水BO～"` and `WFInput` referencing `payload`.

- [ ] **Step 1: Write the failing Watch artifact test**

Create `Tests/ShortcutTests/validate_watch_shortcut.py` that loads the compiled plist and asserts:

```python
assert document["WFWorkflowTypes"] == ["Watch"]
prompt = actions[0]["WFWorkflowActionParameters"]
assert prompt["WFAskActionDefaultAnswer"] == "197"
assert prompt["WFAskActionDefaultAnswerNumber"] == "197"
assert prompt["WFInputType"] == "Number"
assert any(
    action["WFWorkflowActionIdentifier"] == "is.workflow.actions.runworkflow"
    and action["WFWorkflowActionParameters"]["WFWorkflowName"] == "喝水BO～"
    for action in actions
)
```

The test must reject `documentpicker.open`, `documentpicker.save`, `file.getfoldercontents`, `downloadurl`, “查看今日记录”, and any `is.workflow.actions.choosefromlist`.

- [ ] **Step 2: Run the Watch artifact test to verify it fails**

Run:

```bash
python3 Tests/ShortcutTests/validate_watch_shortcut.py \
  "docs/iphone-shortcut/喝水BO～ 手表_unsigned.shortcut"
```

Expected: FAIL because the file does not exist.

- [ ] **Step 3: Implement the Watch launcher in Cherri**

Create `docs/iphone-shortcut/喝水BO～ 手表.cherri` with:

```text
#define name 喝水BO～ 手表
#define color blue
#define glyph watch
#define version 26
#define from watch
#define mac false

#include 'actions/shortcuts'

@amount = prompt("这次喝了多少 ml？", "Number", "197")
if @amount < 1 || @amount > 2000 {
    alert("请输入 1～2000ml", "水量不正确")
    stop()
}
@payload = "drink:{@amount}"
run("喝水BO～", @payload)
```

Do not add a list, menu, file action, network request, or “查看今日记录” branch.

- [ ] **Step 4: Compile, test, and sign the Watch launcher**

Run:

```bash
cherri "docs/iphone-shortcut/喝水BO～ 手表.cherri" --skip-sign
python3 Tests/ShortcutTests/validate_watch_shortcut.py \
  "docs/iphone-shortcut/喝水BO～ 手表_unsigned.shortcut"
shortcuts sign --mode anyone \
  --input "docs/iphone-shortcut/喝水BO～ 手表_unsigned.shortcut" \
  --output "docs/iphone-shortcut/喝水BO～ 手表.shortcut"
cp "docs/iphone-shortcut/喝水BO～ 手表.shortcut" \
  "Resources/喝水BO～ 手表.shortcut"
```

Expected: validation passes and both signed copies exist.

- [ ] **Step 5: Commit the Watch launcher**

```bash
git add "docs/iphone-shortcut/喝水BO～ 手表.cherri" \
  "docs/iphone-shortcut/喝水BO～ 手表.shortcut" \
  "docs/iphone-shortcut/喝水BO～ 手表_unsigned.shortcut" \
  "Resources/喝水BO～ 手表.shortcut" \
  Tests/ShortcutTests/validate_watch_shortcut.py
git commit -m "feat: add watch amount shortcut"
```

---

### Task 3: Package and Explain the Two-Shortcut Setup

**Files:**

- Modify: `Sources/WaterReminder/Views/WelcomeView.swift:120-205`
- Modify: `script/build_and_run.sh:16-17`
- Modify: `script/build_intel.sh`
- Modify: `script/build_release.sh:31-68`
- Modify: `Resources/Info.plist`
- Modify: `README.md`
- Modify: `docs/iphone-shortcut/README.md`
- Modify: `docs/安装与使用说明.txt`
- Modify: `docs/发给朋友.txt`

**Interfaces:**

- Consumes: `Resources/喝水BO～.shortcut` and `Resources/喝水BO～ 手表.shortcut`.
- Produces: Two distinct `ShareLink` buttons in the Mac welcome panel.
- Produces: Release copies named `喝水BO～-iPhone-<version>.shortcut` and `喝水BO～-Watch-<version>.shortcut`.

- [ ] **Step 1: Add a bundle-lookup test through the build**

Add a `watchShortcutURL` lookup to `WelcomeView` and render a second `ShareLink` labeled `发送手表版`.

The panel must state:

- Install both Shortcut files.
- Keep `喝水BO～` available on iPhone.
- Show only `喝水BO～ 手表` on Apple Watch.
- Enable “允许在锁定时运行” for `喝水BO～`.

- [ ] **Step 2: Copy both Shortcut resources in every build script**

Update `build_and_run.sh`, `build_intel.sh`, and `build_release.sh` so each app bundle contains both shortcut files. Update release copying so the share folder contains both standalone files.

- [ ] **Step 3: Update user-facing instructions**

Document the Watch interaction exactly:

1. Open `喝水BO～ 手表`.
2. The amount starts at `197`.
3. Tap confirm for 197, or adjust the number and confirm.
4. The iPhone records and syncs; the Watch does not access iCloud files directly.

Keep the existing iPhone menu documentation because it still applies when `喝水BO～` is launched without input.

- [ ] **Step 4: Bump the release version**

Set `CFBundleShortVersionString` to `1.2.3` and increment `CFBundleVersion` to `19`. Update README version references from 1.2.2 to 1.2.3 where they describe the current release.

- [ ] **Step 5: Run the complete automated verification**

Run:

```bash
swift run WaterCoreChecks
bash Tests/ShortcutTests/validate_shortcut.sh \
  "docs/iphone-shortcut/喝水BO～_unsigned.shortcut"
python3 Tests/ShortcutTests/validate_watch_bridge.py \
  "docs/iphone-shortcut/喝水BO～_unsigned.shortcut"
python3 Tests/ShortcutTests/validate_watch_shortcut.py \
  "docs/iphone-shortcut/喝水BO～ 手表_unsigned.shortcut"
bash script/build_and_run.sh --build-only
```

Expected: tests pass, the app builds, and both resources appear under:

```text
dist/喝水BO～.app/Contents/Resources/
```

- [ ] **Step 6: Commit packaging and documentation**

```bash
git add Resources/Info.plist Sources/WaterReminder/Views/WelcomeView.swift \
  script/build_and_run.sh script/build_intel.sh script/build_release.sh \
  README.md docs/iphone-shortcut/README.md \
  docs/安装与使用说明.txt docs/发给朋友.txt
git commit -m "feat: package watch shortcut support"
```

---

### Task 4: Hand Off Physical iPhone and Watch Verification

**Files:**

- No source changes.

**Interfaces:**

- Consumes: The built app and both signed Shortcut artifacts.
- Produces: Evidence or a precise failure report from the paired iPhone and Apple Watch.

- [ ] **Step 1: Verify both Shortcut artifacts import**

On the iPhone, import both files, choose “替换快捷指令” for `喝水BO～`, and add `喝水BO～ 手表`.

- [ ] **Step 2: Configure Shortcut visibility and privacy**

Turn off “在 Apple Watch 上显示” for `喝水BO～`; turn it on for `喝水BO～ 手表`. Open `喝水BO～` details, Privacy, and enable “允许在锁定时运行”.

- [ ] **Step 3: Verify the normal iPhone path**

Run `喝水BO～` on iPhone with no input. Confirm the three choices still appear and one drink reaches the Mac exactly once.

- [ ] **Step 4: Verify Watch default and adjusted amounts**

Run `喝水BO～ 手表` from the Watch. Confirm the number starts at 197, then test one unchanged confirmation and one adjusted value. Confirm both records reach the Mac exactly once.

- [ ] **Step 5: Verify locked-phone behavior and sync fallback**

Lock the iPhone and repeat a Watch run. Then disable LAN sync on the Mac and verify the Watch-initiated record still reaches the Mac through iCloud.

- [ ] **Step 6: Report any physical-device failure**

Record the exact step, the displayed watchOS or iOS error, whether the iPhone was locked, and whether the Mac received the record. Do not claim Watch success without physical-device evidence.
