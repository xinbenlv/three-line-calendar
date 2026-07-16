import SwiftUI
import WidgetKit

/// The "coffee break" empty-state cup: a steaming cup drawn as vector line art
/// so it stays crisp from complication size up to the Mac widget, and — being
/// stroked in `.primary`/`.secondary` — renders correctly in the watch face's
/// accented and the lock screen's vibrant modes. Decorative only: no strings,
/// hidden from VoiceOver. Face and third steam swirl appear only at `size >= 40`.
struct EmptyStateIllustration: View {
    var size: CGFloat

    private var showsDetail: Bool { size >= 40 }
    // Scale the stroke with the drawing, but never let it go hairline-thin.
    private var line: CGFloat { max(1.4, size * 0.05) }

    var body: some View {
        ZStack {
            SteamShape(swirls: showsDetail ? 3 : 2)
                .stroke(.secondary, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .widgetAccentable()
            CupShape()
                .stroke(.primary, style: StrokeStyle(lineWidth: line,
                                                     lineCap: .round, lineJoin: .round))
            if showsDetail {
                EyesShape().fill(.primary)
                SmileShape()
                    .stroke(.primary, style: StrokeStyle(lineWidth: line * 0.8, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// All shapes share one 0–1 design space so they compose in a plain ZStack.
private func pt(_ rect: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
}

/// Rising steam: gentle S-curves above the cup, the middle one taller.
private struct SteamShape: Shape {
    var swirls: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let xs: [CGFloat] = swirls >= 3 ? [0.32, 0.46, 0.60] : [0.38, 0.54]
        for (i, x) in xs.enumerated() {
            let tall = xs.count == 3 ? i == 1 : false
            let top = tall ? 0.04 : 0.12
            let bottom = 0.34
            let mid = (top + bottom) / 2
            p.move(to: pt(rect, x, bottom))
            p.addCurve(to: pt(rect, x, top),
                       control1: pt(rect, x - 0.07, bottom - (bottom - mid) / 2),
                       control2: pt(rect, x + 0.07, top + (mid - top) / 2))
        }
        return p
    }
}

/// Cup body, handle, and saucer as one stroked outline.
private struct CupShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Body — rounder at the bottom, like a mug seen straight on.
        p.addRoundedRect(in: CGRect(x: rect.minX + 0.24 * rect.width,
                                    y: rect.minY + 0.42 * rect.height,
                                    width: 0.44 * rect.width,
                                    height: 0.38 * rect.height),
                         cornerSize: CGSize(width: 0.09 * rect.width,
                                            height: 0.09 * rect.height))
        // Handle — an open arc off the right wall.
        p.move(to: pt(rect, 0.68, 0.50))
        p.addArc(center: pt(rect, 0.68, 0.605),
                 radius: 0.105 * rect.width,
                 startAngle: .degrees(-88), endAngle: .degrees(88),
                 clockwise: false)
        // Saucer — a wide round-capped line under the cup.
        p.move(to: pt(rect, 0.18, 0.90))
        p.addLine(to: pt(rect, 0.74, 0.90))
        return p
    }
}

private struct EyesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = 0.028 * rect.width
        for x in [0.38, 0.54] {
            let c = pt(rect, x, 0.555)
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        }
        return p
    }
}

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: pt(rect, 0.46, 0.585),
                 radius: 0.065 * rect.width,
                 startAngle: .degrees(30), endAngle: .degrees(150),
                 clockwise: false)
        return p
    }
}
