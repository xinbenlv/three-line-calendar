import Foundation

/// Shared container between the watch app and the complication (same device).
enum AppGroup {
    static let identifier = "group.im.zzn.apps.threelinecal"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
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

    /// The app writes today's remaining events here; the complication reads them.
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
