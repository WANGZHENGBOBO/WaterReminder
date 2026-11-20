import SwiftUI
import WaterCore

struct SetupGuideView: View {
    @ObservedObject var store: WaterStore
    let close: () -> Void
    @Environment(\.appearanceTheme) private var appearanceTheme

    private var theme: AppTheme { AppTheme(appearance: appearanceTheme) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(theme.border)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    shortcutSection
                    guideSteps
                    troubleshooting
                }
                .padding(28)
            }
            Divider().overlay(theme.border)
            footer
        }
        .frame(width: 760, height: 780)
        .background(theme.canvas)
        .appearanceTheme(store.preferences.appearanceTheme)
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.accent.opacity(0.16))
                Image(systemName: "list.number")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(theme.accentBright)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("首次设置说明").font(.title3.bold())
                Text("3 个快捷指令 + 1 个自动化，按顺序做一次即可")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("快捷指令已内置", systemImage: "checkmark.seal.fill")
                .font(.caption)
                .foregroundStyle(theme.accentBright)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("先分清三个快捷指令和一个自动化").font(.headline)
            Text("自动化不是快捷指令文件本身，而是 iPhone 上的一条规则：收到手表消息后，自动运行“喝水BO～ 接收”。主快捷指令仍然用于手机手动记录，手表版只在手表上运行。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("三个快捷指令").font(.headline)
            HStack(alignment: .top, spacing: 10) {
                shortcutCard(
                    name: "喝水BO～",
                    role: "手机手动记录",
                    icon: "iphone",
                    url: shortcutURL,
                    button: "发送 iPhone 版"
                )
                shortcutCard(
                    name: "喝水BO～ 接收",
                    role: "自动化写 iCloud",
                    icon: "arrow.down.doc.fill",
                    url: receiverShortcutURL,
                    button: "发送接收版"
                )
                shortcutCard(
                    name: "喝水BO～ 手表",
                    role: "手表输入水量",
                    icon: "applewatch",
                    url: watchShortcutURL,
                    button: "发送手表版"
                )
            }
        }
    }

    private var guideSteps: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("按顺序操作").font(.headline)

            stepCard(
                number: "1",
                title: "发送并安装三个快捷指令",
                body: """
                在上面的卡片分别点三次发送，通过隔空投送发到 iPhone。
                在 iPhone 上安装“喝水BO～”和“喝水BO～ 接收”。
                打开“喝水BO～ 手表”并安装；手表上只保留这一条。
                """
            )
            stepCard(
                number: "2",
                title: "第一次运行主快捷指令",
                body: """
                在 iPhone 打开“喝水BO～”，输入 197 并完成一次。
                iOS 询问 iCloud 文件夹时选“始终允许”。
                进入“喝水BO～”的详情，打开“允许在锁定时运行”。
                """
            )
            stepCard(
                number: "3",
                title: "新建“收到消息”自动化",
                body: """
                打开“快捷指令 → 自动化”，点右上角 +，选择“收到消息”。
                寄件人选择自己；消息包含“喝水BO～”。
                选择“立即运行”，关闭“执行前确认”。
                添加动作“执行捷径”，选择“喝水BO～ 接收”。
                点这个动作的“输入”，选择“快捷指令输入”，然后保存。
                """
            )
            stepCard(
                number: "4",
                title: "关闭短信和 RCS 回退",
                body: """
                打开 iPhone“设置 → App → 信息”。
                关闭“以短信发送”；如果有“RCS 信息”，也关闭。
                这样 iMessage 不可用时只会停止发送，不会偷偷改发短信。
                """
            )
            stepCard(
                number: "5",
                title: "用手表测试 500ml",
                body: """
                打开手表“喝水BO～ 手表”，输入 500 并确认。
                手机不应弹出水量输入框；应显示“已记录 500ml”。
                iCloud 的 Events 文件夹会出现 watch 记录，Mac 随后自动出现 500ml。
                """
            )
        }
    }

    private var troubleshooting: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("如果没成功，只看这几项").font(.headline)
            troubleRow("仍然弹出“这次喝了多少 ml？”", "自动化执行错了，或者执行动作的输入没有选“快捷指令输入”。应执行“喝水BO～ 接收”。")
            troubleRow("消息收到了，但手机没有通知", "检查自动化的寄件人/内容条件，并确认设为“立即运行”。")
            troubleRow("手机有通知，Mac 没记录", "打开 Mac 设置里的 iCloud 同步；再点“打开同步文件夹”，确认 Events 里有新文件。")
            troubleRow("记录变成了 0ml", "这是旧版接收捷径生成的无效记录；重新发送并替换“喝水BO～ 接收”。")
            troubleRow("手表 500，Mac 还是 197", "说明自动化没有运行“喝水BO～ 接收”，或输入没有传进去。")
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("设置完成后，日常只需要在手表点快捷指令。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("打开同步文件夹") { store.openSyncFolder() }
                .controlSize(.small)
            Button("完成") { close() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
    }

    private func shortcutCard(
        name: String,
        role: String,
        icon: String,
        url: URL?,
        button: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.accentBright)
            Text(name).font(.callout.weight(.semibold))
            Text(role).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let url {
                ShareLink(item: url) {
                    Label(button, systemImage: "square.and.arrow.up")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("未找到文件").font(.caption2).foregroundStyle(.red)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
        .background(theme.surface.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1)
        }
    }

    private func stepCard(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.callout.weight(.bold))
                .foregroundStyle(theme.accentBright)
                .frame(width: 26, height: 26)
                .background(theme.accent.opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.callout.weight(.semibold))
                Text(body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface.opacity(0.34),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func troubleRow(_ symptom: String, _ fix: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(theme.accentBright)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(symptom).font(.callout.weight(.semibold))
                Text(fix).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
