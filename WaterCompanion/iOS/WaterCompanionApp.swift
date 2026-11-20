import SwiftUI

@main
struct WaterCompanionApp: App {
    @StateObject private var phoneSession = PhoneSession()

    var body: some Scene {
        WindowGroup {
            PhoneContentView(session: phoneSession)
        }
    }
}
