# iCloud 快捷指令同步设计

## 目标

在不购买 Apple Developer 会员、不使用第三方服务器的前提下，让「喝水BO～」Mac 版与 iPhone 快捷指令通过用户自己的 iCloud Drive 共用饮水记录。

## iPhone 体验

从桌面或小组件运行「喝水BO～」后，先选择“喝了 197ml”或“自定义水量”。Mac 端只接收 1–2000ml 的整数。保存成功后显示同步提示；默认目标为 1800ml，Mac 版会把当前目标与默认杯量同步到 iCloud。

## 同步模型

iCloud Drive 中使用 `Shortcuts/喝水BO～/Sync` 文件夹。Mac 使用独立 JSON 事件，iPhone 则以两个追加日志记录水量和发生时间，尽量只使用低版本 iOS 也具备的系统动作：

- `drink`：包含唯一 ID、发生时间、毫升数和来源设备。
- `delete`：包含被撤销记录的 ID 和撤销时间。
- `settings.json`：Mac 版发布当前目标和默认杯量，供快捷指令读取。
- `iphone-amounts.txt` 与 `iphone-times.txt`：同序号的两行组成一条 iPhone 记录。

Mac 版保留现有 `state.json` 作为本机缓存和兼容数据源。首次启用时把既有记录补写为事件，并合并 iCloud 中尚未见过的事件；按记录 ID 去重，撤销事件优先于新增事件。

## 离线与冲突

Mac 在 iCloud 暂不可用时先把事件写入 Application Support 下的待上传目录，恢复后自动补传。iPhone 快捷指令把追加日志交给系统的 iCloud Drive，本机离线时由系统稍后同步。Mac 以日志行号生成稳定记录 ID，重复扫描不会重复计数。

## 范围

第一版同步新增、撤销、历史趋势和 CSV 导出所依赖的饮水记录；不把暂停状态、庆祝播放状态或通知队列跨设备同步。Mac 继续负责完整水位、小鱼和提醒，iPhone 先提供快速记录与结果反馈。

## 隐私与兼容

数据仅进入用户自己的 iCloud Drive，不建立账号、不上传第三方后台。同步默认关闭，由用户在设置中主动开启。Mac 最低系统仍为 macOS 13；快捷指令只使用列表、数字、日期、文件与通知等系统动作，不依赖付费 API。
