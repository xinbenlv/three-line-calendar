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
    /// Empty-state coffee cup: nil hides it; < 40 sits beside the text, ≥ 40 above it.
    var illustrationSize: CGFloat? = nil
    /// Ticker-scroll long titles. App processes only — WidgetKit renders are static.
    var marqueeTitles: Bool = false

    /// v1 watch complication look (20/15/13pt, compact time).
    static let watchComplication = EventRowsStyle(
        timeFont: .system(size: 20, weight: .semibold),
        titleFont: .system(size: 20),
        emptyTitleFont: .system(size: 15, weight: .semibold),
        emptyCaptionFont: .system(size: 13),
        messageFont: .system(size: 15),
        rowSpacing: 3,
        compactTime: true,
        illustrationSize: 22)

    /// In-app preview card on iPhone/iPad/Mac: same proportions, full time format.
    static let appPreview = EventRowsStyle(
        timeFont: .system(size: 20, weight: .semibold),
        titleFont: .system(size: 20),
        emptyTitleFont: .system(size: 15, weight: .semibold),
        emptyCaptionFont: .system(size: 13),
        messageFont: .system(size: 15),
        rowSpacing: 8,
        compactTime: false,
        illustrationSize: 64,
        marqueeTitles: true)
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
                // Callers pass events already narrowed to their line budget
                // (3 on the watch face / lock screen, 5 on system widgets).
                VStack(alignment: .leading, spacing: style.rowSpacing) {
                    ForEach(events) { row($0) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    // One row: fixed-width non-truncating time + tail-trimmed title.
    // Title truncates with "…" at a constant size — we do NOT shrink the font to fit.
    // App views ticker-scroll instead of truncating; the time never moves.
    private func row(_ e: EventItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(style.compactTime ? e.timeStringCompact : e.timeString)
                .font(style.timeFont)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize()
            if style.marqueeTitles {
                MarqueeText(text: e.title)
                    .font(style.titleFont)
            } else {
                Text(e.title)
                    .font(style.titleFont)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
    }

    // Centered empty state, with the coffee-break cup where the style allows:
    // beside the text when small (complication), above it when roomy. The
    // text-only fallback keeps the longest of the 21 locales from truncating.
    @ViewBuilder
    private var emptyState: some View {
        Group {
            if let size = style.illustrationSize {
                if size >= 40 {
                    VStack(spacing: 10) {
                        EmptyStateIllustration(size: size)
                        emptyText
                    }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) {
                            EmptyStateIllustration(size: size)
                            emptyText
                        }
                        emptyText
                    }
                }
            } else {
                emptyText
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // If there's a later event, show a live localized countdown.
    private var emptyText: some View {
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
    }

    private func message(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(style.messageFont)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
