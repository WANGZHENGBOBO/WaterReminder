import SwiftUI
import WaterCore

// Measure the document separately from the bounded window viewport. A tall
// fixedSize root otherwise gives NSHostingView a minimum taller than the screen.
struct TopAnchoredViewport<Content: View>: View {
    let maximumHeight: CGFloat
    let onSizeChange: (CGSize) -> Void
    @ViewBuilder var content: () -> Content
    @Environment(\.appearanceTheme) private var appearanceTheme

    private var theme: AppTheme { AppTheme(appearance: appearanceTheme) }

    var body: some View {
        ScrollView(.vertical) {
            content()
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: DocumentHeightKey.self, value: geometry.size.height)
                })
        }
        // The window alone owns viewport height. Updating a second SwiftUI
        // height first produces a centered intermediate frame before AppKit resizes.
        .frame(width: 350)
        .frame(maxHeight: .infinity, alignment: .top)
        .clipped()
        .onPreferenceChange(DocumentHeightKey.self) { height in
            guard height > 0 else { return }
            onSizeChange(CGSize(width: 350, height: min(height, maximumHeight)))
        }
        .background(ThemedPanelBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.borderStrong.opacity(0.55), lineWidth: 1)
        }
    }
}

private struct DocumentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
