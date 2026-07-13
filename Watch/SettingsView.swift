import SwiftUI
import EventKit
import WidgetKit

struct SettingsView: View {
    @State private var store = CalendarStore()
    @State private var calendars: [EKCalendar] = []
    @State private var selected: Set<String> = []
    @State private var message: String?

    var body: some View {
        List {
            Section("Show calendars") {
                if calendars.isEmpty {
                    Text("No calendars found.").foregroundStyle(.secondary)
                }
                ForEach(calendars, id: \.calendarIdentifier) { cal in
                    Toggle(cal.title, isOn: binding(for: cal))
                }
            }

            // Simulator has no Google account synced, so seed test events to demo the UI.
            Section("Testing") {
                Button("Insert sample events") { insertSamples() }
                Button("Remove sample events", role: .destructive) { removeSamples() }
                if let message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .task { load() }
    }

    private func binding(for cal: EKCalendar) -> Binding<Bool> {
        Binding(
            get: { selected.contains(cal.calendarIdentifier) },
            set: { on in
                if on { selected.insert(cal.calendarIdentifier) }
                else { selected.remove(cal.calendarIdentifier) }
                AppGroup.selectedCalendarIDs = selected
                store.refreshSnapshot()
            })
    }

    private func load() {
        calendars = store.eventCalendars()
        if let saved = AppGroup.selectedCalendarIDs {
            selected = saved
        } else {
            selected = Set(calendars.map { $0.calendarIdentifier }) // default: all on
        }
    }

    // watchOS EventKit is read-only (no save/remove), and the simulator has no Google account
    // synced. So we seed the shared snapshot directly — that's exactly what the complication reads.
    private func insertSamples() {
        AppGroup.saveSnapshot(EventItem.demo(from: Date()))
        WidgetCenter.shared.reloadAllTimelines()
        message = "Seeded 3 sample events."
    }

    private func removeSamples() {
        AppGroup.saveSnapshot([])
        WidgetCenter.shared.reloadAllTimelines()
        message = "Cleared sample events."
    }
}
