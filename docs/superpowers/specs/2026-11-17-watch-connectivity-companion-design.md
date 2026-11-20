# Apple Watch 配套 App 设计

## 目标

新增一个只供本人安装、不会上架 App Store 的 iPhone + Apple Watch 配套 App。用户在手表上调整水量后，App 使用 WatchConnectivity 通过现有的蓝牙或 Wi‑Fi 把记录交给已配对的 iPhone。iPhone 读取 Mac 的杯量和提醒规则，把事件写入用户授权的 iCloud Drive 记录文件夹，Mac 按现有机制自动合并。

整个过程不使用手机号，不发送信息，不依赖消息自动化，也不要求手表直接读取 iCloud。

## 为什么做 App

Apple Watch 与 iPhone 已通过蓝牙和 Wi‑Fi 配对，但普通快捷指令运行在各自的沙盒中。快捷指令没有提供“从手表直接调用手机上的另一个快捷指令”的稳定接口，`Run Shortcut` 在手表端仍是本机执行。

设备连接本身只是系统传输层。要让两个独立 App 使用这条连接，需要 WatchConnectivity。因此这部分不能只靠 `.shortcut` 文件实现。

## 用户流程

1. 用户在 Apple Watch 上打开配套 App。
2. 手机和手表的水量默认使用 Mac 设置中的杯量。两端都点击数字直接输入；范围为 `1...2000`。
3. 用户点“记录”。
4. 手表通过 WatchConnectivity 立即发送给 iPhone；iPhone 暂时不可达时，使用系统排队传输，不丢记录。
5. iPhone 收到后显示“已交给 iPhone”，并把事件放入本机待写入队列。
6. iPhone 立即把事件写入 `iCloud Drive/Shortcuts/喝水BO～/Sync/Events`，并从同一 `Sync` 文件夹的 `settings.json` 读取杯量和提醒规则。该文件夹沿用现有 Mac 同步格式，不新增 CloudKit 容器。
7. Mac 继续读取 `Events`，按事件 ID 去重并合并。
8. iPhone 把最近一次状态回传给手表，手表显示“已保存 iCloud”或“等待 iPhone”。

## 数据与同步

### 手表到 iPhone

- 数据格式使用一个共享的 Codable 值：唯一事件 ID、时间、水量。
- iPhone 在线可达时使用 `sendMessage`，获得即时成功或失败回执。
- 不可达或即时发送失败时，使用 `transferUserInfo` 交给系统排队。
- iPhone 按事件 ID 去重，因此即时发送与排队传输重合时不会重复记录。

### iPhone 到 Mac

- iPhone App 首次运行时使用系统文件夹选择器，让用户选择 `iCloud Drive/Shortcuts/喝水BO～/Sync`。
- App 保存该文件夹的安全范围书签，后续无需重复选择。
- 每次收到手表水量，先使用现有事件 JSON 格式和唯一事件 ID 写入 `Events`。
- `settings.json` 增加工作日常规、周末常规、稍后提醒分钟数和达标停止设置，供配套 App 安排提醒。
- 手机记录使用 `source = "iphone-watch"`、`deviceShortName = "WCH"`，历史里显示为手表来源。
- Mac 不需要新增 Bonjour 发现或配对码，继续使用现有同步循环。
- iCloud 暂时不可写时，事件保留在 iPhone Application Support 队列；下次成功写入后再清除。
- 第一版不做局域网加速，路径更简单；需要时可以在后续版本增加，但不作为记录成功的前提。

### 使用用户选择的 iCloud Drive 文件夹

第一版不申请 CloudKit 或自定义 iCloud 容器。用户通过系统文件夹选择器明确授权一个已有文件夹，App 使用安全范围书签读写它。这样可以继续用免费的 Apple ID 做个人安装，不依赖付费开发者账号、Provisioning Profile 或 App Store 上架。

## 提醒与一键记录

- iPhone 根据 Mac 发布的工作日/周末规则安排本地通知。
- 通知显示默认杯量，并提供“记录 <杯量>ml”动作。
- 点击通知本身或记录动作都直接创建一次默认水量记录，不要求先进入 App。
- iPhone 通知可在配对手表中镜像显示。
- 当天已经达到目标且设置为达标后停止时，不再安排当天剩余提醒。
- 修改 Mac 设置后，iPhone 下次刷新时重新安排通知。

## App 结构

新增独立 Xcode 工程 `WaterCompanion/WaterCompanion.xcodeproj`：

- `WaterCompanion`：iPhone App，负责接收手表消息、保存安全范围书签、写入 iCloud 事件、保留失败队列和显示同步状态。
- `WaterCompanion Watch App`：watchOS App，负责水量输入、发送和状态反馈。
- `WaterCompanionShared`：手表与 iPhone 共用的消息模型、事件 ID 和 WatchConnectivity 协议。

现有 Mac App 继续使用 SwiftPM 和菜单栏界面，并继续读取同一 `Events` 文件夹。Mac 侧不增加配对或 Bonjour 元数据，不移植现有 UI。

## 界面

### Apple Watch

- 单屏，不增加菜单。
- 外圈圆环显示“今日已喝 / 今日目标”的完成进度。
- 圆环中央的大号数字是本次要记录的水量，默认来自 Mac 设置。
- 不显示加减按钮和操作提示，数码表冠直接滚动中央数字；圆环只反映今日进度，不随本次水量变化。
- 底部主按钮“记录”。
- 提交后按钮区变成一行状态，例如“已保存 iCloud”或“等待 iPhone”。

### iPhone

- 顶部显示手表连接状态。
- 使用黑曜石主题：近黑背景、灰色面板、低饱和边框和系统默认字体；主按钮采用纯色扁平样式。
- 水量使用可点击直接输入的大号数字，默认采用 Mac 杯量；数字是首屏最强视觉元素，下方显示今日进度与目标。
- 中间显示最近一次手表记录和 iCloud 写入状态。
- 下方显示待写入 iCloud 条数。
- 提供“立即重试”按钮。
- 不要求手机号、消息或第三方服务器；只要求用户选择自己的 iCloud Drive 文件夹。

## 失败与恢复

- 手表与 iPhone 不可达：记录进入 WatchConnectivity 队列，手表显示“等待 iPhone”。
- iCloud Drive 暂时不可写：记录留在 iPhone 队列；App 回到前台或用户点击重试时再次写入。
- Mac App 未运行：不影响 iCloud 保存；Mac 下次运行后按现有事件文件合并。
- 用户重复点击：同一个事件只生成一次；网络重试使用同一事件 ID。
- iPhone 重启：待发送队列从 Application Support 恢复。
- 手表重启：尚未送达的 `transferUserInfo` 由系统继续排队。

## 安装方式

1. 用 Xcode 打开 `WaterCompanion.xcodeproj`。
2. 在 Signing & Capabilities 中选择用户自己的 Personal Team。
3. 先连接 iPhone，运行 `WaterCompanion`。
4. 首次打开 iPhone App 时，选择 `iCloud Drive/Shortcuts/喝水BO～/Sync` 文件夹并允许通知。
5. 再选择配对的 Apple Watch，运行 Watch App。

不上架 App Store，不提交 TestFlight，不需要公开分发。免费个人签名可能要求定期重新安装，后续仍可改为有开发者账号时的长期签名。

## 验证

- 单元测试覆盖消息编码、事件去重、待写入队列和事件文件生成。
- 构建 iPhone 模拟器目标和 watchOS 模拟器目标。
- 验证 Mac 能从 `Events` 读取 `iphone-watch`/`WCH` 事件且只计一次。
- 验证 Mac 规则能生成提醒、通知动作能一键记录默认杯量。
- 物理设备验证：手表输入、iPhone 收到、事件进入 iCloud、Mac 在其他网络条件下仍能合并。
- 明确区分模拟器验证和真实 WatchConnectivity 验证；没有实机证据时不声称蓝牙链路已完成。

## 非目标

- 不上架 App Store。
- 不使用手机号或发送信息。
- 不使用 CloudKit。
- 不新增手表直接连接 Mac。
- 第一版不新增 Bonjour 配对或局域网加速。
- 不替代现有 iPhone/手表快捷指令；快捷指令可继续保留作为备用方式。
