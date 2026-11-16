import SwiftUI
import WaterCore

struct AppTheme {
    let appearance: AppearanceTheme

    var canvas: Color {
        switch appearance {
        case .classicBlue: Color(hex: "1E2024")
        case .obsidian: Color(hex: "0D0D0F")
        }
    }

    var panelTop: Color {
        switch appearance {
        case .classicBlue: Color(hex: "292B31")
        case .obsidian: Color(hex: "19191C")
        }
    }

    var panelBottom: Color {
        switch appearance {
        case .classicBlue: Color(hex: "191B1F")
        case .obsidian: Color(hex: "0B0B0D")
        }
    }

    var cardTop: Color {
        switch appearance {
        case .classicBlue: Color(hex: "0D1A27")
        case .obsidian: Color(hex: "1B1C20")
        }
    }

    var cardBottom: Color {
        switch appearance {
        case .classicBlue: Color(hex: "07111B")
        case .obsidian: Color(hex: "08090B")
        }
    }

    var surface: Color {
        switch appearance {
        case .classicBlue: Color(hex: "2B2E34")
        case .obsidian: Color(hex: "24252A")
        }
    }

    var surfaceRaised: Color {
        switch appearance {
        case .classicBlue: Color(hex: "363A42")
        case .obsidian: Color(hex: "303138")
        }
    }

    var accent: Color {
        switch appearance {
        case .classicBlue: Color(hex: "0080FF")
        case .obsidian: Color(hex: "D2CFD7")
        }
    }

    var accentBright: Color {
        switch appearance {
        case .classicBlue: Color(hex: "62B7FF")
        case .obsidian: Color(hex: "F1EFF3")
        }
    }

    var accentDeep: Color {
        switch appearance {
        case .classicBlue: Color(hex: "005AB8")
        case .obsidian: Color(hex: "5D5B63")
        }
    }

    var text: Color {
        switch appearance {
        case .classicBlue: Color(hex: "F3F6F9")
        case .obsidian: Color(hex: "ECEBEF")
        }
    }

    var textSecondary: Color {
        switch appearance {
        case .classicBlue: Color(hex: "A8B0BB")
        case .obsidian: Color(hex: "A4A2AA")
        }
    }

    var fish: Color {
        switch appearance {
        case .classicBlue: Color(hex: "06111C")
        case .obsidian: Color(hex: "D8D5DE")
        }
    }

    var numberDesign: Font.Design {
        appearance == .obsidian ? .serif : .rounded
    }

    var border: Color { Color.white.opacity(0.085) }
    var borderStrong: Color { Color.white.opacity(0.16) }

    var panelGradient: LinearGradient {
        LinearGradient(colors: [panelTop, panelBottom],
                       startPoint: .top, endPoint: .bottom)
    }

    var cardGradient: LinearGradient {
        LinearGradient(colors: [cardTop, cardBottom],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var accentGradient: LinearGradient {
        let colors: [Color] = switch appearance {
        case .classicBlue: [Color(hex: "2D9CFF"), Color(hex: "0072DD")]
        case .obsidian: [Color(hex: "45474D"), Color(hex: "15161A")]
        }
        return LinearGradient(colors: colors,
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var defaultWaveAppearance: WaveAppearance {
        appearance.defaultWaveAppearance
    }
}

private struct AppearanceThemeKey: EnvironmentKey {
    static let defaultValue = AppearanceTheme.classicBlue
}

extension EnvironmentValues {
    var appearanceTheme: AppearanceTheme {
        get { self[AppearanceThemeKey.self] }
        set { self[AppearanceThemeKey.self] = newValue }
    }
}

extension View {
    func appearanceTheme(_ theme: AppearanceTheme) -> some View {
        environment(\.appearanceTheme, theme)
    }
}

extension Color {
    init(hex: String) {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            self = .clear
            return
        }
        self.init(red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255,
                  blue: Double(value & 255) / 255)
    }
}

struct ThemedPanelBackground: View {
    @Environment(\.appearanceTheme) private var appearanceTheme
    private var theme: AppTheme { AppTheme(appearance: appearanceTheme) }

    var body: some View {
        ZStack {
            theme.panelGradient
            RadialGradient(colors: [theme.accent.opacity(appearanceTheme == .obsidian ? 0.08 : 0.16), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 340)
            RadialGradient(colors: [theme.accentDeep.opacity(0.10), .clear],
                           center: .bottomLeading, startRadius: 0, endRadius: 260)
        }
    }
}

struct PanelChipButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.appearanceTheme) private var appearanceTheme
    private var theme: AppTheme { AppTheme(appearance: appearanceTheme) }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isEnabled ? theme.text : theme.textSecondary.opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.surface.opacity(configuration.isPressed ? 0.65 : 1),
                        in: Capsule())
            .overlay {
                Capsule().strokeBorder(theme.border, lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.6)
    }
}

struct PanelIconButtonStyle: ButtonStyle {
    @Environment(\.appearanceTheme) private var appearanceTheme
    private var theme: AppTheme { AppTheme(appearance: appearanceTheme) }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(theme.textSecondary)
            .frame(width: 26, height: 26)
            .background(theme.surface.opacity(configuration.isPressed ? 0.6 : 1),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: 1)
            }
    }
}
