import SwiftUI
import AppKit
import WaterCore

struct SettingsView: View {
    @ObservedObject var store: WaterStore
    @State private var draft = Preferences()
    @State private var waveDraft = WaveAppearance()
    @State private var launchAtLogin = false
    @State private var loginError: String?
    @State private var saved = false
    @State private var appliedTheme = AppearanceTheme.classicBlue

    private var theme: AppTheme { AppTheme(appearance: draft.appearanceTheme) }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("外观") {
                    Picker("界面主题", selection: $draft.appearanceTheme) {
                        Text("经典蓝").tag(AppearanceTheme.classicBlue)
                        Text("黑曜石").tag(AppearanceTheme.obsidian)
                    }
                    .pickerStyle(.segmented)
                    Text(draft.appearanceTheme == .classicBlue
                         ? "保留原来的蓝色水波和深色面板。"
                         : "使用黑灰面板、银色强调色和黑曜石水波。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("饮水目标") {
                    TextField("每日目标（ml）", value: $draft.goal, format: .number)
                    TextField("每次记录（ml）", value: $draft.serving, format: .number)
                    Toggle("达到目标后停止当天提醒", isOn: $draft.stopAtGoal)
                }
                Section("水波外观") {
                    Stepper("小鱼数量：\(waveDraft.fishCount) 条", value: $waveDraft.fishCount, in: 0...6)
                    HStack {
                        Text("起伏高度")
                        Slider(value: $waveDraft.height, in: 0...10, step: 0.5)
                        Text(waveDraft.height, format: .number.precision(.fractionLength(1)))
                            .monospacedDigit().frame(width: 32)
                    }
                    HStack {
                        Text("流动速度")
                        Slider(value: $waveDraft.speed, in: 0.2...3, step: 0.1)
                        Text(waveDraft.speed, format: .number.precision(.fractionLength(1)))
                            .monospacedDigit().frame(width: 32)
                    }
                    HexColorRow(title: "主水面", value: $waveDraft.baseHex)
                    HStack {
                        Text("主水面透明度")
                        Slider(value: $waveDraft.baseOpacity, in: 0...1, step: 0.01)
                        Text(waveDraft.baseOpacity, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit().frame(width: 42)
                    }
                    HexColorRow(title: "后层波纹", value: $waveDraft.frontHex)
                    HStack {
                        Text("后层波纹透明度")
                        Slider(value: $waveDraft.frontOpacity, in: 0...1, step: 0.01)
                        Text(waveDraft.frontOpacity, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit().frame(width: 42)
                    }
                    WaterWavePreview(appearance: waveDraft)
                }
                Section("工作日 · 周一至周五") { ScheduleEditor(schedule: $draft.weekday) }
                Section("周末 · 周六和周日") { ScheduleEditor(schedule: $draft.weekend) }
                Section("提醒") {
                    TextField("稍后提醒（分钟）", value: $draft.snooze, format: .number)
                    Text("提醒从开始时间起按固定间隔发送，结束时间后保持安静。工作日不自动识别节假日调休。")
                        .font(.caption).foregroundStyle(.secondary)
                    NotificationStatusView(service: store.notifications)
                    Button("发送测试通知") {
                        store.notifications.send(serving: store.preferences.serving, total: store.total, goal: store.preferences.goal, test: true)
                    }
                }
                Section("通用") {
                    Button("重新查看使用指南") { WelcomeWindow.shared.show(store: store) }
                    Toggle("使用 iCloud 同步 iPhone 快捷指令", isOn: Binding(
                        get: { draft.iCloudSyncEnabled ?? false },
                        set: { draft.iCloudSyncEnabled = $0 }
                    ))
                    .onChange(of: draft.iCloudSyncEnabled ?? false) { enabled in
                        _ = store.setICloudSyncEnabled(enabled)
                    }
                    Toggle("同一 Wi‑Fi 下加速同步", isOn: Binding(
                        get: { draft.lanSyncEnabled ?? true },
                        set: { draft.lanSyncEnabled = $0 }
                    ))
                    .onChange(of: draft.lanSyncEnabled ?? true) { enabled in
                        _ = store.setLanSyncEnabled(enabled)
                    }
                    .disabled(!(draft.iCloudSyncEnabled ?? false))
                    Toggle("优先接收这台电脑", isOn: Binding(
                        get: { draft.lanPrimaryEnabled ?? false },
                        set: { draft.lanPrimaryEnabled = $0 }
                    ))
                    .onChange(of: draft.lanPrimaryEnabled ?? false) { enabled in
                        _ = store.setLanPrimaryEnabled(enabled)
                    }
                    .disabled(!(draft.iCloudSyncEnabled ?? false) || !(draft.lanSyncEnabled ?? true))
                    HStack(alignment: .center, spacing: 8) {
                        Text("设备后缀")
                            .frame(width: 68, alignment: .leading)
                        TextField("", text: Binding(
                            get: { draft.lanShortName ?? store.lanShortName },
                            set: { draft.lanShortName = $0.uppercased() }
                        ))
                        .labelsHidden()
                        .frame(width: 90)
                        .textFieldStyle(.roundedBorder)
                        Text("最多 8 个英文字母或数字")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("这台电脑：\(store.lanDeviceName)")
                        .font(.caption).foregroundStyle(.secondary)
                    if let endpoint = store.lanSyncEndpoint {
                        Text("局域网地址：\(endpoint.url)")
                            .font(.caption).foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    } else if let lanError = store.lanSyncError {
                        Text(lanError).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        SyncStatusLabel(status: store.syncStatus)
                            .font(.caption)
                        Spacer()
                        Button("打开同步文件夹") { store.openSyncFolder() }
                            .controlSize(.small)
                    }
                    Toggle("登录时自动启动", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { enabled in
                            guard enabled != LaunchAtLoginController.shared.isEnabled else {
                                loginError = LaunchAtLoginController.shared.errorMessage
                                return
                            }
                            do {
                                _ = try LaunchAtLoginController.shared.setEnabled(enabled)
                                loginError = LaunchAtLoginController.shared.errorMessage
                            } catch { loginError = "自动启动设置失败：\(error.localizedDescription)" }
                        }
                    if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                    Text((draft.iCloudSyncEnabled ?? false)
                         ? "饮水记录同步到你自己的 iCloud Drive，不使用第三方服务器。应用退出或电脑睡眠时不发送提醒。"
                         : "所有记录保存在本机。应用退出或电脑睡眠时不发送提醒；重新打开或唤醒后继续。")
                        .font(.caption).foregroundStyle(.secondary)
                    if draft.iCloudSyncEnabled ?? false {
                        Text("同一 Wi‑Fi 下会优先直接发送给电脑；失败时仍由 iCloud 补齐。首次开启可能需要在系统提示中允许局域网访问。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            Rectangle().fill(theme.border).frame(height: 1)
            HStack {
                if !waveDraft.isValid { Text("色值请使用 #RRGGBB").foregroundStyle(.red).font(.caption) }
                else if !draft.isValid { Text("请检查数值及时间范围").foregroundStyle(.red).font(.caption) }
                else if saved { Text("设置已保存").foregroundStyle(theme.textSecondary).font(.caption) }
                Spacer()
                Button("保存设置") {
                    let settingsWindow = NSApp.keyWindow
                    draft.waveAppearance = waveDraft
                    saved = SettingsSaveFlow.perform(
                        save: { store.update(draft) },
                        close: { settingsWindow?.close() }
                    )
                }
                    .keyboardShortcut("s").buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .disabled(!draft.isValid || !waveDraft.isValid)
            }
            .padding(16)
            .background(theme.panelBottom)
            if let error = store.error { Text(error).foregroundStyle(.red).font(.caption).padding(.horizontal) }
        }.frame(width: 500, height: 700)
        .appearanceTheme(draft.appearanceTheme)
        .tint(theme.accent)
        .preferredColorScheme(.dark)
        .onAppear {
            draft = store.preferences
            if draft.lanShortName == nil {
                draft.lanShortName = store.lanShortName
            }
            waveDraft = store.preferences.waveAppearance
                ?? store.preferences.appearanceTheme.defaultWaveAppearance
            appliedTheme = store.preferences.appearanceTheme
            launchAtLogin = LaunchAtLoginController.shared.isEnabled
            store.notifications.refresh()
        }
        .onChange(of: draft) { _ in saved = false }
        .onChange(of: waveDraft) { _ in saved = false }
        .onChange(of: draft.appearanceTheme) { selected in
            guard selected != appliedTheme else { return }
            waveDraft = selected.applying(to: waveDraft)
            appliedTheme = selected
        }
    }
}

private struct HexColorRow: View {
    let title: String
    @Binding var value: String

    private var colorBinding: Binding<Color> {
        Binding {
            waveColor(value)
        } set: { selected in
            guard let rgb = NSColor(selected).usingColorSpace(.deviceRGB) else { return }
            value = WaveAppearance.hex(red: rgb.redComponent, green: rgb.greenComponent,
                                       blue: rgb.blueComponent)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
            Spacer()
            ColorPicker("选择\(title)颜色", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 28, height: 24)
                .help("点击打开系统色板")
            TextField("#RRGGBB", text: $value)
                .labelsHidden()
                .accessibilityLabel("\(title)色值")
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .overlay(RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(WaveAppearance.isHexColor(value) ? .clear : .red, lineWidth: 1))
        }
    }
}

private struct ScheduleEditor: View {
    @Binding var schedule: Schedule
    var body: some View {
        Toggle("启用提醒", isOn: $schedule.enabled)
        Group {
            DatePicker("开始时间", selection: timeBinding(\.start), displayedComponents: .hourAndMinute)
            DatePicker("结束时间", selection: timeBinding(\.end), displayedComponents: .hourAndMinute)
            Stepper("每 \(schedule.interval) 分钟", value: $schedule.interval, in: 5...240, step: 5)
        }.disabled(!schedule.enabled)
    }

    private func timeBinding(_ keyPath: WritableKeyPath<Schedule, Int>) -> Binding<Date> {
        Binding {
            let minutes = schedule[keyPath: keyPath]
            return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
        } set: { date in
            schedule[keyPath: keyPath] = Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date)
        }
    }
}
