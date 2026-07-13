import WidgetKit
import Foundation

/// Timeline provider shared by all platforms' widgets, parameterized by data source.
/// The boundary algorithm is frozen v1 behavior: one entry now plus one just after
/// each event ends (so passed events roll off on-face), re-pull after the last
/// boundary or in 30 minutes on a quiet day.
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

    func getTimeline(in context: Context, completion: @escaping (Timeline<EventEntry>) -> Void) {
        let now = Date()
        let all = source.upcomingEvents(now: now)
        let lines = maxLines(for: context.family)

        var boundaries = [now]
        for e in all where e.end > now {
            boundaries.append(e.end.addingTimeInterval(1))
        }
        let dates = Array(Set(boundaries.filter { $0 >= now })).sorted().prefix(24)
        var entries = dates.map { makeEntry(for: $0, lines: lines, from: all) }
        if entries.isEmpty { entries = [makeEntry(for: now, lines: lines, from: all)] }

        let refresh = max((dates.last ?? now).addingTimeInterval(60), now.addingTimeInterval(1800))
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
