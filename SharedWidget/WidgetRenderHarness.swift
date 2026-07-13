#if DEBUG && !os(watchOS)
import SwiftUI
import WidgetKit

/// Headless screenshot harness (Debug only, never ships): renders every widget
/// family to PNGs without touching the home screen. Triggered by the
/// `-RenderWidgets [absolute-output-dir]` launch argument; without a path the
/// PNGs land in Documents/widget-renders/<language>/.
/// Driven by scripts/render_widget_screenshots.sh.
@MainActor
enum WidgetRenderHarness {
    @discardableResult
    static func runIfRequested() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-RenderWidgets") else { return false }
        let explicit = (idx + 1 < args.count && args[idx + 1].hasPrefix("/"))
            ? URL(fileURLWithPath: args[idx + 1]) : nil
        render(into: explicit)
        return true
    }

    // Representative point sizes per family (exact sizes vary slightly by device).
    private static var families: [(WidgetFamily, CGSize, String)] {
        #if os(macOS)
        [(.systemSmall, CGSize(width: 170, height: 170), "systemSmall"),
         (.systemMedium, CGSize(width: 364, height: 170), "systemMedium"),
         (.systemLarge, CGSize(width: 364, height: 382), "systemLarge")]
        #else
        [(.systemSmall, CGSize(width: 170, height: 170), "systemSmall"),
         (.systemMedium, CGSize(width: 364, height: 170), "systemMedium"),
         (.accessoryRectangular, CGSize(width: 172, height: 76), "accessoryRectangular"),
         (.accessoryInline, CGSize(width: 234, height: 26), "accessoryInline")]
        #endif
    }

    private static func render(into explicit: URL?) {
        let now = Date()
        let lang = Locale.preferredLanguages.first ?? "en"
        let base = explicit ?? URL.documentsDirectory.appending(path: "widget-renders")
        let dir = base.appending(path: lang)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let withEvents = EventEntry(date: now,
                                    events: Array(EventItem.demo(from: now).prefix(3)),
                                    nextEventStart: nil, hasData: true)
        let empty = EventEntry(date: now, events: [],
                               nextEventStart: now.addingTimeInterval(9_000), hasData: true)

        for (family, size, name) in families {
            for (entry, state) in [(withEvents, "events"), (empty, "empty")] {
                let view = SystemWidgetView(entry: entry, familyOverride: family)
                    .frame(width: size.width, height: size.height)
                    .background(Color(white: 0.98))   // containerBackground is a no-op outside WidgetKit
                    .environment(\.colorScheme, .light)
                write(view, to: dir.appending(path: "\(name)-\(state).png"))
            }
        }
        print("WidgetRenderHarness: wrote \(families.count * 2) PNGs -> \(dir.path)")
    }

    private static func write(_ view: some View, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        #if os(macOS)
        if let img = renderer.nsImage,
           let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        }
        #else
        if let png = renderer.uiImage?.pngData() {
            try? png.write(to: url)
        }
        #endif
    }
}
#endif
