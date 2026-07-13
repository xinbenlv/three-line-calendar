#!/usr/bin/env python3
"""Render a marketing 'hero' screenshot: the 3-line complication on a modular Apple Watch
Ultra face. Output: screenshots/watch-complication-hero.png (410x502, APP_WATCH_ULTRA).

Placing a real complication on a face can't be scripted via simctl, so this composites a
representative face. Swap it for a real device capture (side button + Digital Crown) any time.
"""
import math
from PIL import Image, ImageDraw, ImageFont

W, H = 820, 1004  # 2x of 410x502 for crispness


def font(sz):
    for p in ("/System/Library/Fonts/SFNSRounded.ttf", "/System/Library/Fonts/SFNS.ttf",
              "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(p, sz)
        except Exception:
            continue
    return ImageFont.load_default()


def main():
    img = Image.new("RGB", (W, H), (0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = W / 2, H / 2

    # Ultra-style tick ring
    for i in range(60):
        a = math.radians(i * 6 - 90)
        r1, r2 = 470, (486 if i % 5 else 496)
        col = (255, 149, 0) if i % 15 == 0 else (70, 55, 25)
        d.line([(cx + r1 * math.cos(a), cy + r1 * math.sin(a)),
                (cx + r2 * math.cos(a), cy + r2 * math.sin(a))], fill=col, width=3)

    d.text((70, 70), "10:09", font=font(120), fill=(255, 255, 255))
    d.text((74, 205), "TUE 12 JUL", font=font(34), fill=(255, 149, 0))

    d.rounded_rectangle((66, 360, 754, 610), radius=34, outline=(72, 72, 80), width=3)
    rows = [("10:00", "Standup"), ("11:30", "1:1 with Sam"),
            ("14:00", "Design review with the plat…")]
    y = 388
    for t, title in rows:
        d.text((100, y), t, font=font(42), fill=(150, 150, 160))
        d.text((235, y), title, font=font(42), fill=(240, 240, 245))
        y += 74

    for x0 in (170, 410, 650):
        d.ellipse((x0 - 70, 700, x0 + 70, 840), outline=(60, 60, 66), width=3)
    d.text((150, 762), "68°", font=font(38), fill=(120, 120, 130))
    d.text((372, 762), "7,842", font=font(30), fill=(120, 120, 130))
    d.text((612, 760), "◷", font=font(46), fill=(120, 120, 130))

    img.resize((410, 502), Image.LANCZOS).save("screenshots/watch-complication-hero.png")
    print("saved screenshots/watch-complication-hero.png")


if __name__ == "__main__":
    main()
