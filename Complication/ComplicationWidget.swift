import WidgetKit
import SwiftUI

struct EventEntry: TimelineEntry {
    let date: Date
    let events: [EventItem]     // today's next up to 3 as of `date`
    let nextEventStart: Date?   // soonest future event (may be a later day) for the countdown
    let hasData: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> EventEntry {
        EventEntry(date: Date(), events: Array(EventItem.sample.prefix(3)),
                   nextEventStart: nil, hasData: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (EventEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EventEntry>) -> Void) {
        let now = Date()
        let all = AppGroup.loadSnapshot()

        // One entry now, plus one just after each event ends, so passed events roll off on-face.
        var boundaries = [now]
        for e in all where e.end > now {
            boundaries.append(e.end.addingTimeInterval(1))
        }
        let dates = Array(Set(boundaries.filter { $0 >= now })).sorted().prefix(24)
        var entries = dates.map { makeEntry(for: $0) }
        if entries.isEmpty { entries = [makeEntry(for: now)] }

        // Re-pull the snapshot after the last boundary, or in 30 min if the day is quiet.
        let refresh = max((dates.last ?? now).addingTimeInterval(60), now.addingTimeInterval(1800))
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func makeEntry(for date: Date) -> EventEntry {
        var all = AppGroup.loadSnapshot()
        #if DEBUG
        // Screenshot aid (Debug only, never ships): fall back to demo events when the
        // simulator has no synced calendar, so the complication renders real-looking data.
        if all.todaysNext(3, now: date).isEmpty { all = EventItem.demo(from: date) }
        #endif
        return EventEntry(date: date,
                          events: all.todaysNext(3, now: date),
                          nextEventStart: all.nextUpcomingStart(now: date),
                          hasData: AppGroup.hasSnapshot || !all.isEmpty)
    }
}

struct ThreeLineCalComplicationView: View {
    var entry: EventEntry

    var body: some View {
        // The shared renderer with the frozen v1 watch metrics.
        EventRowsView(events: entry.events,
                      nextEventStart: entry.nextEventStart,
                      hasData: entry.hasData,
                      style: .watchComplication)
            .containerBackground(.clear, for: .widget)
    }
}

struct ThreeLineCalComplication: Widget {
    let kind = "ThreeLineCalComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ThreeLineCalComplicationView(entry: entry)
        }
        .configurationDisplayName("Next 3 Events")
        .description("Your next three calendar events.")
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()   // reclaim the default L/R/T/B padding -> full-width text
    }
}

@main
struct ThreeLineCalComplicationBundle: WidgetBundle {
    var body: some Widget {
        ThreeLineCalComplication()
    }
}
