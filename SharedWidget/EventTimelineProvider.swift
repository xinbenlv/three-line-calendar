import WidgetKit
import Foundation

/// Timeline provider shared by all platforms' widgets, parameterized by data source.
/// v2.1 boundary algorithm: the timeline is pre-rendered at every moment the
/// content changes — event starts, just after event ends, and each local midnight
/// (the "today" window itself moves) — so the face stays correct through the night
/// even when WidgetKit defers background reloads entirely.
struct EventTimelineProvider: TimelineProvider {
    var source: EventSource

    /// How many rows the family's standard height fits: the roomier system
    /// families show 5; the watch face and lock-screen accessories keep 3.
    private func maxLines(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge: return 5
        default: return 3
        }
    }

    func placeholder(in context: Context) -> EventEntry {
        EventEntry(date: Date(),
                   events: Array(EventItem.sample.prefix(maxLines(for: context.family))),
                   nextEventStart: nil, hasData: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (EventEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context)
                                     : makeEntry(for: Date(), lines: maxLines(for: context.family)))
    }

    /// Every moment the rendered content changes: now, each future event start
    /// (a row appears / the countdown flips), just after each end (passed events
    /// roll off), and each of the next 7 local midnights ("today's next 3" is
    /// recomputed from the already-cached window — no reload needed overnight).
    /// Pure so tests can assert it for synthetic clocks (the sim can't time-travel).
    static func timelineDates(now: Date, events: [EventItem],
                              calendar: Calendar = .current) -> [Date] {
        var boundaries: Set<Date> = [now]
        for e in events {
            if e.start > now { boundaries.insert(e.start) }
            if e.end > now { boundaries.insert(e.end.addingTimeInterval(1)) }
        }
        var day = calendar.startOfDay(for: now)
        for _ in 0..<7 {
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86400)
            boundaries.insert(day.addingTimeInterval(1))
        }
        return Array(boundaries.filter { $0 >= now }.sorted().prefix(40))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EventEntry>) -> Void) {
        let now = Date()
        let all = source.upcomingEvents(now: now)
        let lines = maxLines(for: context.family)

        let dates = Self.timelineDates(now: now, events: all)
        var entries = dates.map { makeEntry(for: $0, lines: lines, from: all) }
        if entries.isEmpty { entries = [makeEntry(for: now, lines: lines, from: all)] }

        // The midnight entries make the timeline self-sufficient for a week, so a
        // daily re-pull (plus the app-triggered reloads) is all we ask WidgetKit for.
        let refresh = min(max((dates.last ?? now).addingTimeInterval(60),
                              now.addingTimeInterval(1800)),
                          now.addingTimeInterval(24 * 3600))
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func makeEntry(for date: Date, lines: Int, from events: [EventItem]? = nil) -> EventEntry {
        var all = events ?? source.upcomingEvents(now: date)
        #if DEBUG
        // Screenshot aid (Debug only, never ships): fall back to demo events when the
        // simulator has no synced calendar, so the widget renders real-looking data.
        // QA can disable it (defaults write <group> debugDisableDemoFallback -bool true)
        // to tell a real EventKit read apart from the demo data.
        if all.todaysNext(lines, now: date).isEmpty,
           !AppGroup.defaults.bool(forKey: "debugDisableDemoFallback") {
            all = EventItem.demo(from: date)
        }
        #endif
        return EventEntry(date: date,
                          events: all.todaysNext(lines, now: date),
                          nextEventStart: all.nextUpcomingStart(now: date),
                          hasData: source.hasData || !all.isEmpty)
    }
}
