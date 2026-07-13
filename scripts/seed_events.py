#!/usr/bin/env python3
"""Seed the watch App Group snapshot with sample events (for simulator screenshots).

watchOS EventKit is read-only and the simulator has no calendar account, so we write the
shared snapshot directly. Dates are seconds since 2001-01-01 UTC (JSONEncoder .deferredToDate).

Usage: seed_events.py <path-to-group.im.zzn.apps.threelinecal.plist>
"""
import sys, json, time, plistlib

REF = 978307200  # 2001-01-01 UTC epoch


def ev(i, title, start_min, dur_min):
    start = time.time() + start_min * 60
    return {"id": i, "title": title, "start": start - REF, "end": start + dur_min * 60 - REF}


def main(path):
    events = [
        ev("1", "Standup", 20, 15),
        ev("2", "1:1 with Sam", 75, 30),
        ev("3", "Design review with the platform team", 140, 60),
    ]
    with open(path, "wb") as f:
        plistlib.dump({"eventsSnapshot": json.dumps(events).encode()}, f, fmt=plistlib.FMT_BINARY)
    print(f"seeded {len(events)} events -> {path}")


if __name__ == "__main__":
    main(sys.argv[1])
