import SwiftUI
import EventKit

/// iPhone/iPad home screen of the app: a live preview of exactly what the
/// widget shows, plus Settings. No filler.
struct RootView: View {
    @State private var store = CalendarStore()
    @State private var events: [EventItem] = []
    @State private var nextStart: Date?
    @State private var authorized = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    previewCard
                    if !authorized {
                        Button {
                            Task { await grant() }
                        } label: {
                            Text("Grant Calendar Access")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(20)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("3-Line Calendar")
            .toolbar {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .task { await load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await load() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            Task { await load() }
        }
    }

    /// The same 3-line rendering the widget uses, framed like a medium widget.
    private var previewCard: some View {
        EventRowsView(events: events,
                      nextEventStart: nextStart,
                      hasData: true,
                      style: .appPreview)
            .padding(20)
            .frame(minHeight: 170)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func grant() async {
        _ = await store.requestAccess()
        await load()
    }

    private func load() async {
        #if DEBUG
        // Screenshot mode (Debug only, never ships): demo events for App Store captures.
        if ProcessInfo.processInfo.arguments.contains("-ScreenshotMode") {
            events = EventItem.demo(from: Date())
            authorized = true
            return
        }
        #endif
        authorized = store.authorized
        // When authorized, refresh the shared snapshot (also reloads the widgets).
        let all = authorized ? store.refreshSnapshot() : AppGroup.loadSnapshot()
        events = all.todaysNext(3)
        nextStart = all.nextUpcomingStart()
    }
}
