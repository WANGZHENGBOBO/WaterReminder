import SwiftUI

struct DrinkAnimationView: View {
    let serving: Int
    let record: () -> Void

    var body: some View {
        Button(action: record) {
            Label("喝了 \(serving)ml", systemImage: "plus")
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Color(red: 0, green: 128.0 / 255, blue: 1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
