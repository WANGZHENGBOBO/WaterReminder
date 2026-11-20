import SwiftUI

@main
struct WaterCompanionWatchApp: App {
    @StateObject private var watchSession = WatchSession()

    var body: some Scene {
        WindowGroup {
            WatchContentView(session: watchSession)
        }
    }
}
