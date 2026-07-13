# 3-Line Calendar for Watch Face

**Your next three calendar events, always at a glance — on your Apple Watch face, your
iPhone/iPad Home Screen and Lock Screen, and your Mac desktop.**

A clean 3-line view that shows your next three events of the day — each as
`time · title` — so you always know what's next, without opening an app.
Translated into 21 languages.

## Screenshots

<p align="center">
  <img src="screenshots/watch-face-ultra.png" width="220" alt="Complication on the Apple Watch Ultra face">
  &nbsp;&nbsp;
  <img src="screenshots/watch-face-modular.png" width="220" alt="Complication on a modular watch face">
</p>
<p align="center"><em>The “Next 3 Events” complication on built-in watch faces.</em></p>

<p align="center">
  <img src="screenshots/watch-app.png" width="200" alt="In-app list of upcoming events">
  &nbsp;&nbsp;
  <img src="screenshots/watch-app-list.png" width="200" alt="App icon in the watch app list">
</p>

## No BS

I got sick and tired of apps that nag, upsell, and harvest your data. So I built the one I
actually want to use — and I'm giving it away.

- 💯 **Completely free** — no charge, no hidden charges, no premium tier
- 🛒 **No in-app purchases** — nothing to unlock, no consumables, no upsells
- 🔑 **No account, no sign-in** — just install and go
- 🚫 **No ads** — ever
- 🕵️ **No tracking, no analytics** — the app makes no network requests to send your data anywhere
- 📅 **Your data stays with you** — calendar events are read on-device via Apple's EventKit and never leave your watch/phone
- 🔓 **Open source** — Apache 2.0; read every line, build it yourself, or fork it

If you like it, please leave a review and share it with friends. That's the whole business model. 🙂

## What it does

- Shows your **next 3 timed events for today** as three clean lines, everywhere:
  - **Apple Watch** — the original `accessoryRectangular` watch-face complication
  - **iPhone & iPad** — Home Screen widgets (small, medium) + Lock Screen widgets
    (rectangular, inline)
  - **Mac** — desktop widgets (small, medium, large)
- Reads your calendar through Apple's EventKit, so any account you add
  (**including Google Calendar**) shows up automatically
- Skips all-day and multi-day events to keep the focus on what's coming
- When today is clear, shows a live countdown to your next event
- **21 languages**: English + zh-Hans, zh-Hant, ja, ko, es, fr, de, it, pt-BR, ru, ar,
  hi, id, tr, nl, pl, th, vi, sv, da — times follow your region's 12/24-hour setting

## Architecture

Six XcodeGen targets around one shared core:

- **iOS app** (`iOS/`) — live widget preview + settings (`im.zzn.apps.threelinecal`),
  embeds the watch app and the iOS widget
- **iOS/iPadOS widget** (`Widget/` + `SharedWidget/`) — WidgetKit appex (`….widget`)
- **watchOS app** (`Watch/`) — watch UI + snapshot writer (`….watchkitapp`)
- **Complication** (`Complication/`) — the WidgetKit `accessoryRectangular` widget
  (`….watchkitapp.widget`)
- **macOS app** (`Mac/`) — same bundle ID as the iOS app → universal purchase; embeds
  the desktop widget
- **macOS widget** (`MacWidget/`) — WidgetKit appex (`….widget`)
- **Shared** (`Shared/`) — `EventItem` model, EventKit access (`CalendarStore`), the
  3-line renderer (`EventRowsView`), settings UI, `Localizable.xcstrings`, and App Group
  (`group.im.zzn.apps.threelinecal`) plumbing; `SharedWidget/` adds the common
  `TimelineProvider` + widget views

Data flow: each app reads events with EventKit and writes a small snapshot to its App
Group. The watch complication renders the snapshot; the iOS/macOS widgets read EventKit
directly at every timeline reload and fall back to the snapshot.

## Build & run

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonik/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open ThreeLineCal.xcodeproj
```

Pick the **ThreeLineCal** scheme and run on a paired iPhone + Apple Watch (or the simulators).
On device: add your calendar in iPhone **Settings → Calendar → Accounts**, open the watch app,
grant calendar access, then add the **Next 3 Events** complication to a rectangular slot on your face.

### Regenerate App Store screenshots & metadata

```bash
scripts/make_screenshots.sh        # builds, runs simulators + the Mac app, saves PNGs to screenshots/
scripts/upload_screenshots.py      # uploads them via the App Store Connect API (needs .creds/)
scripts/upload_metadata.py         # uploads metadata/<locale>/ (21 localized store listings)
```

Localized store listings live in `metadata/<asc-locale>/{description,keywords,subtitle,whats_new}.txt`.

## License

[Apache License 2.0](LICENSE) © 2026 Z. Victor Zhou.
