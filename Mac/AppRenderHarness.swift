#if DEBUG && os(macOS)
import SwiftUI

/// Headless App Store screenshot harness (Debug only, never ships): renders the
/// Mac app's main window *content* to a PNG using SwiftUI's `ImageRenderer` —
/// no Screen Recording permission, no real calendar, no on-screen window needed.
/// Triggered by the `-RenderApp [absolute-output-path]` launch argument; without
/// a path the PNG lands in Documents/app-renders/mac-<language>.png.
/// Mirrors `WidgetRenderHarness`. Driven by scripts/render_app_screenshots.sh.
@MainActor
enum AppRenderHarness {
    @discardableResult
    static func runIfRequested() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-RenderApp") else { return false }
        let explicit = (idx + 1 < args.count && args[idx + 1].hasPrefix("/")) ? args[idx + 1] : nil
        render(to: explicit)
        return true
    }

    private static func render(to explicitPath: String?) {
        let now = Date()
        let lang = Locale.preferredLanguages.first ?? "en"
        let url: URL
        if let explicitPath {
            url = URL(fileURLWithPath: explicitPath)
        } else {
            url = URL.documentsDirectory.appending(path: "app-renders/mac-\(lang).png")
        }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let renderer = ImageRenderer(content: MacScreenshotView(now: now))
        renderer.scale = 3
        if let img = renderer.nsImage,
           let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
            print("AppRenderHarness: wrote \(url.path)")
        } else {
            print("AppRenderHarness: render failed")
        }
    }
}

/// Deterministic, self-contained render of the Mac window content for the store
/// screenshot: the same 3-line preview the app shows (`MacRootView.previewCard`),
/// plus a representative "Show calendars" list — all from demo data, so it renders
/// synchronously without EventKit or the async `.task` load.
private struct MacScreenshotView: View {
    let now: Date

    var body: some View {
        VStack(spacing: 16) {
            // Mirrors MacRootView.previewCard exactly.
            EventRowsView(events: Array(EventItem.demo(from: now).prefix(5)),
                          nextEventStart: nil, hasData: true, style: .appPreview)
                .padding(20)
                .frame(minHeight: 160)
                .background(.quaternary.opacity(0.5),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Representative calendar list (illustrative demo data — the real
            // SettingsView reads EventKit, which is empty in a headless render).
            // NOTE: draw the "on" switch with pure SwiftUI shapes — Toggle(.switch)
            // is an AppKit control that ImageRenderer cannot rasterize offscreen.
            VStack(alignment: .leading, spacing: 14) {
                Text("Show calendars")
                    .font(.headline)
                ForEach([("Work", Color.blue), ("Personal", Color.orange),
                         ("Family", Color.green)], id: \.0) { name, dot in
                    HStack(spacing: 10) {
                        Circle().fill(dot).frame(width: 10, height: 10)
                        Text(name)
                        Spacer()
                        Capsule().fill(Color.green)
                            .frame(width: 38, height: 22)
                            .overlay(alignment: .trailing) {
                                Circle().fill(.white).frame(width: 18, height: 18).padding(2)
                            }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 420, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.colorScheme, .light)
    }
}
#endif
