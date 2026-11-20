import SwiftUI

struct WatchContentView: View {
    @ObservedObject var session: WatchSession
    @State private var amount = 197
    @State private var editingAmount = false
    @State private var showRecordConfirmation = false
    @State private var confirmationTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 3) {
                ZStack {
                ForEach(0..<40, id: \.self) { index in
                    let angle = Double(index) / 40 * 2 * .pi - .pi / 2
                    Capsule()
                        .fill(
                            Double(index) / 40 < progress
                                ? Color.white.opacity(0.72)
                                : Color.white.opacity(0.15)
                        )
                        .frame(width: 1.4, height: 3.4)
                        .rotationEffect(.degrees(Double(index) * 9))
                        .position(
                            x: 86 + cos(angle) * 82,
                            y: 86 + sin(angle) * 82
                        )
                }

                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 12)
                    .frame(width: 138, height: 138)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(white: 0.34),
                                Color(white: 0.98),
                                Color(white: 0.48),
                                Color(white: 0.34)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 138, height: 138)

                VStack(spacing: 1) {
                    Text("本次饮水")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("\(amount)")
                        .font(.system(size: 56, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.72)
                    Text("ml")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    editingAmount = true
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("本次饮水 \(amount) 毫升")
                .accessibilityHint("轻点后输入水量")
                }
                .frame(width: 172, height: 172)

                Button {
                    session.record(milliliters: amount)
                } label: {
                    HStack(spacing: 4) {
                        if showRecordConfirmation {
                            Image(systemName: "checkmark")
                        }
                        Text(
                            session.sending
                                ? "发送中"
                                : (showRecordConfirmation ? "已记录" : "提交记录")
                        )
                    }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WatchRecordButtonStyle())
                .disabled(session.sending)
            }

        }
        .padding(.horizontal, 14)
        .background(Color(red: 13 / 255, green: 13 / 255, blue: 15 / 255).ignoresSafeArea())
        .onAppear {
            amount = session.defaultAmount
        }
        .onChange(of: session.defaultAmount) { _, newValue in
            amount = newValue
        }
        .onChange(of: session.confirmation) { _, confirmation in
            guard confirmation != nil else { return }
            confirmationTask?.cancel()
            showRecordConfirmation = true
            confirmationTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.6))
                guard !Task.isCancelled else { return }
                showRecordConfirmation = false
            }
        }
        .sheet(isPresented: $editingAmount) {
            AmountKeypad(initial: amount) { newValue in
                amount = newValue
            }
        }
        .sensoryFeedback(.success, trigger: session.confirmation)
        .animation(.snappy, value: amount)
    }

    private var progress: Double {
        guard session.goal > 0 else { return 0 }
        return min(max(Double(session.todayTotal) / Double(session.goal), 0), 1)
    }
}

private struct AmountKeypad: View {
    @Environment(\.dismiss) private var dismiss

    let initial: Int
    let onCommit: (Int) -> Void

    @State private var text: String
    @State private var replaceOnNextDigit = true

    init(initial: Int, onCommit: @escaping (Int) -> Void) {
        self.initial = initial
        self.onCommit = onCommit
        _text = State(initialValue: "\(initial)")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(text.isEmpty ? "0" : text)
                        .font(.system(size: 36, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(text.isEmpty ? .secondary : .primary)
                    Text("ml")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 38)

                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 5),
                        count: 3
                    ),
                    spacing: 5
                ) {
                    ForEach(1...9, id: \.self) { digit in
                        digitButton(digit)
                    }
                    actionButton("⌫", action: deleteLast)
                    digitButton(0)
                    commitButton
                }
            }
            .padding(.horizontal, 8)
            .navigationTitle("输入水量")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func digitButton(_ digit: Int) -> some View {
        Button {
            append("\(digit)")
        } label: {
            keypadLabel("\(digit)")
        }
        .buttonStyle(.plain)
    }

    private func actionButton(
        _ label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            keypadLabel(label)
        }
        .buttonStyle(.plain)
    }

    private var commitButton: some View {
        Button(action: commit) {
            keypadLabel("✓", isPrimary: true)
        }
        .buttonStyle(.plain)
    }

    private func keypadLabel(_ label: String, isPrimary: Bool = false) -> some View {
        Text(label)
            .font(.headline)
            .foregroundStyle(isPrimary ? Color.black : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(
                isPrimary
                    ? Color(red: 210 / 255, green: 207 / 255, blue: 215 / 255)
                    : Color(white: 0.16),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
    }

    private func append(_ digit: String) {
        if replaceOnNextDigit {
            text = digit
            replaceOnNextDigit = false
        } else if text == "0" {
            text = digit
        } else if text.count < 4 {
            text += digit
        }
    }

    private func deleteLast() {
        replaceOnNextDigit = false
        if !text.isEmpty {
            text.removeLast()
        }
    }

    private func commit() {
        let entered = Int(text) ?? initial
        onCommit(min(max(entered, 1), 2000))
        dismiss()
    }
}

private struct WatchRecordButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .padding(.vertical, 4)
            .padding(.horizontal, 5)
            .background(Color(red: 210 / 255, green: 207 / 255, blue: 215 / 255), in: Capsule())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
