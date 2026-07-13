import WidgetKit
import Foundation

/// Timeline entry shared by every platform's widget.
struct EventEntry: TimelineEntry {
    let date: Date
    let events: [EventItem]     // today's next events as of `date`, already narrowed
                                // to the family's line count (3 accessory / 5 system)
    let nextEventStart: Date?   // soonest future event (may be a later day) for the countdown
    let hasData: Bool
}
