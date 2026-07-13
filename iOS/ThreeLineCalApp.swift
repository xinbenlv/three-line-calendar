import SwiftUI

// Minimal iOS companion. Its only job is to make this an iOS app delivery
// (so it uploads via standard tooling) and host the embedded watch app.
@main
struct ThreeLineCalApp: App {
    var body: some Scene {
        WindowGroup {
            CompanionView()
        }
    }
}
