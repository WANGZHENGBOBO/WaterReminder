import AppKit
import SwiftUI
import WaterCore

struct DrinkAnimationView: View {
    let serving: Int
    let record: (Int) -> Void
    @State private var showsCustomAmount = false
    @State private var customAmount = ""
    @FocusState private var customAmountFocused: Bool
    @Environment(\.appearanceTheme) private var appearanceTheme

    private var theme: AppTheme { AppTheme(appearance: appearanceTheme) }

    private var parsedCustomAmount: Int? {
        let value = customAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Int(value), (1...2000).contains(amount) else { return nil }
        return amount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let buttonWidth = max(proxy.size.width - 8, 0)
                HStack(spacing: 8) {
                    Button {
                        showsCustomAmount = false
                        record(serving)
                    } label: {
                        Label("喝了 \(serving)ml", systemImage: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: buttonWidth * 0.8, height: 40)
                            .background(theme.accentGradient,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                            }
                            .shadow(color: theme.accentDeep.opacity(0.45), radius: 12, y: 4)
                    }
                    .buttonStyle(.plain)

                    Button {
                        customAmount = ""
                        showsCustomAmount.toggle()
                    } label: {
                        Text(showsCustomAmount ? "收起" : "自定义")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(theme.accentBright)
                            .frame(width: buttonWidth * 0.2, height: 40)
                            .background(theme.surface,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(theme.accent.opacity(0.35), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("记录一个自定义饮水量")
                }
            }
            .frame(height: 40)

            if showsCustomAmount {
                HStack(spacing: 8) {
                    TextField("例如 \(serving)", text: $customAmount)
                        .textFieldStyle(.roundedBorder)
                        .focused($customAmountFocused)
                        .onSubmit(recordCustomAmount)
                    Text("ml").foregroundStyle(.secondary)
                    Button("记录", action: recordCustomAmount)
                        .buttonStyle(.borderedProminent)
                        .tint(theme.accent)
                        .disabled(parsedCustomAmount == nil)
                        .keyboardShortcut(.defaultAction)
                }
                .padding(10)
                .background(theme.surface.opacity(0.7),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1)
                }
                .overlay(alignment: .bottomLeading) {
                    if parsedCustomAmount == nil {
                        Text("请输入 1–2000 ml 的水量")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .offset(y: 16)
                    }
                }
                .padding(.bottom, parsedCustomAmount == nil ? 14 : 0)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: showsCustomAmount)
        .onChange(of: showsCustomAmount) { shown in
            if shown {
                // The panel is nonactivating so a normal drink can be logged
                // without switching apps. Typing still requires activation.
                NSApp.activate(ignoringOtherApps: true)
                Task { @MainActor in
                    await Task.yield()
                    customAmountFocused = true
                }
            } else {
                customAmountFocused = false
            }
        }
    }

    private func recordCustomAmount() {
        guard let amount = parsedCustomAmount else { return }
        record(amount)
        showsCustomAmount = false
    }
}
