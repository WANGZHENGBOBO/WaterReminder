# 菜单栏弹窗顶部锚定 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 弹窗内容高度变化时固定上沿，只移动底边。

**Architecture:** 用 AppKit 状态栏按钮与无标题面板替换 SwiftUI 自动定位的 MenuBarExtra；SwiftUI 仪表内容不变，尺寸回调驱动面板明确布局。

**Tech Stack:** macOS 14+，SwiftUI，AppKit，SwiftPM。

**Spec:** `docs/menu-popup-anchor-design.md`

## Global Constraints

- 保留本机记录，不改数据格式，不更新 Intel。
- 菜单栏入口继续显示水滴和百分比。
- 设置按钮、退出按钮和点击外部收起行为保留。

## Review Focus

- 记录展开/收起：上沿不移动。
- 状态栏接近屏幕边缘：面板不超出横向可见区域。
- 设置窗口：保存后仍能关闭。
- 首次启动：欢迎页不受影响。
- 单进程运行：不出现第二个水滴入口。

### Task 1: 顶部锚定几何

**Files:** `Sources/WaterCore/PopoverAnchor.swift`, `Tests/WaterCoreTests/ReminderTests.swift`

- [x] 新增失败用例：大小变化前后 `frame.maxY` 固定在状态栏按钮下缘；接近屏幕右边时限制 X。
- [x] 运行核心检查确认红灯。
- [x] 实现 `PopoverAnchor.panelFrame(button:content:visible:)`。
- [x] 运行核心检查确认绿灯。

### Task 2: 原生状态栏弹窗

**Files:** `Sources/WaterReminder/App/WaterReminderApp.swift`, `Sources/WaterReminder/App/MenuBarPanelController.swift`, `Sources/WaterReminder/Views/DashboardView.swift`, `Sources/WaterReminder/App/SettingsWindow.swift`

- [x] 状态栏按钮显示水滴及百分比，点击切换面板（代码与构建验证，待用户目视）。
- [x] 仪表根视图报告高度，控制器每次以 Task 1 几何设定面板 frame。
- [x] 保留原设置、退出、点击外部关闭；移除旧窗口通知校正桥（代码与构建验证，待用户点击）。
- [x] 构建 Apple 版，验证单进程、架构、签名和包内容。
