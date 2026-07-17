import SwiftUI

@main
struct ThreeLineCalWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Deep-link target for the complication's widgetURL. The root
                // view already shows today's events, so arriving is the action.
                .onOpenURL { _ in }
        }
        .backgroundTask(.appRefresh) { _ in
            await BackgroundRefresh.run()
        }
    }
}
