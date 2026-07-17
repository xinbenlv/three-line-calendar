import SwiftUI

/// Single-line text that scrolls horizontally (news-ticker style) when it
/// overflows its slot, and renders as a plain truncating `Text` when it fits.
/// Inherits the environment font like `Text`. App processes only — WidgetKit
/// surfaces are static snapshots, so widgets keep the plain "…" truncation.
struct MarqueeText: View {
    var text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var slotWidth: CGFloat = 0
    @State private var phase: CGFloat = 0   // 0 → 1 over one full pass

    private let gap: CGFloat = 32           // space between the looping copies
    private let pointsPerSecond: CGFloat = 30
    private let pauseSeconds: TimeInterval = 1.5

    private var scrolls: Bool { !reduceMotion && textWidth > slotWidth + 1 }

    var body: some View {
        // The plain text stakes out the row's layout (and shows when it fits);
        // the moving copies live in an overlay so scrolling never resizes rows.
        Text(text)
            .lineLimit(1)
            .truncationMode(.tail)
            .opacity(scrolls ? 0 : 1)
            .overlay(alignment: .leading) {
                if scrolls {
                    HStack(spacing: gap) {
                        Text(text).fixedSize()
                        Text(text).fixedSize()
                    }
                    .offset(x: -phase * (textWidth + gap))
                }
            }
            .background(
                // Invisible untruncated copy measuring the text's natural width.
                Text(text).fixedSize().hidden()
                    .background(GeometryReader { g in
                        Color.clear
                            .onAppear { textWidth = g.size.width }
                            .onChange(of: g.size.width) { _, w in textWidth = w }
                    })
            )
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { slotWidth = g.size.width }
                    .onChange(of: g.size.width) { _, w in slotWidth = w }
            })
            .clipped()
            .mask { fadeMask }
            .task(id: "\(scrolls)-\(textWidth)") { await animate() }
    }

    // Soft trailing fade while scrolling. No leading fade: during the pause the
    // text sits flush left and a fade there would eat the first characters.
    @ViewBuilder
    private var fadeMask: some View {
        if scrolls {
            HStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 8)
            }
        } else {
            Color.black
        }
    }

    private func animate() async {
        phase = 0
        guard scrolls else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(pauseSeconds))
            guard !Task.isCancelled else { return }
            let duration = TimeInterval((textWidth + gap) / pointsPerSecond)
            withAnimation(.linear(duration: duration)) { phase = 1 }
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            // At phase 1 the second copy sits exactly where the first started,
            // so snapping back without animation is a seamless loop.
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { phase = 0 }
        }
    }
}
