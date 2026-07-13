import Foundation
import EventKit
import WidgetKit

/// Owns EventKit access and produces the filtered event list the app + complication show.
@MainActor
final class CalendarStore {
    let store = EKEventStore()

    var authorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func requestAccess() async -> Bool {
        do { return try await store.requestFullAccessToEvents() }
        catch { return false }
    }

    func eventCalendars() -> [EKCalendar] {
        store.calendars(for: .event).sorted { $0.title < $1.title }
    }

    /// Upcoming timed events across the next `days` days in the selected calendars,
    /// excluding all-day and multi-day events. The complication shows today's next 3 and
    /// uses the later ones only to compute the "next in …" countdown.
    func upcomingEvents(days: Int = 7, now: Date = Date()) -> [EventItem] {
        let cal = Calendar.current
        guard let end = cal.date(byAdding: .day, value: days, to: now) else { return [] }

        let selectedIDs = AppGroup.selectedCalendarIDs
        let calendars = eventCalendars().filter { c in
            guard let sel = selectedIDs else { return true } // nil => all
            return sel.contains(c.calendarIdentifier)
        }
        guard !calendars.isEmpty else { return [] }

        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: calendars)
        return store.events(matching: predicate)
            .filter { ev in
                if ev.isAllDay { return false }                                   // no all-day
                if ev.endDate.timeIntervalSince(ev.startDate) > 24 * 3600 { return false } // no >24h
                if !cal.isDate(ev.startDate, inSameDayAs: ev.endDate) { return false }      // no multi-day
                return ev.endDate > now                                           // still upcoming/ongoing
            }
            .sorted { $0.startDate < $1.startDate }
            .map { EventItem(id: $0.eventIdentifier ?? UUID().uuidString,
                             title: ($0.title?.isEmpty == false ? $0.title!
                                                                : String(localized: "(No title)")),
                             start: $0.startDate,
                             end: $0.endDate) }
    }

    /// Recompute, persist for the complication, and ask WidgetKit to reload.
    @discardableResult
    func refreshSnapshot() -> [EventItem] {
        let all = upcomingEvents()
        AppGroup.saveSnapshot(all)
        WidgetCenter.shared.reloadAllTimelines()
        return all
    }
}
