# App Store Marketing Screenshots — Style & Spec

Design + dimension spec for generating App Store marketing screenshots with
**ChatGPT Image 2 (`gpt-image-2`)**. Every release we re-run the saved prompts
(in `marketing/prompts/`) against the current real screenshots. No homography /
re-stamp automation — regeneration is intentional and cheap.

Source of truth for dimensions: Apple, *Screenshot specifications*
<https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/>
(verified 2026-07).

---

## 1. Required dimensions (2025 simplified requirement)

Apple now requires **only the largest device per platform**; smaller sizes are
auto-scaled down. So we generate exactly one canvas per platform.

| Platform            | Mandatory | Portrait (px)   | Landscape (px)  | Notes |
|---------------------|-----------|-----------------|-----------------|-------|
| **iPhone 6.9″**     | ✅        | **1320 × 2868** | 2868 × 1320     | iPhone 17 Pro Max. Covers 6.5″/6.7″ by scaling. |
| **iPad 13″**        | ✅        | **2064 × 2752** | 2752 × 2064     | iPad Pro M4 13″. Older 12.9″ = 2048 × 2732. |
| **Mac**             | ✅        | —               | **2560 × 1600** | 16:10. Other legal: 1280×800 / 1440×900 / 2880×1800. |
| **Apple Watch Ultra 3** | ✅    | **422 × 514**   | —               | Must use ONE watch size across all localizations. |

- Format: `.png` / `.jpg` / `.jpeg`. 1–10 screenshots per platform per locale.
- Portrait for iPhone/iPad/Watch; landscape for Mac.

### ⚠️ Repo mismatch to fix
`scripts/upload_screenshots.py` maps `watch-app.png` → `APP_WATCH_ULTRA`
(410 × 502, = Ultra/Ultra 2). But our real captures are **422 × 514 (Ultra 3)**.
Pick one and align the upload target displayType with the actual pixel size,
otherwise ASC rejects the upload.

---

## 2. gpt-image-2 → App Store canvas fitting

`gpt-image-2` outputs only three aspect ratios (verify each session — vendors
change these):

| gpt-image-2 size | Ratio | Best for |
|------------------|-------|----------|
| `1024 x 1536`    | 2:3 (0.667) | iPhone, iPad (portrait) |
| `1536 x 1024`    | 3:2 (1.5)   | Mac (landscape) |
| `1024 x 1024`    | 1:1         | Watch |

None match the store exactly. **Two-step pipeline:**

1. **Generate** the hero art at the nearest gpt size.
2. **Place** it on the exact store canvas over a **flat/gradient background that
   extends seamlessly** — the extra room becomes the headline zone.

| Target        | Store ratio | Gap vs gpt | Extend |
|---------------|-------------|------------|--------|
| iPhone 1320×2868 | 1 : 2.17 | very tall | big top/bottom margin → headline lives here |
| iPad 2064×2752   | 1 : 1.33 | taller    | small top/bottom |
| Mac 2560×1600    | 1.6 : 1  | wider     | small left/right |
| Watch 422×514    | 1 : 1.22 | ~square   | crop/pad, ~no text room |

→ **This is the #1 reason the background must be a solid color or soft gradient,
not a photo.** It also keeps 21-locale regeneration trivial.

---

## 3. Visual style: "Editorial minimal" (Apple-native look)

Target the calm, high-contrast look Apple uses for its own apps (Fitness,
Journal) and best-in-class calendar apps (Fantastical, Things).

**Layout archetype — "framed device":**
```
┌────────────────────┐
│                    │  ← flat bg / soft gradient
│   Short headline    │  ≤ 5 words, 1 line, huge weight, top ~25%
│                    │
│   ┌──────────┐     │
│   │ REAL app  │     │  ← device with the ACTUAL screenshot on screen,
│   │ screenshot│     │     floating, soft drop shadow, head-on (no tilt)
│   └──────────┘     │
│                    │
└────────────────────┘
```

**Rules**
- **Background**: one brand color OR a 2-stop vertical gradient. Never a busy
  photo (breaks canvas extension + fights the screenshot).
- **Device**: head-on, centered, subtle shadow. No 3/4 tilt — flat keeps the
  screen legible and avoids the perspective problem we deliberately dropped.
- **Screen content**: the real current screenshot, crisp and readable. It is the
  hero — everything else is quiet.
- **Typography**: one headline per tile. SF Pro / system-like, very bold, high
  contrast. Front-load the value word.
- **Palette** (grounded in the product): dark charcoal/near-black background,
  **orange accent `#FF9500`** (the watch-face accent), white text. One accent
  only. A light variant (warm off-white bg, near-black text, orange accent) is
  fine — pick one and keep the whole set consistent.
- **Consistency**: same background family + same headline position across all
  tiles → cohesive "shelf" in the store.

**Anti-patterns**: photographic lifestyle scenes, multiple accent colors,
paragraphs of text, tilted/rotated devices, drop-shadow overkill, emoji.

---

## 4. i18n strategy (21 locales) — the key decision

Headlines are the expensive part at 21 locales. Three options:

| Option | How | i18n safety | Cost |
|--------|-----|-------------|------|
| **A. AI renders text** | gpt-image-2 draws the headline (its strength) | ⚠️ risky for Arabic / Hindi / Thai / CJK — model mangles complex scripts | 1 gen per tile per locale |
| **B. Text-free AI + code overlay** ⭐ | AI makes a **text-free** bg+device; a tiny script overlays the localized headline in the right font/direction | ✅ pixel-perfect, RTL-correct | 1 gen per tile (locale-independent) + cheap text pass |
| **C. No in-image text** | device + bg only; App Store's localized subtitle/description carries the words | ✅ safest, most minimal | cheapest |

**Recommendation:** **B for the scale-out.** Generate the AI art *text-free and
locale-independent* (background + device + screenshot), then overlay the
localized headline as a separate deterministic text layer. This is NOT the
homography system we dropped — it's just drawing text on a flat area, which is
reliable and free. Use **A only for the English/Latin hero tile** if you want to
show off gpt-image-2's typography. **C is the acceptable minimum** for v1.

**Text-layer rules when using B/C:**
- Reserve ≥ 35 % horizontal headroom — German/Finnish run long.
- **RTL** (ar, he, fa, ur): mirror layout, right-align, RTL-shaped font.
- **CJK** (zh-Hans, zh-Hant, ja, ko): larger line-height, no hyphenation, bold-capable CJK face.
- Keep the *English* source headline ≤ 5 words so translations stay short.

---

## 5. Per-tile content plan (iPhone/iPad/Mac set)

4–6 tiles, first tile is the strongest. Headlines are the English source; localize per §4.

| # | Screenshot shown | Headline (EN source, ≤5 words) |
|---|------------------|-------------------------------|
| 1 | Watch complication — 3 lines on the face | "Your next 3 events." |
| 2 | Watch app / list | "A glance is all it takes." |
| 3 | iPhone widget on home screen | "Widgets on every screen." |
| 4 | iPad / Mac widget | "Watch, iPhone, iPad, Mac." |
| 5 | (optional) empty/private state | "Private. Reads on-device." |

Watch tiles (422×514): near-zero text room → **tile-only or one tiny word**;
let the store caption carry meaning.

---

## 6. Reusable prompt scaffold

Saved, tuned prompts live in `marketing/prompts/<platform>-<tile>.txt`. Template:

```
A single App Store marketing screenshot, editorial-minimal style.
Background: solid deep charcoal (#111114) with a very subtle darker vignette.
Centered: a {DEVICE} shown head-on (no tilt, no perspective), floating with a
soft realistic drop shadow, screen fully visible and unobstructed.
On the screen, reproduce EXACTLY the provided app screenshot, crisp and legible.
No added text, no logos, no UI chrome, no reflections over the screen.
Calm, premium, lots of negative space. Accent color orange #FF9500 used sparingly.
Output {GPT_SIZE}.
```
- `{DEVICE}` = "Apple Watch Ultra" / "iPhone 17 Pro" / "iPad Pro" / "MacBook".
- `{GPT_SIZE}` = 1024x1536 (iPhone/iPad) · 1536x1024 (Mac) · 1024x1024 (Watch).
- Feed the real screenshot via the **`images.edit`** endpoint so the model has
  the actual pixels to reproduce. Keep the prompt **text-free** (§4 option B).
- After generating, `Read` the PNG (vision) to confirm it matches before saving.

---

## 7. Pipeline (kept deliberately simple)

```
scripts/make_screenshots.sh        # real device screenshots (already exists)
        │
        ▼
gpt-image-2 images.edit  ← marketing/prompts/*.txt   (regenerate every release)
        │
        ▼
place on exact store canvas + (optional) localized headline overlay
        │
        ▼
scripts/upload_screenshots.py      # already exists; fix Watch displayType (§1)
```

Requires `OPENAI_API_KEY` (see `xinbenlv-image-gen-skill`). Gemini
`gemini-3-pro-image` is a cheaper draft alternative but weaker at in-image text.
