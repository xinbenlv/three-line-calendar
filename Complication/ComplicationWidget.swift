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

    // One row: fixed-width non-truncating time + tail-trimmed title.
    // Title truncates with "…" at a constant size — we do NOT shrink the font to fit.
    private func row(_ e: EventItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(e.timeStringCompact)
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize()
            Text(e.title)
                .font(.system(size: 20))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
    }

    var body: some View {
        Group {
            if !entry.hasData {
                message("Open 3 Line Cal Watch Face to sync")
            } else if entry.events.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(entry.events.prefix(3)) { row($0) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    // Centered empty state. If there's a later event, show a "… until next" countdown.
    // The relative-style Text is locale-aware and live-updates on its own between entries.
    private var emptyState: some View {
        VStack(spacing: 3) {
            if let next = entry.nextEventStart {
                Text("No events today")
                    .font(.system(size: 15, weight: .semibold))
                Text("\(Text(next, style: .relative)) until next")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                Text("No upcoming events")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func message(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
