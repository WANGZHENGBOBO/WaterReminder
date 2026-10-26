import SwiftUI

struct WelcomeView: View {
    let finish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color(red: 0, green: 0.5, blue: 1))
                VStack(alignment: .leading, spacing: 3) {
                    Text("欢迎使用 喝水BO～").font(.title2.bold())
                    Text("一杯一杯，轻松记得更准确。")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("应用在屏幕顶部菜单栏", systemImage: "menubar.rectangle")
                    .font(.headline)
                Text("打开后不会停留在桌面。找到菜单栏里的水滴和百分比，点击它就能记录喝水、查看进度。")
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                    Text("0%")
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.quaternary, in: Capsule())
                .accessibilityLabel("菜单栏示意：水滴，0%")
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("先量好常用杯子的容量", systemImage: "cup.and.saucer")
                    .font(.headline)
                Text("在设置里填入每杯的毫升数。以后每喝完一杯，就点一次“喝了 ××ml”，记录会更准确。")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("按你的节奏提醒", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Text("每日目标、每次杯量、工作日和周末的提醒时段与间隔，都可以自己调整。")
                    .foregroundStyle(.secondary)
            }

            Label("不联网、不收集个人资料；记录只保存在这台 Mac。", systemImage: "lock.shield")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Text("以后可在设置里重新查看此说明")
                    .font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button("去菜单栏开始使用") { finish() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(width: 470)
    }
}
