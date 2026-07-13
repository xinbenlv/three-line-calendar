import SwiftUI

/// Metrics for the shared 3-line rendering.
/// `.watchComplication` is frozen v1 behavior — do not change it.
struct EventRowsStyle {
    var timeFont: Font
    var titleFont: Font
    var emptyTitleFont: Font
    var emptyCaptionFont: Font
    var messageFont: Font
    var rowSpacing: CGFloat
    var compactTime: Bool

    /// v1 watch complication look (20/15/13pt, compact time).
    static let watchComplication = EventRowsStyle(
        timeFont: .system(size: 20, weight: .semibold),
        titleFont: .system(size: 20),
        emptyTitleFont: .system(size: 15, weight: .semibold),
        emptyCaptionFont: .system(size: 13),
        messageFont: .system(size: 15),
        rowSpacing: 3,
        compactTime: true)

    /// In-app preview card on iPhone/iPad/Mac: same proportions, full time format.
    static let appPreview = EventRowsStyle(
        timeFont: .system(size: 20, weight: .semibold),
        titleFont: .system(size: 20),
        emptyTitleFont: .system(size: 15, weight: .semibold),
        emptyCaptionFont: .system(size: 13),
        messageFont: .system(size: 15),
        rowSpacing: 8,
        compactTime: false)
}

/// The signature "3 lines" view shared by the apps and every widget family:
/// up to three rows of fixed time + tail-truncated title, plus the shared
/// empty / countdown / sync-message states.
struct EventRowsView: View {
    var events: [EventItem]
    var nextEventStart: Date?
    var hasData: Bool
    var style: EventRowsStyle = .watchComplication

    var body: some View {
        Group {
            if !hasData {
                message("Open 3 Line Cal Watch Face to sync")
            } else if events.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: style.rowSpacing) {
                    ForEach(events.prefix(3)) { row($0) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    // One row: fixed-width non-truncating time + tail-trimmed title.
    // Title truncates with "…" at a constant size — we do NOT shrink the font to fit.
    private func row(_ e: EventItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(style.compactTime ? e.timeStringCompact : e.timeString)
                .font(style.timeFont)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize()
            Text(e.title)
                .font(style.titleFont)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
    }

    // Centered empty state. If there's a later event, show a live localized countdown.
    private var emptyState: some View {
        VStack(spacing: 3) {
            if let next = nextEventStart {
                Text("No events today")
                    .font(style.emptyTitleFont)
                Text("\(Text(next, style: .relative)) until next")
                    .font(style.emptyCaptionFont)
                    .foregroundStyle(.secondary)
            } else {
                Text("No upcoming events")
                    .font(style.messageFont)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func message(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(style.messageFont)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
