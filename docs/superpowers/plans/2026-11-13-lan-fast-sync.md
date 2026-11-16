# 局域网加速同步 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在同一 Wi‑Fi 下让 iPhone 记录通过局域网快速到达 Mac，同时始终保留 iCloud 兜底和单事件去重。

**Architecture:** iPhone 先保存 iCloud 事件，再向 Mac 的带令牌 HTTP 端点发送同一事件。Mac 使用 `Network.framework` 接收、复用现有合并逻辑立即更新，并把事件写回共享 CSV；iCloud 副本稍后到达时按事件 ID 忽略。

**Tech Stack:** Swift 5 language mode、Swift Package Manager、Foundation、Network.framework、SwiftUI、Cherri、Python 静态校验。

**Spec:** `docs/superpowers/specs/2026-11-13-lan-fast-sync-design.md`

## Global Constraints

- 最低支持 macOS 13，不增加第三方运行时依赖。
- 局域网仅接受 `POST /v1/drink`，请求体上限 8 KB。
- 默认端口 47832；占用时顺延，实际端口写入这台 Mac 的 `Devices/<deviceID>.json`。
- 手机先保存 iCloud 事件，局域网失败不能丢记录。
- 两条通道必须按同一事件 ID 去重，不能重复加水量。
- 局域网请求必须携带 `Authorization: Bearer <token>`。
- 稳定地址优先使用 `<LocalHostName>.local`，当前 IPv4 作为 `lanFallbackURL`。
- 当前目录不是 Git 仓库，计划中的提交步骤改为记录验证结果，不执行 `git commit`。

## Review Focus

- 路由器重新分配地址后，这台 Mac 的设备文件必须自动更新，不能要求用户手填 IP。
- Mac 睡眠、防火墙拦截或访客网络隔离时，记录必须仍由 iCloud 到达。
- Shortcuts 网络请求失败时不能阻止已经完成的 iCloud 保存。
- 局域网和 iCloud 在短时间内先后到达时只能产生一条饮水记录。
- 无令牌、错误令牌或畸形请求不能写入任何状态。
- 每条新记录都必须保留具体设备名，来源后缀只能写成 `iphone` 或 `mac`，接收事件的电脑不能改掉原始设备。

---

### Task 1: 每台 Mac 的独立设备文件

**Files:**
- Modify: `Sources/WaterCore/DrinkSyncFilesystem.swift`
- Modify: `Sources/WaterReminder/Services/ICloudDrinkSync.swift`
- Test: `Tests/WaterCoreTests/ReminderTests.swift`

**Interfaces:**
- Consumes: existing `DrinkSyncSettings` for goal and serving.
- Produces: `public struct LanDeviceRecord: Codable, Equatable` with `schemaVersion`, `deviceID`, `name`, `shortName`, `role`, `lanURL`, `lanFallbackURL`, `lanSubnet`, `lanToken`, `lastSeen`.
- Produces: `DrinkSyncFilesystem.publishDevice(_ record: LanDeviceRecord) throws`.
- Produces: `DrinkSyncFilesystem.loadDevices() throws -> [LanDeviceRecord]`.
- Produces: `LanDeviceNamer.nextShortName(existing:) -> String`.

- [ ] **Step 1: Write failing device-file tests**

Add to `ReminderTests.main()` and the class:

```swift
try suite.testDeviceFilesAreIndependent()
try suite.testMalformedDeviceFileIsIgnored()
```

- `testDeviceFilesAreIndependent` publishes `mac-A` and `mac-B` records to the same temporary cloud directory and asserts both files exist and both decode with their own token/URL.
- `testMalformedDeviceFileIsIgnored` writes one malformed JSON file under `Devices` and asserts `loadDevices()` returns an empty list without throwing.
- `testDeviceShortNamesAreCompactAndUnique` assigns `M1` to the first device and `M2` after an `M1` record already exists.

- [ ] **Step 2: Run tests to verify RED**

Run: `cd WaterReminder && swift run WaterCoreChecks`

Expected: compile failure for missing `LanDeviceRecord` and device-file methods.

- [ ] **Step 3: Implement device-file model and storage**

Create `Sync/Devices`, encode each record to `Devices/<deviceID>.json` atomically, skip malformed files when loading, and leave `DrinkSyncSettings` limited to goal and serving. Use the smallest unused `macN` label, with a maximum of eight ASCII characters. Compose URLs without a trailing slash.

- [ ] **Step 4: Run tests to verify GREEN**

Run: `cd WaterReminder && swift run WaterCoreChecks`

Expected: all existing groups plus the two device-file checks pass.

- [ ] **Step 5: Record verification**

Run: `cd WaterReminder && swift run WaterCoreChecks`

Record the group count and confirm no failures.

---

### Task 2: HTTP 请求解析与局域网接收端

**Files:**
- Create: `Sources/WaterCore/LanDrinkServer.swift`
- Test: `Tests/WaterCoreTests/ReminderTests.swift`

**Interfaces:**
- Produces: `LanHTTPRequest(method: String, path: String, headers: [String: String], body: Data)`.
- Produces: `LanHTTPRequestParser.parse(_:) -> LanHTTPParseResult`.
- Produces: `enum LanDrinkResponse: Equatable { case accepted(duplicate: Bool); case unauthorized; case invalid(String); case unavailable(String) }`.
- Produces: `final class LanDrinkServer` with `init(token: String, handler: @escaping @Sendable (DrinkSyncEvent) async -> LanDrinkResponse)`, `start(preferredPort: UInt16 = 47832) throws -> UInt16`, and `stop()`.

- [ ] **Step 1: Write failing parser tests**

Add checks for:

```swift
let valid = Data("POST /v1/drink HTTP/1.1\r\nAuthorization: Bearer s\r\nContent-Length: 2\r\n\r\n{}".utf8)
// parse -> method POST, path /v1/drink, body "{}"

let incomplete = Data("POST /v1/drink HTTP/1.1\r\nContent-Length: 2\r\n\r\n".utf8)
// parse -> .incomplete

let oversized = // body larger than 8 KB
// parse -> .invalid
```

- [ ] **Step 2: Run tests to verify RED**

Run: `cd WaterReminder && swift run WaterCoreChecks`

Expected: missing parser/server types.

- [ ] **Step 3: Implement parser**

Parse the request line and headers case-insensitively, require `Content-Length`, cap header and body at 8 KB, and return `.incomplete` until the full body arrives.

- [ ] **Step 4: Write failing server tests**

Start the listener on `127.0.0.1`, send valid and unauthorized POST requests with `URLSession`, and assert:

- valid token reaches the handler and returns 200;
- invalid token returns 401 without calling the handler;
- malformed path returns 404;
- duplicate handler result serializes as 200 with `"duplicate":true`.

- [ ] **Step 5: Run tests to verify RED**

Run: `cd WaterReminder && swift run WaterCoreChecks`

Expected: server tests fail because `LanDrinkServer` is missing or does not respond.

- [ ] **Step 6: Implement minimal server**

Use `NWListener(using: .tcp, on:)`, accept one request per connection, validate method/path/token, decode `DrinkSyncEvent`, await the handler, write a JSON response, and close the connection. Try sequential ports until one becomes ready.

- [ ] **Step 7: Run tests to verify GREEN**

Run: `cd WaterReminder && swift run WaterCoreChecks`

Expected: parser and network-listener checks pass with no warnings.

---

### Task 3: 稳定地址、备用 IP 与令牌

**Files:**
- Create: `Sources/WaterCore/LanEndpoint.swift`
- Create: `Sources/WaterCore/LanSyncSupport.swift`
- Test: `Tests/WaterCoreTests/ReminderTests.swift`

**Interfaces:**
- Produces: `public struct LanEndpoint: Equatable` with `hostName`, `ipv4`, `subnet`, `port`, `url`, `fallbackURL`.
- Produces: `LanAddressSelector.privateIPv4(in:) -> String?`.
- Produces: `LanAddressSelector.subnet(forIPv4:) -> String?`.
- Produces: `LanAddressSelector.endpoint(hostName:addresses:port:) -> LanEndpoint?`.
- Produces: `LanDeviceSelector.candidates(_:phoneIPv4:now:) -> [LanDeviceRecord]` and `select(_:phoneIPv4:now:) -> LanDeviceRecord?`.
- Produces: `LanSyncSupport.loadOrCreateToken(at:) throws -> String`.

- [ ] **Step 1: Write failing address tests**

Assert:

- `192.168.1.20` is selected from mixed loopback, link-local, public, and private addresses;
- `10.0.0.8` and `172.16.3.9` are accepted;
- `127.0.0.1`, `169.254.2.3`, and `8.8.8.8` are rejected;
- `subnet(forIPv4: "192.168.1.20") == "192.168.1"`;
- endpoint URL uses `<normalized-host>.local:47832` and fallback uses the IPv4.
- two records with different subnets exclude the non-matching Mac;
- a primary record outranks a newer standby record;
- with no primary, the most recent `lastSeen` wins;
- records older than seven days are excluded.

- [ ] **Step 2: Run tests to verify RED**

Run: `cd WaterReminder && swift run WaterCoreChecks`

Expected: missing address-selector types.

- [ ] **Step 3: Implement endpoint selection**

Normalize the host to lowercase `.local`, reject empty/invalid host names, choose the first private IPv4, and compose both URLs.

- [ ] **Step 4: Implement device selection**

Filter by `phoneIPv4` prefix and a seven-day freshness window, then sort by primary role, descending `lastSeen`, and device name. Keep the full sorted list so the shortcut can optionally try the next device.

- [ ] **Step 5: Write failing token test**

Create a token in a temporary directory twice and assert both reads are equal, 43 URL-safe characters, and the token file is excluded from normal sync data.

- [ ] **Step 6: Run tests to verify RED**

Run: `cd WaterReminder && swift run WaterCoreChecks`

Expected: missing `LanSyncSupport`.

- [ ] **Step 7: Implement token persistence and interface enumeration**

Use 32 random bytes encoded as base64url, persist under Application Support with mode `0600`, and enumerate active IPv4 interfaces while ignoring loopback, link-local, and non-private addresses.

- [ ] **Step 8: Run tests to verify GREEN**

Run: `cd WaterReminder && swift run WaterCoreChecks`

Expected: all address, device-selection, and token checks pass.

---

### Task 4: 单事件合并与 Store 接收

**Files:**
- Create: `Sources/WaterCore/LanDrinkIngestor.swift`
- Modify: `Sources/WaterReminder/Stores/WaterStore.swift`
- Test: `Tests/WaterCoreTests/ReminderTests.swift`

**Interfaces:**
- Produces: `LanDrinkIngestor.ingest(_:into:) -> (state: SavedState, duplicate: Bool)`.
- Produces: optional `deviceID`, `deviceName`, and `deviceShortName` on `DrinkSyncEvent` and `Drink`.
- Consumes: `DrinkSyncMerge.apply(events:to:)`.
- Produces: `DrinkSyncFilesystem.flushOutbox(sourceDeviceID: String? = nil) throws` and `ICloudDrinkSync.flushOutbox(sourceDeviceID:)`.
- Consumes: `DrinkSyncFilesystem.enqueue(_:)` and `appendMissingShared(drinks:source:)`.

- [ ] **Step 1: Write failing dedupe tests**

Apply the same `DrinkSyncEvent` twice to an empty `SavedState`. Assert one drink and `duplicate == true` on the second call. Apply two events with the same `recordID` and assert one drink.

Also enqueue a Mac event, flush it with `sourceDeviceID: "mac-A"`, overwrite the shared CSV with only its header, and assert `loadEvents()` still returns the event from `Events/mac-mac-A-*.json`.

Add `testSimultaneousMacEventsBothSurvive`: two events with different IDs, identical timestamps, and identical amounts merge into two drinks and remain two after a second merge. Add `testSameEventFromTwoDevicesCountsOnce`: the same event ID loaded from `mac-A` and `mac-B` files yields one drink.

Add `testEventsPreserveDeviceIdentity`: merge a Mac event with `source: "mac"`, `deviceID: "mac-A"`, `deviceName: "BOBO 的 MacBook Pro"`, and `deviceShortName: "M1"`; assert the resulting drink keeps all fields. Add `testLegacySourceStillNormalizes`: decode old `iphone-shortcut`, `iPhone`, and `Mac` sources and assert they classify as `.phone` or `.mac`.

- [ ] **Step 2: Run tests to verify RED**

Run: `cd WaterReminder && swift run WaterCoreChecks`

Expected: missing `LanDrinkIngestor`.

- [ ] **Step 3: Implement ingestor**

Compare drink IDs before and after `DrinkSyncMerge.apply`; return the merged state and whether no new drink was added.

Extend outbox flushing to write a uniquely named `Events/mac-<deviceID>-<eventID>.json` before the best-effort CSV append. Two Mac files with the same event ID must still load as one event.

Extend event and drink Codable models with optional device fields so old `state.json` remains readable. New Mac events use `source: "mac"` and include the publishing Mac's ID/name/short name; new phone events use `source: "iphone"` and `deviceShortName: "iPH"`. Keep old source strings readable and normalize them for display.

- [ ] **Step 4: Run ingestor tests to verify GREEN**

Run: `cd WaterReminder && swift run WaterCoreChecks`

Expected: dedupe checks pass.

- [ ] **Step 5: Wire `WaterStore.receiveLAN(_:)`**

On MainActor, enqueue the event first, ingest into `state`, save `state.json`, flush the outbox with this Mac's device ID, append missing shared records, publish settings and today summary, and return `.accepted(duplicate:)`. Any local save failure returns `.unavailable`; any iCloud-only failure leaves the outbox intact.

- [ ] **Step 6: Verify build**

Run: `cd WaterReminder && swift build`

Expected: exit 0.

---

### Task 5: 监听器生命周期、设置界面与权限

**Files:**
- Modify: `Sources/WaterCore/Models.swift`
- Modify: `Sources/WaterReminder/Stores/WaterStore.swift`
- Modify: `Sources/WaterReminder/App/WaterReminderApp.swift`
- Modify: `Sources/WaterReminder/Views/SettingsView.swift`
- Modify: `Resources/Info.plist`
- Test: `Tests/WaterCoreTests/ReminderTests.swift`

**Interfaces:**
- Produces: `Preferences.lanSyncEnabled: Bool?`, defaulting to enabled.
- Produces: `Preferences.lanPrimaryEnabled: Bool?`, defaulting to false, and `Preferences.lanShortName: String?`.
- Produces: `WaterStore.lanSyncEndpoint: LanEndpoint?`, `lanDeviceID: String`, `lanSyncError: String?`, `setLanSyncEnabled(_:) -> Bool`, `setLanPrimaryEnabled(_:) -> Bool`, `shutdown()`.
- Produces: `Drink.sourceSuffix -> "iphone" | "mac"` and `Drink.sourceDisplayLabel -> String`.

- [ ] **Step 1: Write failing preference compatibility test**

Decode an old `Preferences` JSON without `lanSyncEnabled` or `lanPrimaryEnabled`; assert LAN acceleration defaults to enabled, primary role defaults to false, and existing values remain unchanged.

Add `testDrinkDeviceDisplayLabel`: a Mac drink with short name `M1` displays `M1`; a phone drink displays `iPH`; an old drink without a short name falls back to `电脑` or `手机`. Full `BOBO 的 MacBook Pro` stays available for the tooltip and export.

Add `testHistoryCSVIncludesDeviceColumns`: exported CSV includes compact/full device columns and a source column; the source is exactly `mac` or `iphone`; device names containing commas are quoted correctly.

Add `testReceivedPhoneEventKeepsOriginDevice`: a phone event received through the Mac listener remains `iphone`/`iPH` and is not relabeled as the receiving Mac. Add `testImportedMacEventKeepsOriginMac`: a Mac-B event imported by Mac-A keeps Mac-B's `M1`/`M2` short name.

Add `testCustomMacSuffixValidation`: accepts `OFFICE`, `HOME`, and `MBP`; rejects empty strings, names longer than eight ASCII characters, spaces, punctuation, case-insensitive duplicates, and the reserved `iPH`. Add `testRenamingDeviceUpdatesMatchingHistory`: changing `M1` to `OFFICE` updates drinks with the same `deviceID` but does not change their IDs or count. Add `testRemoteDuplicateSuffixResolvesDeterministically`: two device files with the same alias resolve to different aliases by stable `deviceID` order.

- [ ] **Step 2: Run test to verify RED**

Run: `cd WaterReminder && swift run WaterCoreChecks`

Expected: missing `lanSyncEnabled`.

- [ ] **Step 3: Implement preference and lifecycle**

Start one listener when iCloud and LAN sync are enabled. Publish this Mac's device ID, name, role, address, and last-seen time under `Devices`. Refresh on network path changes, wake, preference changes, and the existing five-second tick. Stop when either toggle is off or the app terminates.

- [ ] **Step 4: Add settings UI and Info.plist copy**

Add “同一 Wi‑Fi 下加速同步”, show the stable address or “仅使用 iCloud”, and explain the one-time system network permission. Add “优先接收这台电脑” for users with multiple Macs; automatic selection remains the default. Add an editable “设备后缀” field with the current `M1`/`M2` value, an eight-character limit, and duplicate-name validation. Add `NSLocalNetworkUsageDescription`: “在同一 Wi‑Fi 下接收 iPhone 快捷指令的喝水记录。”

Use `Drink.sourceDisplayLabel` in the today-record list. Add compact/full device columns and a source column to `HistoryReport.csv`; the source column must contain only `mac` or `iphone`. The visible list should read `197ml · M1`, `197ml · M2`, or `197ml · iPH`.

- [ ] **Step 5: Verify build**

Run: `cd WaterReminder && swift build`

Expected: exit 0 with no warnings from changed files.

---

### Task 6: 快捷指令先保存再局域网发送

**Files:**
- Modify: `docs/iphone-shortcut/喝水BO～.cherri`
- Modify: `Resources/喝水BO～.shortcut`
- Create: `Tests/ShortcutTests/validate_lan_sync.py`
- Modify: `Tests/ShortcutTests/validate_shortcut.sh`

**Interfaces:**
- Consumes: `Devices/<deviceID>.json` fields `role`, `lanURL`, `lanFallbackURL`, `lanSubnet`, `lanToken`, `lastSeen`.
- Produces: one `is.workflow.actions.downloadurl` POST to `/v1/drink` after the Events save action.

- [ ] **Step 1: Write failing shortcut validator**

Parse the compiled plist and assert:

- `Devices` folder contents are read;
- the Events save precedes the request;
- the request path ends with `/v1/drink`;
- `Authorization` contains `Bearer`;
- the request body references `eventJSON`;
- the event uses `source: "iphone"`, `deviceID: "iphone"`, `deviceShortName: "iPH"`, and a non-empty `deviceName`;
- new phone event IDs use the `iphone-` prefix;
- selection prefers a primary device and filters by the current Wi‑Fi prefix;
- the dynamic amount path still reaches the same request.

- [ ] **Step 2: Run validator to verify RED**

Run: `cd WaterReminder && python3 Tests/ShortcutTests/validate_lan_sync.py Resources/喝水BO～.shortcut`

Expected: FAIL because no LAN request action exists.

- [ ] **Step 3: Update Cherri source**

Use `getFolderContents` on `Sync/Devices`; decode each record; use `getLocalIP("IPv4")` and compare the first three octets with `lanSubnet`; sort primary before standby and newest `lastSeen` before older. Include `getDeviceDetail("Device Name")` as the phone `deviceName`. Build the event with `source: "iphone"`, `deviceID: "iphone"`, `deviceShortName: "iPH"`, and an `iphone-` event ID. Save the event first, then call `jsonRequest` with the same `eventJSON`, the selected device's token, and its LAN URL. When the system supports continuing after a failed request, try the next same-subnet device; otherwise use only the selected one.

- [ ] **Step 4: Compile, patch, validate, and sign**

Run:

```sh
cd WaterReminder
cherri "docs/iphone-shortcut/喝水BO～.cherri" --skip-sign
python3 scripts/patch_shortcut_event_save.py "docs/iphone-shortcut/喝水BO～_unsigned.shortcut"
bash Tests/ShortcutTests/validate_shortcut.sh "docs/iphone-shortcut/喝水BO～_unsigned.shortcut"
cherri "docs/iphone-shortcut/喝水BO～.cherri" --share=anyone
cp "docs/iphone-shortcut/喝水BO～.shortcut" "Resources/喝水BO～.shortcut"
```

Expected: validators pass and the signed artifact starts with `AEA1`.

- [ ] **Step 5: Test failure behavior on iPhone Mirroring**

Run the shortcut on the same Wi‑Fi, then with Wi‑Fi disabled. Expected: same-Wi‑Fi record updates Mac within seconds; offline run still confirms the iCloud save and Mac later merges it. If a LAN failure interrupts the shortcut, suppress the request error or move it after final confirmation.

---

### Task 7: 多 Mac 端到端验证与发布说明

**Files:**
- Modify: `README.md`
- Modify: `docs/iphone-shortcut/README.md`
- Modify: `docs/安装与使用说明.txt`
- Modify: `Resources/Info.plist`

**Interfaces:**
- Consumes: all prior tasks.
- Produces: version `1.2.0`, build `15`, and documented LAN fallback behavior.

- [ ] **Step 1: Build and launch**

Run: `cd WaterReminder && ./script/build_and_run.sh --verify`

Expected: build succeeds and the app is running.

- [ ] **Step 2: Verify live device files and rejected writes**

Run:

```sh
python3 - <<'PY'
import json, os
root=os.path.expanduser("~/Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents/喝水BO～/Sync")
print(json.load(open(os.path.join(root, "settings.json"))))
print([json.load(open(os.path.join(root, "Devices", name))) for name in os.listdir(os.path.join(root, "Devices"))])
PY
```

Expected: `settings.json` still has goal/serving, and at least this Mac's `Devices/*.json` has `lanURL`, `lanFallbackURL`, `lanSubnet`, and `lanToken`. Send a request with a deliberately wrong token and verify it returns 401 without changing the live total.

- [ ] **Step 3: Verify duplicate handling in an isolated harness**

Use the temporary-directory server and ingestor tests from Tasks 2 and 4: send the same event twice and assert exactly one drink in the temporary `SavedState`. Add two temporary Mac device records with different IDs and assert selection is deterministic and both event files are deduplicated. Do not create or delete a record in the live `state.json` just for verification.

- [ ] **Step 4: Verify closed listener**

Turn off LAN acceleration in settings and confirm the previously published port no longer accepts connections. Turn it back on and confirm the listener returns.

- [ ] **Step 5: Run full test suite**

Run:

```sh
cd WaterReminder
swift run WaterCoreChecks
bash Tests/ShortcutTests/validate_shortcut.sh "docs/iphone-shortcut/喝水BO～_unsigned.shortcut"
./script/build_and_run.sh --verify
```

Expected: all checks pass, no warnings, and the app process is running.

- [ ] **Step 6: Update docs and version**

Document that no fixed IP is required, `.local` is primary, IP is fallback, every Mac publishes its own device file, and iCloud remains the final fallback. Set `CFBundleShortVersionString` to `1.2.0` and `CFBundleVersion` to `15`.

- [ ] **Step 7: Final verification**

Repeat Step 5 and record the exact pass counts and integration results.
