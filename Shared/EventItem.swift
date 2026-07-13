import Foundation

/// A calendar event reduced to what the complication needs.
struct EventItem: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let start: Date
    let end: Date

    /// 24-hour `HH:mm` — matches the sketch (10:00 / 14:00).
    var timeString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f.string(from: start)
    }
}

extension Array where Element == EventItem {
    /// Today's next `n` events (still upcoming/ongoing), from a wider snapshot window.
    func todaysNext(_ n: Int, now: Date = Date()) -> [EventItem] {
        let cal = Calendar.current
        let endOfToday = cal.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
        return filter { $0.end > now && $0.start <= endOfToday }
            .sorted { $0.start < $1.start }
            .prefix(n)
            .map { $0 }
    }

    /// Start of the soonest event strictly in the future (may be a later day) — for the countdown.
    func nextUpcomingStart(now: Date = Date()) -> Date? {
        filter { $0.start > now }.map(\.start).min()
    }
}

extension EventItem {
    /// Used for widget previews / the WidgetKit gallery placeholder.
    static var sample: [EventItem] { demo(from: Date()) }

    /// Near-future demo events, relative to `now`, so they always render as "upcoming"
    /// regardless of what time it is. Used to seed the simulator (no Google account synced there).
    static func demo(from now: Date) -> [EventItem] {
        func ev(_ id: String, _ title: String, startMin: Int, durMin: Int) -> EventItem {
            let s = now.addingTimeInterval(TimeInterval(startMin * 60))
            return EventItem(id: id, title: title,
                             start: s, end: s.addingTimeInterval(TimeInterval(durMin * 60)))
        }
        return [
            ev("1", "Standup", startMin: 15, durMin: 15),
            ev("2", "1:1 with Sam", startMin: 90, durMin: 30),
            ev("3", "Design review with the platform team about onboarding",
               startMin: 180, durMin: 60),
        ]
    }
}
