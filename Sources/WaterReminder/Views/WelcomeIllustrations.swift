import SwiftUI

enum WelcomeStep: Int, CaseIterable, Equatable {
    case shortcuts
    case install
    case permission
    case automation
    case iMessage
    case test

    var title: String {
        switch self {
        case .shortcuts: "先发送三个快捷指令"
        case .install: "手机和手表分别安装"
        case .permission: "允许 iCloud 和锁定运行"
        case .automation: "创建收到消息自动化"
        case .iMessage: "关闭短信和 RCS 回退"
        case .test: "测试一次，确认链路"
        }
    }

    var shortTitle: String {
        switch self {
        case .shortcuts: "发送"
        case .install: "安装"
        case .permission: "授权"
        case .automation: "自动化"
        case .iMessage: "iMessage"
        case .test: "测试"
        }
    }
}

struct WelcomeStepArtwork: View {
    let step: WelcomeStep
    let theme: AppTheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.cardGradient)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(theme.borderStrong, lineWidth: 1)
            content
                .padding(18)
        }
        .frame(width: 310, height: 330)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .shortcuts:
            VStack(spacing: 15) {
                HStack(spacing: 14) {
                    device("laptopcomputer", "Mac")
                    Image(systemName: "arrow.right")
                        .foregroundStyle(theme.accentBright)
                    device("iphone", "iPhone")
                }
                VStack(alignment: .leading, spacing: 7) {
                    chip("喝水BO～", icon: "iphone")
                    chip("喝水BO～ 接收", icon: "arrow.down.doc")
                    chip("喝水BO～ 手表", icon: "applewatch")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("三个文件都已放进 App")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        case .install:
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 9) {
                    device("iphone", "iPhone", compact: true)
                    chip("喝水BO～", icon: "iphone")
                    chip("喝水BO～ 接收", icon: "arrow.down.doc")
                }
                Image(systemName: "arrow.right")
                    .foregroundStyle(theme.accentBright)
                    .padding(.top, 40)
                VStack(spacing: 9) {
                    device("applewatch", "Watch", compact: true)
                    chip("喝水BO～ 手表", icon: "applewatch")
                    Text("手表只留这一条")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        case .permission:
            VStack(spacing: 10) {
                mockDialog(
                    title: "“喝水BO～”想访问 iCloud 文件",
                    detail: "只用于读写喝水记录",
                    button: "始终允许"
                )
                mockDialog(
                    title: "快捷指令详情",
                    detail: "允许在锁定时运行",
                    toggleOn: true
                )
            }
        case .automation:
            VStack(spacing: 8) {
                flowRow("message.fill", "收到消息", "包含 喝水BO～")
                flowArrow
                flowRow("bolt.fill", "执行捷径", "喝水BO～ 接收")
                flowArrow
                flowRow("text.cursor", "输入", "捷径输入")
            }
        case .iMessage:
            VStack(alignment: .leading, spacing: 12) {
                toggleRow("以短信发送", isOn: false)
                toggleRow("RCS 信息", isOn: false)
                HStack(spacing: 8) {
                    Image(systemName: "message.fill")
                        .foregroundStyle(theme.accentBright)
                    Text("消息气泡保持 iMessage 蓝色")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        case .test:
            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    miniDevice("applewatch", "手表")
                    Image(systemName: "arrow.right")
                    miniDevice("iphone", "iPhone")
                    Image(systemName: "arrow.right")
                    miniDevice("icloud.fill", "iCloud")
                    Image(systemName: "arrow.right")
                    miniDevice("laptopcomputer", "Mac")
                }
                .foregroundStyle(theme.accentBright)
                Text("500ml")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.accentBright)
                Text("手机不弹输入框，Mac 出现 WCH 记录")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var flowArrow: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(theme.accentBright)
    }

    private func device(_ icon: String, _ title: String, compact: Bool = false) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: compact ? 23 : 31, weight: .medium))
                .foregroundStyle(theme.accentBright)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.text)
        }
        .frame(width: compact ? 76 : 92, height: compact ? 72 : 88)
        .background(theme.surfaceRaised.opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func miniDevice(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .medium))
            Text(title).font(.system(size: 9))
        }
        .frame(maxWidth: .infinity)
    }

    private func chip(_ title: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.accentBright)
                .frame(width: 17)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.text)
            Spacer(minLength: 0)
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(theme.accentBright)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(theme.surface.opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func mockDialog(
        title: String,
        detail: String,
        button: String? = nil,
        toggleOn: Bool? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.text)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
            HStack {
                Spacer()
                if let button {
                    Text(button)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accentBright)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(theme.accent.opacity(0.18),
                                    in: Capsule())
                }
                if let toggleOn {
                    Capsule()
                        .fill(toggleOn ? Color.green : theme.surfaceRaised)
                        .frame(width: 34, height: 19)
                        .overlay(alignment: toggleOn ? .trailing : .leading) {
                            Circle()
                                .fill(.white.opacity(0.9))
                                .frame(width: 15, height: 15)
                                .padding(2)
                        }
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface.opacity(0.9),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func flowRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.accentBright)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.accentBright)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(theme.surface.opacity(0.9),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func toggleRow(_ title: String, isOn: Bool) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.text)
            Spacer()
            Capsule()
                .fill(isOn ? Color.green : theme.surfaceRaised)
                .frame(width: 34, height: 19)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white.opacity(0.9))
                        .frame(width: 15, height: 15)
                        .padding(2)
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.surface.opacity(0.9),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
