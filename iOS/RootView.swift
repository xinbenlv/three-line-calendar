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
                            Text("Continue")
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
        WidgetRenderHarness.runIfRequested()
        // Screenshot mode (Debug only, never ships): demo events for App Store captures.
        if ProcessInfo.processInfo.arguments.contains("-ScreenshotMode") {
            events = EventItem.demo(from: Date())
            authorized = true
            return
        }
        // QA aid: write demo events into the real (simulator) calendar via EventKit,
        // so the widget's direct-EventKit path can be exercised end to end.
        if ProcessInfo.processInfo.arguments.contains("-SeedEventKit") {
            seedEventKitDemo()
        }
        #endif
        authorized = store.authorized
        // When authorized, refresh the shared snapshot (also reloads the widgets).
        let all = authorized ? store.refreshSnapshot() : AppGroup.loadSnapshot()
        events = all.todaysNext(5)   // the preview mirrors the 5-line medium widget
        nextStart = all.nextUpcomingStart()
    }

    #if DEBUG
    private static var didSeed = false

    // Once per launch (load() re-fires on foreground + EKEventStoreChanged);
    // repeated *launches* still duplicate events — it's a QA tool, keep it simple.
    private func seedEventKitDemo() {
        guard store.authorized, !Self.didSeed else { return }
        Self.didSeed = true
        for item in EventItem.demo(from: Date()) {
            let ev = EKEvent(eventStore: store.store)
            ev.title = item.title
            ev.startDate = item.start
            ev.endDate = item.end
            ev.calendar = store.store.defaultCalendarForNewEvents
            try? store.store.save(ev, span: .thisEvent, commit: false)
        }
        try? store.store.commit()
    }
    #endif
}
