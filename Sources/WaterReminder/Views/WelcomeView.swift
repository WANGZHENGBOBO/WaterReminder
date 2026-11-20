import SwiftUI
import WaterCore

struct WelcomeView: View {
    @ObservedObject var store: WaterStore
    let finish: () -> Void
    @State private var step: WelcomeStep = .shortcuts
    @Environment(\.appearanceTheme) private var appearanceTheme

    private var theme: AppTheme { AppTheme(appearance: appearanceTheme) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(theme.border)
            HStack(alignment: .top, spacing: 28) {
                WelcomeStepArtwork(step: step, theme: theme)

                VStack(alignment: .leading, spacing: 14) {
                    Text("第 \(step.rawValue + 1) 步，共 \(WelcomeStep.allCases.count) 步")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accentBright)
                    Text(step.title)
                        .font(.title2.bold())
                    stepContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
            }
            .padding(28)
            Divider().overlay(theme.border)
            footer
        }
        .frame(width: 760, height: 610)
        .background {
            ZStack {
                theme.panelGradient
                RadialGradient(colors: [theme.accent.opacity(0.16), .clear],
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
                Text("3 个快捷指令 + 1 个自动化，设置一次就可以只用手表。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(WelcomeStep.allCases, id: \.rawValue) { item in
                    Button {
                        step = item
                    } label: {
                        Capsule()
                            .fill(item == step ? theme.accentBright : theme.surfaceRaised)
                            .frame(width: item == step ? 22 : 8, height: 8)
                    }
                    .buttonStyle(.plain)
                    .help("第 \(item.rawValue + 1) 步：\(item.shortTitle)")
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .shortcuts:
            Text("三个文件都已经内置在 App 里，不需要另外找下载。点按钮后通过隔空投送发到 iPhone。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            shortcutButtons
            Text("建议三个文件一次性发送完，再在 iPhone 上按顺序安装。")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        case .install:
            bullets([
                "iPhone 安装“喝水BO～”和“喝水BO～ 接收”。前者用于手机手动记录，后者只给自动化使用。",
                "Apple Watch 只安装“喝水BO～ 手表”；接收版不要放到手表。",
                "手表版导入时填写自己的 Apple ID 邮箱，并通过 iMessage 发给自己。"
            ])
        case .permission:
            bullets([
                "先在 iPhone 手动运行一次“喝水BO～”，输入 197 完成记录。",
                "iOS 询问是否访问 iCloud 中的快捷指令文件夹时，选择“始终允许”。",
                "打开“喝水BO～”的详情，开启“允许在锁定时运行”，这样手机放口袋也能处理手表消息。"
            ])
        case .automation:
            bullets([
                "打开“快捷指令 → 自动化”，点右上角 +，选择“收到消息”。",
                "寄件人选择自己；消息包含“喝水BO～”。",
                "选择“立即运行”，关闭“执行前确认”。",
                "添加动作“执行捷径”，选择“喝水BO～ 接收”。",
                "点这个动作的“输入”，选择“捷径输入”，不要留空，然后保存。"
            ])
            Text("自动化本身不是快捷指令文件，而是这条“收到消息”规则。")
                .font(.caption)
                .foregroundStyle(theme.accentBright)
        case .iMessage:
            bullets([
                "打开 iPhone 的“设置 → App → 信息”。",
                "关闭“以短信发送”。如果系统有“RCS 信息”，也关闭。",
                "iMessage 不可用时只停止发送，不会偷偷改发短信。",
                "手表和 iPhone 要保持配对并正常联网。"
            ])
        case .test:
            bullets([
                "在手表上输入 500，点击确认。",
                "手机不应弹出“这次喝了多少 ml？”，应显示“已记录 500ml”。",
                "iCloud 的 Events 文件夹出现 watch 文件后，Mac 自动出现 WCH 的 500ml。",
                "如果仍弹输入框，回到第 4 步确认执行的是“喝水BO～ 接收”，输入是“捷径输入”。"
            ])
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(theme.accentBright)
                Text("设置完成后，日常只需要点手表。")
                    .font(.callout.weight(.semibold))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface.opacity(0.42),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var shortcutButtons: some View {
        VStack(spacing: 8) {
            shortcutButton(title: "发送 iPhone 版", subtitle: "手机手动记录", icon: "iphone", url: shortcutURL)
            shortcutButton(title: "发送接收版", subtitle: "自动化写 iCloud", icon: "arrow.down.doc", url: receiverShortcutURL)
            shortcutButton(title: "发送手表版", subtitle: "手表输入水量", icon: "applewatch", url: watchShortcutURL)
        }
    }

    private func shortcutButton(title: String, subtitle: String, icon: String, url: URL?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.accentBright)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let url {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(title)
            } else {
                Text("缺失").font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(theme.surface.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1)
        }
    }

    private func bullets(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 9) {
                    Circle()
                        .fill(theme.accentBright)
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)
                    Text(line)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("查看完整文字说明") {
                SetupGuideWindow.shared.show(store: store)
            }
            .controlSize(.small)

            SyncStatusLabel(status: store.syncStatus)
                .font(.caption)

            Spacer()

            if step.rawValue > 0 {
                Button("上一步") {
                    if let previous = WelcomeStep(rawValue: step.rawValue - 1) {
                        step = previous
                    }
                }
                .controlSize(.large)
            }

            if step == .test {
                Button("完成并进入菜单栏") { finish() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("下一步") {
                    if let next = WelcomeStep(rawValue: step.rawValue + 1) {
                        step = next
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
    }

    private var shortcutURL: URL? {
        Bundle.main.url(forResource: "喝水BO～", withExtension: "shortcut")
    }

    private var receiverShortcutURL: URL? {
        Bundle.main.url(forResource: "喝水BO～ 接收", withExtension: "shortcut")
    }

    private var watchShortcutURL: URL? {
        Bundle.main.url(forResource: "喝水BO～ 手表", withExtension: "shortcut")
    }
}
