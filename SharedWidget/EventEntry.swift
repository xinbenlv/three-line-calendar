import WidgetKit
import Foundation

/// Timeline entry shared by every platform's widget.
struct EventEntry: TimelineEntry {
    let date: Date
    let events: [EventItem]     // today's next up to 3 as of `date`
    let nextEventStart: Date?   // soonest future event (may be a later day) for the countdown
    let hasData: Bool
}
