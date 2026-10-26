import SwiftUI
import WaterCore

struct DashboardView: View {
    @ObservedObject var store: WaterStore
    var onOpenSettings: () -> Void
    @State private var showRecords = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WaterGaugeView(total: store.total, goal: store.preferences.goal,
                           count: store.todayDrinks.count, date: store.now,
                           appearance: store.preferences.waveAppearance ?? WaveAppearance())
            DrinkAnimationView(serving: store.preferences.serving) {
                store.addDrink()
            }
            HStack {
                Button("稍后 \(store.preferences.snooze) 分钟") { store.snooze() }
                    .disabled(store.paused || (store.completed && store.preferences.stopAtGoal))
                Spacer()
                Button(showRecords ? "收起记录" : "今日记录") { showRecords.toggle() }
            }
            .controlSize(.small)
            if showRecords {
                if store.todayDrinks.isEmpty {
                    Text("今天还没有记录").foregroundStyle(.secondary).font(.caption)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(store.todayDrinks) { drink in
                                HStack {
                                    Text(drink.date, format: .dateTime.hour().minute().second())
                                        .monospacedDigit().foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(drink.grams)ml").monospacedDigit()
                                    Button("撤销") { store.remove(drink) }.buttonStyle(.borderless)
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
                    .font(.caption).foregroundStyle(.tint)
            }
            NotificationStatusView(service: store.notifications)
            Divider()
            Label(store.status, systemImage: "clock")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(store.paused ? "恢复提醒" : "暂停今日提醒") { store.togglePause() }.buttonStyle(.borderless)
                Spacer()
                Button {
                    onOpenSettings()
                } label: { Image(systemName: "gearshape") }.help("设置")
                Button { NSApplication.shared.terminate(nil) } label: { Image(systemName: "power") }.help("退出喝水BO～")
            }
        }
        .padding(18).frame(width: 350)
        .fixedSize(horizontal: false, vertical: true)
        .overlay { CelebrationOverlay(feedback: store.feedback).allowsHitTesting(false) }
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
