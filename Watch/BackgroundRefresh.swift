import Foundation
import WatchKit

/// Rewrites the App Group snapshot while the app is backgrounded, so the
/// complication tracks calendar changes without the app ever being opened.
/// watchOS grants ~4 wakes/hour to apps with a complication on the active
/// face; we use ~8/day — every 3 hours, pulled in to 00:05 across midnight
/// so the morning face reflects anything that changed overnight.
enum BackgroundRefresh {
    /// Only one outstanding request exists at a time (a new schedule replaces
    /// the old), so each run — and each foreground — just re-schedules.
    static func schedule(now: Date = Date()) {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86400)
        let pastMidnight = cal.startOfDay(for: tomorrow).addingTimeInterval(5 * 60)
        let preferred = min(now.addingTimeInterval(3 * 3600), pastMidnight)
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: preferred,
                                                         userInfo: nil) { _ in }
    }

    @MainActor
    static func run() async {
        let store = CalendarStore()
        // refreshSnapshot() also asks WidgetKit to reload the complication.
        if store.authorized { store.refreshSnapshot() }
        schedule()
    }
}
