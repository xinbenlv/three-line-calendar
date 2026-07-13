import Foundation
import EventKit

/// Where a widget's events come from. The watch complication reads the snapshot the
/// watch app wrote (v1 behavior); iOS/macOS widgets read EventKit directly and fall
/// back to the snapshot.
protocol EventSource {
    /// All upcoming events in the window (the provider narrows to today's 3 per entry).
    func upcomingEvents(now: Date) -> [EventItem]
    var hasData: Bool { get }
}

/// The App Group snapshot written by the app.
struct SnapshotEventSource: EventSource {
    func upcomingEvents(now: Date) -> [EventItem] { AppGroup.loadSnapshot() }
    var hasData: Bool { AppGroup.hasSnapshot }
}

#if !os(watchOS)
/// Direct EventKit read inside the widget process — fresh data at every timeline
/// reload. Widgets can't prompt: the containing app must already hold full calendar
/// access, and the *widget's* Info.plist must carry NSCalendarsFullAccessUsageDescription
/// or TCC kills the process on the first EventKit call.
struct EventKitEventSource: EventSource {
    private let snapshot = SnapshotEventSource()

    private var authorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func upcomingEvents(now: Date) -> [EventItem] {
        guard authorized else { return snapshot.upcomingEvents(now: now) }
        let live = CalendarStore.fetchUpcoming(in: EKEventStore(), now: now)
        // A quiet week and a failed read look the same (both empty) — prefer the
        // app-written snapshot then, since stale beats blank and it's usually empty too.
        return live.isEmpty ? snapshot.upcomingEvents(now: now) : live
    }

    var hasData: Bool { authorized || snapshot.hasData }
}
#endif
