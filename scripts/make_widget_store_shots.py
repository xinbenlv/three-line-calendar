#!/usr/bin/env python3
"""Produce faithful, store-dimension 'widget on device' App Store screenshots for
iPhone and iPad, leading the store gallery with the app's core feature (the widget).

Faithfulness contract (see docs: screenshots-must-be-faithful): the pixels INSIDE the
screen are always the real app — a real Home Screen capture (iPhone) or a real widget
render composited on a green-screen device (iPad). We only ever add/scale the marketing
frame + background, never repaint the screen.

Outputs (exact App Store slot dimensions):
    marketing/store/iphone-widget.png       1320x2868   (real Home Screen, light)
    marketing/store/iphone-widget-dark.png  1320x2868   (real Home Screen, dark)
    marketing/store/ipad-widget.png         2064x2752   (real widget on framed iPad)

Pure Pillow.
"""
import os
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(ROOT, "marketing", "store")


def gradient(w, h, top, bot):
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        col.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return col.resize((w, h))


def cutout_green(img):
    """Key out a flat green (#00FF00) background -> transparent RGBA (device only)."""
    r, g, b = img.convert("RGB").split()
    green = ImageChops.multiply(ImageChops.multiply(
        g.point(lambda v: 255 if v > 150 else 0),
        r.point(lambda v: 255 if v < 130 else 0)),
        b.point(lambda v: 255 if v < 130 else 0))
    keep = ImageChops.invert(green).filter(ImageFilter.MinFilter(3))  # erode to kill fringe
    out = img.convert("RGBA")
    out.putalpha(keep)
    return out


def rounded_shadow(size, radius, blur, spread, color=(0, 0, 0, 120)):
    w, h = size
    pad = blur * 3 + spread
    canvas = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(canvas).rounded_rectangle(
        [pad - spread, pad - spread, pad + w + spread, pad + h + spread],
        radius=radius + spread, fill=color)
    return canvas.filter(ImageFilter.GaussianBlur(blur)), pad


def iphone_fullbleed(src, out, size=(1320, 2868)):
    """A real full-screen Home Screen capture, resized to the exact slot. No frame:
    full-bleed is the most legible option on the install sheet."""
    img = Image.open(src).convert("RGB")
    img.resize(size, Image.LANCZOS).save(out)
    print(f"wrote {out} ({size[0]}x{size[1]}) from {os.path.basename(src)} {img.size}")


def ipad_framed(src, out, size=(2064, 2752),
                top=(238, 241, 246), bot=(214, 222, 234), height_frac=0.94):
    """Green-keyed iPad (real widget on screen) centered on a clean gradient canvas."""
    ow, oh = size
    device = cutout_green(Image.open(src))
    device = device.crop(device.getbbox())
    scale = (oh * height_frac) / device.height
    dw, dh = max(1, round(device.width * scale)), max(1, round(device.height * scale))
    if dw > ow * 0.98:  # don't let width overflow
        scale = (ow * 0.98) / device.width
        dw, dh = round(device.width * scale), round(device.height * scale)
    device = device.resize((dw, dh), Image.LANCZOS)

    canvas = gradient(ow, oh, top, bot).convert("RGBA")
    x, y = (ow - dw) // 2, (oh - dh) // 2
    shadow, pad = rounded_shadow((dw, dh), radius=int(min(dw, dh) * 0.06), blur=44, spread=6)
    canvas.alpha_composite(shadow, (x - pad, y - pad + 18))
    canvas.alpha_composite(device, (x, y))
    canvas.convert("RGB").save(out)
    print(f"wrote {out} ({ow}x{oh}); device {dw}x{dh} on gradient")


def main():
    iphone_fullbleed(os.path.join(ROOT, "screenshots", "widgets", "ios-homescreen.png"),
                     os.path.join(STORE, "iphone-widget.png"))
    iphone_fullbleed(os.path.join(ROOT, "screenshots", "widgets", "ios-homescreen-dark.png"),
                     os.path.join(STORE, "iphone-widget-dark.png"))
    ipad_framed(os.path.join(ROOT, "marketing", "frames", "wdev-ipad.png"),
                os.path.join(STORE, "ipad-widget.png"))


if __name__ == "__main__":
    main()
