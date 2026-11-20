import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PhoneContentView: View {
    @ObservedObject var session: PhoneSession
    @State private var choosingFolder = false
    @State private var selectedAmount = CompanionSettings.fallback.serving
    @State private var submitFeedback: String?
    @State private var feedbackTrigger = 0
    @State private var feedbackTask: Task<Void, Never>?

    private let canvas = Color(hex: "0D0D0F")
    private let cardTop = Color(hex: "1B1C20")
    private let cardBottom = Color(hex: "08090B")
    private let border = Color(hex: "2E2F34")
    private let text = Color(hex: "ECEBEF")
    private let secondary = Color(hex: "A4A2AA")
    private let accent = Color(hex: "D2CFD7")
    private let accentText = Color(hex: "111114")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    amountCard
                    syncCard
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 18)
            }
            .background(canvas.ignoresSafeArea())
            .foregroundStyle(text)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            selectedAmount = session.defaultServing
        }
        .onChange(of: session.defaultServing) { oldValue, newValue in
            if selectedAmount == oldValue {
                selectedAmount = newValue
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification
        )) { _ in
            session.refresh()
        }
        .fileImporter(
            isPresented: $choosingFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                session.chooseFolder(url)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("喝水BO～")
                .font(.largeTitle.bold())
            HStack(spacing: 7) {
                Image(systemName: "applewatch")
                    .font(.subheadline)
                Text(session.watchReachable ? "Apple Watch 已连接" : "等待 Apple Watch 连接")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(secondary)
        }
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("这次喝了多少")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 23)
                .padding(.top, 24)

            AmountEditor(
                value: $selectedAmount,
                text: Color(hex: "F1EFF3"),
                secondary: secondary
            )
            .frame(height: 250)
            .padding(.horizontal, 23)

            HStack(spacing: 22) {
                Text("进度：\(progressPercent)%")
                Text("\(session.todayTotal)ml / \(session.goal)ml")
            }
            .font(.system(size: 13))
                .foregroundStyle(secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 2)

            Button {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
                let saved = session.submit(milliliters: selectedAmount)
                showSubmitFeedback(saved: saved, amount: selectedAmount)
            } label: {
                HStack(spacing: 8) {
                    if submitFeedback != nil {
                        Image(systemName: "checkmark")
                    }
                    Text(submitFeedback ?? "提交记录")
                }
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FlatAccentButtonStyle(accent: accent, text: accentText))
            .padding(.horizontal, 23)
            .padding(.top, 9)
            .padding(.bottom, 23)
        }
        .background(
            LinearGradient(
                colors: [cardTop, cardBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(border, lineWidth: 1)
        }
        .sensoryFeedback(.success, trigger: feedbackTrigger)
        .animation(.easeOut(duration: 0.18), value: submitFeedback)
    }

    private func showSubmitFeedback(saved: Bool, amount: Int) {
        feedbackTask?.cancel()
        submitFeedback = saved ? "已保存 \(amount) ml" : "已记录 \(amount) ml"
        feedbackTrigger += 1
        feedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            submitFeedback = nil
        }
    }

    private var progressPercent: Int {
        Int(Double(session.todayTotal) / Double(max(session.goal, 1)) * 100)
    }

    private var syncCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "icloud")
                    .font(.title3)
                    .foregroundStyle(secondary)
                Text("同步设置")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(folderBadgeText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(
                        session.selectedFolderName == nil
                            ? Color(hex: "C9C6CF")
                            : accent
                    )
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(Color(hex: "24252A"), in: Capsule())
            }

            Text("iCloud 记录文件夹")
                .font(.title3.weight(.semibold))
                .padding(.top, 21)

            Text("读取 Mac 的杯量与提醒设置，\n饮水记录写入 Sync/Events。")
                .font(.subheadline)
                .foregroundStyle(secondary)
                .lineSpacing(4)
                .padding(.top, 9)

            Text("iCloud Drive / Shortcuts / … / Sync")
                .font(.caption)
                .foregroundStyle(secondary)
                .padding(.top, 13)

            if session.pendingCount > 0 {
                Button("立即重试 · \(session.pendingCount) 条待写入") {
                    session.retryPending()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .padding(.top, 8)
            }

            Button {
                choosingFolder = true
            } label: {
                Text("选择 Sync 文件夹")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: "ECEBEF"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FlatSecondaryButtonStyle(
                fill: Color(hex: "24252A"),
                border: Color(hex: "3C3D43")
            ))
            .padding(.top, 18)
            .padding(.bottom, 23)
        }
        .padding(.horizontal, 23)
        .padding(.top, 21)
    }

    private var folderBadgeText: String {
        if session.pendingCount > 0 { return "待同步" }
        if case .waiting = session.syncState, session.selectedFolderName != nil {
            return "同步异常"
        }
        return session.selectedFolderName == nil ? "尚未选择" : "已选择"
    }
}

private struct AmountEditor: View {
    @Binding var value: Int
    let text: Color
    let secondary: Color

    var body: some View {
        VStack(spacing: 0) {
            EditableAmountField(value: $value, color: UIColor(text))
                .frame(maxWidth: .infinity)
                .frame(height: 96)
            Text("ml")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(secondary)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EditableAmountField: UIViewRepresentable {
    @Binding var value: Int
    let color: UIColor

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.keyboardType = .numberPad
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.textColor = color
        field.tintColor = color
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = 60
        field.defaultTextAttributes = [
            .font: UIFont.systemFont(ofSize: 104, weight: .semibold),
            .foregroundColor: color,
            .kern: -3
        ]
        field.textAlignment = .center
        field.text = "\(value)"
        field.accessibilityLabel = "要记录的毫升数"
        field.accessibilityHint = "轻点后直接输入数字"
        field.inputAccessoryView = context.coordinator.makeToolbar()
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if !field.isFirstResponder, field.text != "\(value)" {
            field.text = "\(value)"
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EditableAmountField

        init(_ parent: EditableAmountField) {
            self.parent = parent
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            textField.selectAll(nil)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            commit(textField)
        }

        @objc func editingChanged(_ textField: UITextField) {
            let digits = String((textField.text ?? "").filter(\.isNumber).prefix(4))
            if digits != textField.text {
                textField.text = digits
            }
            if let amount = Int(digits), amount > 0 {
                parent.value = min(amount, 2000)
            }
        }

        @objc private func finishEditing() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }

        func makeToolbar() -> UIToolbar {
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            toolbar.items = [
                UIBarButtonItem(systemItem: .flexibleSpace),
                UIBarButtonItem(
                    title: "完成",
                    style: .done,
                    target: self,
                    action: #selector(finishEditing)
                )
            ]
            return toolbar
        }

        private func commit(_ textField: UITextField) {
            let amount = Int(textField.text ?? "") ?? parent.value
            let clamped = min(max(amount, 1), 2000)
            parent.value = clamped
            textField.text = "\(clamped)"
        }
    }
}

private struct FlatAccentButtonStyle: ButtonStyle {
    let accent: Color
    let text: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(text)
            .padding(.vertical, 15)
            .background(accent, in: Capsule())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct FlatSecondaryButtonStyle: ButtonStyle {
    let fill: Color
    let border: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .background(fill, in: Capsule())
            .overlay {
                Capsule().strokeBorder(border, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private extension Color {
    init(hex: String) {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        let value = UInt32(digits, radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
