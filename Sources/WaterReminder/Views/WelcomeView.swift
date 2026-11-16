import SwiftUI
import WaterCore

struct WelcomeView: View {
    @ObservedObject var store: WaterStore
    let finish: () -> Void
    @Environment(\.appearanceTheme) private var appearanceTheme

    private var theme: AppTheme { AppTheme(appearance: appearanceTheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 20) {
                    phonePurpose
                    Divider()
                    privacyNote
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                pairingPanel
                    .frame(width: 244)
            }

            footer
        }
        .padding(32)
        .frame(width: 720)
        .background {
            ZStack {
                theme.panelGradient
                RadialGradient(colors: [theme.accent.opacity(0.18), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 520)
            }
        }
        .appearanceTheme(store.preferences.appearanceTheme)
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(theme.accent.opacity(0.18))
                Image(systemName: "drop.fill")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(theme.accentBright)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("喝水BO～").font(.title2.bold())
                Text("Mac 负责提醒和汇总，iPhone 负责随手记录。")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var phonePurpose: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("手机端是做什么的？").font(.headline)
            Text("你不在 Mac 前，也能喝完水就记下来。快捷指令把记录放回你自己的 iCloud，Mac 打开时会自动合并到当天进度。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 11) {
                feature(
                    icon: "drop.fill",
                    title: "一按就记",
                    detail: "记录默认一杯 197ml，也可以输入自定义水量。"
                )
                feature(
                    icon: "chart.bar.fill",
                    title: "随时看进度",
                    detail: "显示今天完成了多少、还差多少。"
                )
                feature(
                    icon: "arrow.triangle.2.circlepath",
                    title: "自动回到 Mac",
                    detail: "不用在 Mac 上重复输入，历史记录也会一起保留。"
                )
            }
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 19))
                .foregroundStyle(theme.accentBright)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 5) {
                Text("数据只属于你").font(.headline)
                Text("不需要注册，不连接开发者服务器，也没有数据收集、广告或统计。记录只保存在你的 Mac、iPhone 和本人 iCloud Drive 中；关闭同步后就只留在本机。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(theme.surface.opacity(0.55),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1)
        }
    }

    private var pairingPanel: some View {
        VStack(spacing: 13) {
            VStack(spacing: 4) {
                Text("用 iPhone 添加").font(.headline)
                Text("Mac 与 iPhone 使用同一个 Apple ID")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "iphone.gen3")
                .font(.system(size: 38))
                .foregroundStyle(theme.accentBright)
                .frame(maxWidth: .infinity)
                .frame(height: 96)
                .background(theme.surface.opacity(0.6),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text("点击下面的按钮，把随 App 提供的最新快捷指令发送到 iPhone。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let shortcutURL {
                ShareLink(item: shortcutURL) {
                    Label("发送最新快捷指令", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Text("没有找到随 App 提供的快捷指令文件")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text("在 iPhone 上打开收到的文件，选择“替换快捷指令”或“添加快捷指令”。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .background(theme.surface.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(theme.borderStrong.opacity(0.8))
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            SyncStatusLabel(status: store.syncStatus)
                .font(.caption)

            if case .disabled = store.syncStatus {
                Button("开启同步") {
                    _ = store.setICloudSyncEnabled(true)
                }
                .controlSize(.small)
            }

            Spacer()

            Button("进入菜单栏") { finish() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }

    private func feature(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.accentBright)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var shortcutURL: URL? {
        Bundle.main.url(forResource: "喝水BO～", withExtension: "shortcut")
    }
}
