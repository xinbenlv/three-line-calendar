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
                    Text(authorized ? "No upcoming events today." : "No cached events yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(events) { e in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(e.timeString)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Text(e.title)
                                .lineLimit(1)
                                .truncationMode(.tail)   // "…" — never shrink to fit
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
        authorized = store.authorized
        // When authorized, pull real events (Apple-synced Google Calendar) into the snapshot.
        if authorized { store.refreshSnapshot() }
        // Read the snapshot as the single source of truth (works offline too = "cache it").
        events = AppGroup.loadSnapshot().todaysNext(3)
    }
}
