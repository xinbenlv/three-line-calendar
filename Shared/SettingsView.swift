import SwiftUI
import EventKit
import WidgetKit

struct SettingsView: View {
    /// Mac embeds this inline and owns the window title ("3-Line Calendar"), so it
    /// suppresses this view's own "Settings" title. iOS/watchOS push it, so keep it.
    var showsTitle = true

    @State private var store = CalendarStore()
    @State private var calendars: [EKCalendar] = []
    @State private var selected: Set<String> = []
    @State private var message: String?

    #if DEBUG
    @State private var demoCalendars: [String] = []
    private var screenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-ScreenshotMode")
    }
    #endif

    var body: some View {
        Group {
            if showsTitle {
                calendarList.navigationTitle("Settings")
            } else {
                calendarList
            }
        }
        .task { load() }
    }

    private var calendarList: some View {
        List {
            Section("Show calendars") {
                #if DEBUG
                // Screenshot mode: representative calendars in the REAL List UI
                // (real controls, demo data — the same idea as the demo events).
                if screenshotMode {
                    ForEach(demoCalendars, id: \.self) { name in
                        Toggle(name, isOn: .constant(true))
                    }
                } else {
                    realCalendarRows
                }
                #else
                realCalendarRows
                #endif
            }

            #if DEBUG
            // Dev-only QA aid; never ships (Release compiles it out) and must never
            // appear in a screenshot, so it's also hidden in -ScreenshotMode.
            if !screenshotMode {
                Section("Testing") {
                    Button("Insert sample events") { insertSamples() }
                    Button("Remove sample events", role: .destructive) { removeSamples() }
                    if let message {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            #endif

            Section("About") {
                aboutRow("Version", BuildInfo.versionString)
                aboutRow("Build date", BuildInfo.buildDateISO ?? "—")
            }
        }
    }

    // The watch screen is too narrow for label + value side by side; stack there.
    private func aboutRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        #if os(watchOS)
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
            Text(value).font(.footnote).foregroundStyle(.secondary)
        }
        #else
        LabeledContent(label) { Text(value) }
        #endif
    }

    @ViewBuilder private var realCalendarRows: some View {
        if calendars.isEmpty {
            Text("No calendars found.").foregroundStyle(.secondary)
        }
        ForEach(calendars, id: \.calendarIdentifier) { cal in
            Toggle(cal.title, isOn: binding(for: cal))
        }
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
        #if DEBUG
        // Screenshot mode: representative calendar names (localized), all enabled.
        if screenshotMode {
            demoCalendars = [String(localized: "Work"),
                             String(localized: "Personal"),
                             String(localized: "Family")]
            return
        }
        #endif
        calendars = store.eventCalendars()
        if let saved = AppGroup.selectedCalendarIDs {
            selected = saved
        } else {
            selected = Set(calendars.map { $0.calendarIdentifier }) // default: all on
        }
    }

    #if DEBUG
    // watchOS EventKit is read-only (no save/remove), and the simulator has no Google account
    // synced. So we seed the shared snapshot directly — that's exactly what the complication reads.
    private func insertSamples() {
        AppGroup.saveSnapshot(EventItem.demo(from: Date()))
        WidgetCenter.shared.reloadAllTimelines()
        message = String(localized: "Seeded 3 sample events.")
    }

    private func removeSamples() {
        AppGroup.saveSnapshot([])
        WidgetCenter.shared.reloadAllTimelines()
        message = String(localized: "Cleared sample events.")
    }
    #endif
}
