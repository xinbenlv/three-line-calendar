import Foundation

/// Shared container between the watch app and the complication (same device).
enum AppGroup {
    static let identifier = "group.im.zzn.apps.threelinecal"

    static var defaults: UserDefaults {
        guard let suite = UserDefaults(suiteName: identifier) else {
            #if DEBUG
            // A silent fallback would invisibly split app/widget data on a
            // misprovisioned build (the classic macOS app-group failure mode).
            print("AppGroup: suite \(identifier) unavailable — using .standard, data will NOT be shared")
            #endif
            return .standard
        }
        return suite
    }

    private static let selectedKey = "selectedCalendarIDs"
    private static let snapshotKey = "eventsSnapshot"

    /// Which calendars to show. `nil` means "not configured yet" → treat as all.
    static var selectedCalendarIDs: Set<String>? {
        get {
            guard let arr = defaults.array(forKey: selectedKey) as? [String] else { return nil }
            return Set(arr)
        }
        set {
            if let s = newValue { defaults.set(Array(s), forKey: selectedKey) }
            else { defaults.removeObject(forKey: selectedKey) }
        }
    }

    static var hasSnapshot: Bool { defaults.data(forKey: snapshotKey) != nil }

    /// The app writes today's remaining events here; the widgets read them.
    /// Encoding is frozen: JSONEncoder defaults (.deferredToDate = seconds since
    /// 2001-01-01 UTC) — scripts/seed_events.py hardcodes that epoch. Do not change.
    static func saveSnapshot(_ events: [EventItem]) {
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: snapshotKey)
        }
    }

    static func loadSnapshot() -> [EventItem] {
        guard let data = defaults.data(forKey: snapshotKey),
              let events = try? JSONDecoder().decode([EventItem].self, from: data)
        else { return [] }
        return events
    }
}
