import SwiftUI
import AppKit
import ServiceManagement
import WaterCore

struct SettingsView: View {
    @ObservedObject var store: WaterStore
    @State private var draft = Preferences()
    @State private var waveDraft = WaveAppearance()
    @State private var launchAtLogin = false
    @State private var loginError: String?
    @State private var saved = false
    var body: some View {
        VStack(spacing: 0) {
            Form {
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
                    Button("重新查看使用指南") { WelcomeWindow.shared.show() }
                    Toggle("使用 iCloud 同步 iPhone 快捷指令", isOn: Binding(
                        get: { draft.iCloudSyncEnabled ?? false },
                        set: { draft.iCloudSyncEnabled = $0 }
                    ))
                    Toggle("登录时自动启动", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { enabled in
                            do {
                                if enabled { try SMAppService.mainApp.register() }
                                else { try SMAppService.mainApp.unregister() }
                                if SMAppService.mainApp.status == .requiresApproval {
                                    loginError = "请在系统设置的登录项中允许喝水BO～。"
                                } else { loginError = nil }
                            } catch { loginError = "自动启动设置失败：\(error.localizedDescription)" }
                        }
                    if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                    Text((draft.iCloudSyncEnabled ?? false)
                         ? "饮水记录同步到你自己的 iCloud Drive，不使用第三方服务器。应用退出或电脑睡眠时不发送提醒。"
                         : "所有记录保存在本机。应用退出或电脑睡眠时不发送提醒；重新打开或唤醒后继续。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped)
            Divider()
            HStack {
                if !waveDraft.isValid { Text("色值请使用 #RRGGBB").foregroundStyle(.red).font(.caption) }
                else if !draft.isValid { Text("请检查数值及时间范围").foregroundStyle(.red).font(.caption) }
                else if saved { Text("设置已保存").foregroundStyle(.secondary).font(.caption) }
                Spacer()
                Button("保存设置") {
                    let settingsWindow = NSApp.keyWindow
                    draft.waveAppearance = waveDraft
                    saved = SettingsSaveFlow.perform(
                        save: { store.update(draft) },
                        close: { settingsWindow?.close() }
                    )
                }
                    .keyboardShortcut("s").buttonStyle(.borderedProminent).disabled(!draft.isValid || !waveDraft.isValid)
            }.padding(16)
            if let error = store.error { Text(error).foregroundStyle(.red).font(.caption).padding(.horizontal) }
        }.frame(width: 500, height: 700)
        .onAppear {
            draft = store.preferences
            waveDraft = store.preferences.waveAppearance ?? WaveAppearance()
            launchAtLogin = SMAppService.mainApp.status == .enabled
            store.notifications.refresh()
        }
        .onChange(of: draft) { _ in saved = false }
        .onChange(of: waveDraft) { _ in saved = false }
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
        HStack {
            Text(title)
            Spacer()
            ColorPicker("选择\(title)颜色", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 24, height: 24)
                .help("点击打开系统色板")
            TextField("#RRGGBB", text: $value)
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
