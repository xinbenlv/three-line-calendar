import SwiftUI

struct ContentView: View {
    @State private var store = CalendarStore()
    @State private var events: [EventItem] = []
    @State private var authorized = false

    var body: some View {
        NavigationStack {
            List {
                if !authorized && events.isEmpty {
                    Button("Grant Calendar Access") { Task { await grant() } }
                        .font(.footnote)
                }
                if events.isEmpty {
                    // Two literals (not a String ternary) so both keys localize.
                    if authorized {
                        Text("No upcoming events today.").foregroundStyle(.secondary)
                    } else {
                        Text("No cached events yet.").foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(events) { e in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(e.timeStringCompact)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            MarqueeText(text: e.title)   // ticker-scrolls when long; time stays put
                        }
                        .font(.system(size: 17))
                    }
                }
                NavigationLink("Settings") { SettingsView() }
            }
            .navigationTitle("3-Line Calendar")
        }
        .task { await load() }
    }

    private func grant() async {
        _ = await store.requestAccess()
        await load()
    }

    private func load() async {
        #if DEBUG
        // Screenshot mode (Debug only, never ships): show demo events for App Store captures.
        if ProcessInfo.processInfo.arguments.contains("-ScreenshotMode") {
            events = EventItem.demo(from: Date())
            authorized = true
            return
        }
        #endif
        authorized = store.authorized
        // When authorized, pull real events (Apple-synced Google Calendar) into the snapshot.
        if authorized { store.refreshSnapshot() }
        // Read the snapshot as the single source of truth (works offline too = "cache it").
        events = AppGroup.loadSnapshot().todaysNext(3)
        // The first background-refresh request must come from the foreground.
        BackgroundRefresh.schedule()
    }
}
