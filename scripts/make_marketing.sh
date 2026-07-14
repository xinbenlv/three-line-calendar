#!/usr/bin/env bash
# Generate App Store marketing images with gpt-image-2 (ChatGPT Image 2) from the
# real device screenshots, at (near-)exact store dimensions, then resize to the
# exact required pixels. Re-run every release — the tuned prompts live in
# marketing/prompts/. Output: marketing/store/<device>.png
#
# gpt-image-2 accepts custom sizes: width & height each divisible by 16, longest
# edge <= 3840, aspect <= 3:1, ~8.3M pixel budget. So iPad/Mac hit the store size
# exactly; iPhone/Watch generate at the nearest divisible size and resize <1%.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT/.env.local" ] && { set -a; . "$ROOT/.env.local"; set +a; }
: "${OPENAI_API_KEY:?set OPENAI_API_KEY (e.g. in .env.local)}"
OUT="$ROOT/marketing/store"; mkdir -p "$OUT"
Q="${MARKETING_QUALITY:-high}"

# dev | input screenshot | prompt file | gen size (÷16) | final store W H
gen() {
  local dev="$1" in="$2" prompt_file="$3" gensize="$4" fw="$5" fh="$6"
  local prompt raw out
  prompt="$(cat "$ROOT/marketing/prompts/$prompt_file")"
  raw="$(mktemp).json"; out="$OUT/$dev.png"
  echo "[$dev] generating $gensize (quality=$Q)..."
  curl -s https://api.openai.com/v1/images/edits \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -F model=gpt-image-2 -F image=@"$in" -F "prompt=$prompt" \
    -F size="$gensize" -F quality="$Q" -o "$raw"
  if ! jq -e '.data[0].b64_json' "$raw" >/dev/null 2>&1; then
    echo "[$dev] ERROR: $(jq -r '.error.message // "unknown"' "$raw")"; rm -f "$raw"; return 1
  fi
  jq -r '.data[0].b64_json' "$raw" | base64 -D > "$out"; rm -f "$raw"
  # Store aspect ≈ gen aspect, so this is a sub-1% scale — no visible distortion.
  [ "$(sips -g pixelWidth "$out" | awk '/pixelWidth/{print $2}')" = "$fw" ] \
    && [ "$(sips -g pixelHeight "$out" | awk '/pixelHeight/{print $2}')" = "$fh" ] \
    || sips -z "$fh" "$fw" "$out" >/dev/null
  echo "[$dev] -> $out ($(sips -g pixelWidth -g pixelHeight "$out" \
    | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w"x"h}'))"
}

gen iphone "$ROOT/screenshots/iphone-companion.png" iphone-hero.txt 1328x2880 1320 2868 &
gen ipad   "$ROOT/screenshots/ipad-companion.png"   ipad-hero.txt   2064x2752 2064 2752 &
gen watch  "$ROOT/screenshots/watch-face-ultra.png" watch-hero.txt  832x1024  422  514  &
gen mac    "$ROOT/screenshots/mac-app.png"          mac-hero.txt    2560x1600 2560 1600 &
wait

echo "=== marketing/store ==="
ls -la "$OUT"/*.png 2>/dev/null || true
