import SwiftUI

// macOS app: ships under the same bundle ID as the iOS app (universal purchase),
// hosts the desktop widget, and shows the same live preview + settings.
@main
struct ThreeLineCalMacApp: App {
    var body: some Scene {
        WindowGroup {
            MacRootView()
        }
        .windowResizability(.contentSize)
    }
}
