import SwiftUI
import EventKit
import AppKit

/// The Mac window: a live preview of exactly what the widget shows, plus
/// calendar selection. No filler.
struct MacRootView: View {
    @State private var store = CalendarStore()
    @State private var events: [EventItem] = []
    @State private var nextStart: Date?
    @State private var authorized = false

    var body: some View {
        VStack(spacing: 16) {
            previewCard
            if authorized {
                SettingsView(showsTitle: false)   // window title stays "3-Line Calendar"
                    .frame(minHeight: 240)
            } else {
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
        .frame(width: 420, height: 500)
        .navigationTitle(Text("3-Line Calendar"))
        .onAppear { applyScreenshotAppearance() }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await load() }
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
            .frame(minHeight: 160)
            .background(.quaternary.opacity(0.5),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func grant() async {
        _ = await store.requestAccess()
        await load()
    }

    private func load() async {
        #if DEBUG
        WidgetRenderHarness.runIfRequested()
        // Transparent, padded widget renders for the marketing compositor; then stop.
        if WidgetRenderHarness.runMarketingIfRequested() { return }
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
        events = all.todaysNext(5)   // the preview mirrors the 5-line medium widget
        nextStart = all.nextUpcomingStart()
    }

    // Force light/dark for the screenshot script: `-ScreenshotAppearance light|dark`.
    private func applyScreenshotAppearance() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-ScreenshotAppearance"), i + 1 < args.count else { return }
        switch args[i + 1] {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":  NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
        #endif
    }
}
