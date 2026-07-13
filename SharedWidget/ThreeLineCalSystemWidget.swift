#if !os(watchOS)
import WidgetKit
import SwiftUI

/// The iOS/iPad/macOS widget. Reads EventKit directly (fresh at every reload),
/// falling back to the app-written App Group snapshot.
struct ThreeLineCalSystemWidget: Widget {
    let kind = "ThreeLineCalWidget"

    private var families: [WidgetFamily] {
        #if os(macOS)
        [.systemSmall, .systemMedium, .systemLarge]
        #else
        [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline]
        #endif
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
                            provider: EventTimelineProvider(source: EventKitEventSource())) { entry in
            SystemWidgetView(entry: entry)
        }
        .configurationDisplayName("Next 3 Events")
        .description("Your next three calendar events.")
        .supportedFamilies(families)
    }
}
#endif
