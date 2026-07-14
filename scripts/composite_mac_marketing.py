#!/usr/bin/env python3
"""Composite the FAITHFUL Mac app window (real screencapture) onto an AI-generated
iMac frame, producing the App Store Mac marketing image.

Faithfulness contract: the app window is real pixels (never AI-repainted). Only the
iMac + desk + wallpaper are the marketing frame. The frame's screen is generated as
flat magenta (#FF00FF) so we can detect the exact screen shape (rounded corners and
all) by colour-keying, then paint our own screen content into it.

    python3 scripts/composite_mac_marketing.py \
        --frame  marketing/frames/imac-magenta.png \
        --window screenshots/mac-app-dark.png \
        --out    marketing/store/mac.png

Pure Pillow — no numpy.
"""
import argparse
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps


def magenta_mask(frame: Image.Image) -> Image.Image:
    """L-mode mask (255 where the flat-magenta screen is), via channel thresholds."""
    r, g, b = frame.convert("RGB").split()
    rm = r.point(lambda v: 255 if v > 170 else 0)
    gm = g.point(lambda v: 255 if v < 100 else 0)
    bm = b.point(lambda v: 255 if v > 170 else 0)
    mask = ImageChops.multiply(ImageChops.multiply(rm, gm), bm)  # logical AND
    if mask.getbbox() is None:
        raise SystemExit("No magenta screen found in the frame — regenerate it flatter.")
    return mask


def cutout_green(img: Image.Image) -> Image.Image:
    """Key out a flat green (#00FF00) background → transparent RGBA (device only)."""
    r, g, b = img.convert("RGB").split()
    green = ImageChops.multiply(ImageChops.multiply(
        g.point(lambda v: 255 if v > 150 else 0),
        r.point(lambda v: 255 if v < 130 else 0)),
        b.point(lambda v: 255 if v < 130 else 0))
    keep = ImageChops.invert(green).filter(ImageFilter.MinFilter(3))  # erode to kill fringe
    out = img.convert("RGBA")
    out.putalpha(keep)
    return out


def gradient(w: int, h: int, top=(38, 42, 74), bot=(18, 20, 38)) -> Image.Image:
    """A calm macOS-style vertical wallpaper gradient."""
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        col.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return col.resize((w, h))


def round_corners(img: Image.Image, radius: int) -> Image.Image:
    """Apply rounded corners (macOS-widget style) to an RGBA image."""
    img = img.convert("RGBA")
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width, img.height], radius=radius, fill=255)
    out = img.copy()
    out.putalpha(mask)
    return out


def rounded_shadow(size, radius, blur, spread, color=(0, 0, 0, 150)):
    w, h = size
    pad = blur * 3 + spread
    canvas = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(canvas).rounded_rectangle(
        [pad - spread, pad - spread, pad + w + spread, pad + h + spread],
        radius=radius + spread, fill=color)
    return canvas.filter(ImageFilter.GaussianBlur(blur)), pad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frame", required=True)
    ap.add_argument("--window", help="real app window capture (rounded already)")
    ap.add_argument("--widget", help="real widget render (gets rounded corners)")
    ap.add_argument("--screenshot", help="real full-screen screenshot; fills the device screen")
    ap.add_argument("--cutout", action="store_true",
                    help="with --screenshot: key out a green background → transparent device PNG")
    ap.add_argument("--out", required=True)
    ap.add_argument("--out-size", default="2560x1600", help="final store size, WxH")
    ap.add_argument("--wallpaper", help="optional wallpaper image; default = gradient")
    ap.add_argument("--height-frac", type=float,
                    help="content height as a fraction of the screen height "
                         "(default 0.78 for --window, 0.5 for --widget)")
    args = ap.parse_args()
    if not (args.window or args.widget or args.screenshot):
        raise SystemExit("pass --window, --widget, or --screenshot")
    ow, oh = (int(v) for v in args.out_size.lower().split("x"))

    frame = Image.open(args.frame).convert("RGB")
    # Dilate the mask a few px so screen content buries the anti-aliased magenta
    # fringe at the screen/bezel boundary (otherwise a thin pink line remains).
    mask = magenta_mask(frame).filter(ImageFilter.MaxFilter(9))
    x0, y0, x1, y1 = mask.getbbox()
    sw, sh = x1 - x0, y1 - y0

    # --- fill-screen mode (iPhone/iPad/Watch): the REAL screenshot fills the
    # device screen, masked to its exact rounded shape. Pure real pixels. ---
    if args.screenshot:
        # Stretch to the exact screen box: fills with no crop (the real screenshot
        # is edge-to-edge screen content). Distortion = the frame-vs-device aspect
        # gap, which should be tiny if the frame's screen matches the device.
        shot = Image.open(args.screenshot).convert("RGB").resize((sw, sh), Image.LANCZOS)
        placed = Image.new("RGBA", frame.size, (0, 0, 0, 0))
        placed.paste(shot, (x0, y0))
        result = Image.composite(placed, frame.convert("RGBA"), mask)
        if args.cutout:
            result = cutout_green(result)                 # device on transparent, native size
        else:
            result = result.convert("RGB")
            if result.size != (ow, oh):
                result = result.resize((ow, oh), Image.LANCZOS)
        result.save(args.out)
        print(f"wrote {args.out} ({result.width}x{result.height}); screen bbox "
              f"= ({x0},{y0})-({x1},{y1}) {sw}x{sh}")
        return

    # --- build the deterministic screen content (our desktop) ---
    if args.wallpaper:
        # cover-crop (no stretch) to the screen aspect
        screen = ImageOps.fit(Image.open(args.wallpaper).convert("RGB"), (sw, sh), Image.LANCZOS)
    else:
        screen = gradient(sw, sh)
    screen = screen.convert("RGBA")

    if args.widget:
        # Real widget CONTENT (transparent, padded) over a frosted-material card
        # built from the wallpaper itself — the authentic macOS desktop-widget look
        # (content over frosted wallpaper), exactly what WidgetKit would draw.
        content = Image.open(args.widget).convert("RGBA")
        frac = args.height_frac if args.height_frac else 0.5
        scale = (sh * frac) / content.height
        cw, ch = max(1, round(content.width * scale)), max(1, round(content.height * scale))
        content = content.resize((cw, ch), Image.LANCZOS)
        radius = int(min(cw, ch) * 0.16)
        cx, cy = (sw - cw) // 2, int((sh - ch) * 0.42)

        material = screen.crop((cx, cy, cx + cw, cy + ch)).convert("RGBA")
        material = material.filter(ImageFilter.GaussianBlur(20))
        material = Image.alpha_composite(material, Image.new("RGBA", (cw, ch), (12, 14, 22, 125)))
        material = round_corners(material, radius)

        shadow, pad = rounded_shadow((cw, ch), radius=radius, blur=38, spread=4)
        screen.alpha_composite(shadow, (cx - pad, cy - pad + 12))
        screen.alpha_composite(material, (cx, cy))
        screen.alpha_composite(content, (cx, cy))
    else:
        content = Image.open(args.window).convert("RGBA")   # already rounded by macOS
        frac = args.height_frac if args.height_frac else 0.78
        scale = (sh * frac) / content.height
        content = content.resize((max(1, round(content.width * scale)),
                                  max(1, round(content.height * scale))), Image.LANCZOS)
        cx, cy = (sw - content.width) // 2, int((sh - content.height) * 0.42)
        shadow, pad = rounded_shadow(content.size, radius=18, blur=34, spread=6)
        screen.alpha_composite(shadow, (cx - pad, cy - pad + 10))
        screen.alpha_composite(content, (cx, cy))

    # --- paint the screen content into the exact magenta shape (keeps rounded corners) ---
    placed = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    placed.paste(screen, (x0, y0))
    result = Image.composite(placed, frame.convert("RGBA"), mask).convert("RGB")

    if result.size != (ow, oh):
        result = result.resize((ow, oh), Image.LANCZOS)
    result.save(args.out)
    print(f"wrote {args.out} ({result.width}x{result.height}); screen bbox "
          f"= ({x0},{y0})-({x1},{y1}) {sw}x{sh}")


if __name__ == "__main__":
    main()
