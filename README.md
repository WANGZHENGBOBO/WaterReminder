# 喝水BO～

macOS 13 Ventura 或更新版本的原生菜单栏应用。菜单栏显示今日百分比，点开查看进度、记录或撤销饮水。

默认目标 1800ml，每次 197ml。工作日（周一至五）和周末可分别设置，默认均为 11:00–19:00、每45分钟，稍后提醒10分钟。开始时间包含在内，结束时间不发送通知，因此默认提醒时刻为11:00、11:45……18:30。达到目标后默认停止当天提醒，可在设置关闭这一选项。记录后保持固定时间表。

全新安装首次启动会出现简短欢迎页，说明菜单栏入口、杯量记录方法与本地隐私；已有数据的用户更新后不会重复看到。关闭欢迎页而未完成时，下次启动会再次显示；也可随时在设置中选择“重新查看使用指南”。

水位卡片中的后层波纹位于主水面下方；两层颜色、透明度、起伏高度和速度可在设置中调整。水位达到30%后会出现小鱼，它会在水中缓慢游动；点击有水的位置，它会游向点击处，再继续自由游动。开启系统“减少动态效果”时，小鱼保持静止。

首次打开后点击菜单栏水滴，再点击“开启通知”。可以在设置中发送测试通知。系统专注模式及通知设置可能影响横幅、声音和按钮展示。菜单栏应用不显示 Dock 图标。

数据保存在 `~/Library/Application Support/com.bobo.WaterReminder/state.json`，按本地日历日期统计，不删除历史记录。没有网络、账号或云同步。退出或睡眠时不提醒；唤醒不补发。工作日不识别法定节假日调休。时间范围暂不支持跨午夜。

## 构建

需要 Swift 6 命令行工具，零外部依赖。

```sh
swift run WaterCoreChecks
./script/build_and_run.sh --verify
```

应用位于 `dist/喝水BO～.app`。可放到“应用程序”后使用；开启自动启动前请先确定最终存放位置。本机使用临时签名，未进行 Developer ID 公证。水滴图标基于 macOS 系统符号生成，重建命令：`swift script/make_icon.swift Resources/AppIcon.iconset`，然后运行 `iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns`。

## Intel Mac 版本

运行 `bash script/build_intel.sh` 交叉编译 x86_64 Release 版本。应用位于 `dist/intel/喝水BO～.app`，传输包为 `dist/喝水BO～-Intel.zip`。要求 macOS 13 Ventura 或更新版本。独立打包，不覆盖当前 Apple 芯片版本；Intel 核心逻辑已在 Rosetta 下验证，界面与通知仍需在 Intel 实机确认。
