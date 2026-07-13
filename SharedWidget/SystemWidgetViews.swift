#if !os(watchOS)
import SwiftUI
import WidgetKit

// Widget-family metrics for iOS/iPadOS/macOS. The watch keeps `.watchComplication`.
extension EventRowsStyle {
    /// Lock-screen rectangular (vibrant rendering, system content margins).
    static let accessory = EventRowsStyle(
        timeFont: .system(size: 14, weight: .semibold),
        titleFont: .system(size: 14),
        emptyTitleFont: .system(size: 13, weight: .semibold),
        emptyCaptionFont: .system(size: 12),
        messageFont: .system(size: 13),
        rowSpacing: 1,
        compactTime: true)

    /// Home-screen small: three tight rows under a "Today" header (also StandBy).
    static let systemSmall = EventRowsStyle(
        timeFont: .system(size: 12, weight: .semibold),
        titleFont: .system(size: 12),
        emptyTitleFont: .system(size: 13, weight: .semibold),
        emptyCaptionFont: .system(size: 12),
        messageFont: .system(size: 13),
        rowSpacing: 8,
        compactTime: true)

    /// Home-screen medium — the flagship, mirrors the watch look.
    static let systemMedium = EventRowsStyle(
        timeFont: .system(size: 17, weight: .semibold),
        titleFont: .system(size: 17),
        emptyTitleFont: .system(size: 15, weight: .semibold),
        emptyCaptionFont: .system(size: 13),
        messageFont: .system(size: 15),
        rowSpacing: 10,
        compactTime: false)

    /// Desktop large (macOS): medium at larger type.
    static let systemLarge = EventRowsStyle(
        timeFont: .system(size: 20, weight: .semibold),
        titleFont: .system(size: 20),
        emptyTitleFont: .system(size: 17, weight: .semibold),
        emptyCaptionFont: .system(size: 15),
        messageFont: .system(size: 17),
        rowSpacing: 14,
        compactTime: false)
}

/// Family-aware layouts for the iOS/iPad/macOS widget.
struct SystemWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: EventEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            rows(style: .accessory)
                .containerBackground(.clear, for: .widget)
        case .accessoryInline:
            inline
                .containerBackground(.clear, for: .widget)
        case .systemSmall:
            headered(style: .systemSmall)
                .containerBackground(.background, for: .widget)
        case .systemLarge:
            headered(style: .systemLarge)
                .containerBackground(.background, for: .widget)
        default: // .systemMedium
            rows(style: .systemMedium)
                .containerBackground(.background, for: .widget)
        }
    }

    private func rows(style: EventRowsStyle) -> some View {
        EventRowsView(events: entry.events,
                      nextEventStart: entry.nextEventStart,
                      hasData: entry.hasData,
                      style: style)
    }

    /// "Today" caption above the rows, for the roomier square/large families.
    private func headered(style: EventRowsStyle) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            rows(style: style)
        }
    }

    /// Single line for the lock screen inline slot: "10:00 Standup".
    @ViewBuilder
    private var inline: some View {
        if let e = entry.events.first {
            Text("\(e.timeStringCompact) \(e.title)")
        } else {
            Text("No events today")
        }
    }
}
#endif
