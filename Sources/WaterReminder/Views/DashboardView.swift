import SwiftUI
import WaterCore

struct DashboardView: View {
    @ObservedObject var store: WaterStore
    var onOpenSettings: () -> Void
    @State private var showRecords = false

    private var theme: AppTheme {
        AppTheme(appearance: store.preferences.appearanceTheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WaterGaugeView(total: store.total, goal: store.preferences.goal,
                           count: store.todayDrinks.count, date: store.now,
                           appearance: store.preferences.waveAppearance ?? theme.defaultWaveAppearance)
            DrinkAnimationView(serving: store.preferences.serving) { amount in
                store.addDrink(amount: amount)
            }
            HStack {
                Button("稍后 \(store.preferences.snooze) 分钟") { store.snooze() }
                    .disabled(store.paused || (store.completed && store.preferences.stopAtGoal))
                Spacer()
                Button(showRecords ? "收起记录" : "今日记录") { showRecords.toggle() }
            }
            .controlSize(.small)
            .buttonStyle(PanelChipButtonStyle())
            if showRecords {
                if store.todayDrinks.isEmpty {
                    Text("今天还没有记录").foregroundStyle(theme.textSecondary).font(.caption)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(store.todayDrinks) { drink in
                                HStack {
                                    Text(drink.date, format: .dateTime.hour().minute().second())
                                        .monospacedDigit().foregroundStyle(theme.textSecondary)
                                    Spacer()
                                    Text("\(drink.grams)ml · \(drink.sourceDisplayLabel)")
                                        .monospacedDigit().foregroundStyle(theme.text)
                                        .help(drink.sourceDetailLabel)
                                    Button("撤销") { store.remove(drink) }.buttonStyle(.borderless)
                                        .tint(theme.accentBright)
                                }.frame(height: 32)
                            }
                        }
                    }
                    // A menu-bar popover measures its ideal size; a maximum alone
                    // lets ScrollView collapse to zero height during that measurement.
                    .frame(height: min(CGFloat(store.todayDrinks.count) * 32, 192))
                }
            }
            HistoryView(drinks: store.state.drinks, goal: store.preferences.goal,
                        serving: store.preferences.serving, now: store.now)
            if let error = store.error {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
            if let notice = store.notice {
                Label(notice, systemImage: "sparkles")
                    .font(.caption).foregroundStyle(theme.accentBright)
            }
            NotificationStatusView(service: store.notifications)
            Rectangle().fill(theme.border).frame(height: 1)
            Label(store.status, systemImage: "clock")
                .font(.caption).foregroundStyle(theme.textSecondary)
            HStack {
                Button(store.paused ? "恢复提醒" : "暂停今日提醒") { store.togglePause() }
                    .buttonStyle(PanelChipButtonStyle())
                Spacer()
                Button {
                    onOpenSettings()
                } label: { Image(systemName: "gearshape") }
                    .buttonStyle(PanelIconButtonStyle()).help("设置")
                Button { NSApplication.shared.terminate(nil) } label: { Image(systemName: "power") }
                    .buttonStyle(PanelIconButtonStyle()).help("退出喝水BO～")
            }
        }
        .padding(18).frame(width: 350)
        .fixedSize(horizontal: false, vertical: true)
        .appearanceTheme(store.preferences.appearanceTheme)
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .overlay {
            CelebrationOverlay(feedback: store.feedback) { id in
                store.consumeCelebration(id)
            }
            .allowsHitTesting(false)
        }
        .onAppear { store.notifications.refresh() }
    }
}

struct NotificationStatusView: View {
    @ObservedObject var service: NotificationService
    var body: some View {
        if service.checked && !service.authorized {
            VStack(alignment: .leading, spacing: 6) {
                Label("尚未开启系统通知", systemImage: "bell.badge").font(.caption)
                HStack {
                    Button("开启通知") { service.request() }
                    Button("系统设置") { service.openSettings() }
                }.controlSize(.small)
            }
        }
    }
}
