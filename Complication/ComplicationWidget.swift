import WidgetKit
import SwiftUI

struct ThreeLineCalComplicationView: View {
    var entry: EventEntry

    var body: some View {
        // The shared renderer with the frozen v1 watch metrics.
        EventRowsView(events: entry.events,
                      nextEventStart: entry.nextEventStart,
                      hasData: entry.hasData,
                      style: .watchComplication)
            .containerBackground(.clear, for: .widget)
            // Explicit launch intent: without a widgetURL some watchOS builds
            // drop the implicit tap→app association and taps do nothing.
            .widgetURL(URL(string: "threelinecal://face")!)
    }
}

// Frozen v1 configuration — existing watch-face placements depend on the kind,
// the single family, and the disabled margins. Do not change.
struct ThreeLineCalComplication: Widget {
    let kind = "ThreeLineCalComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
                            provider: EventTimelineProvider(source: SnapshotEventSource())) { entry in
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
