#!/usr/bin/env bash
# Headless macOS app screenshot — renders the Mac app's main window CONTENT to a
# PNG via the DEBUG `-RenderApp` harness (SwiftUI ImageRenderer). No Screen
# Recording permission, no simulator, no real calendar, no visible window.
# This is the permission-free, CI-friendly replacement for the `screencapture`
# window grab in make_screenshots.sh.
#
# Output: screenshots/mac-app.png            (en)
#         screenshots/mac-app-<locale>.png   (other locales)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/screenshots"; mkdir -p "$OUT"
PROJ="$ROOT/ThreeLineCal.xcodeproj"
read -ra LOCALES <<< "${APP_LOCALES:-en}"

echo "[1/3] Generating project + building ThreeLineCalMac..."
command -v xcodegen >/dev/null 2>&1 && (cd "$ROOT" && xcodegen generate >/dev/null)
xcodebuild -project "$PROJ" -scheme ThreeLineCalMac -destination "platform=macOS" \
  -derivedDataPath "$ROOT/build/ddmac" CODE_SIGNING_ALLOWED=NO build >/dev/null
MAC_APP="$(find "$ROOT/build/ddmac/Build/Products" -name ThreeLineCalMac.app -maxdepth 3 | head -1)"
BIN="$MAC_APP/Contents/MacOS/ThreeLineCalMac"

echo "[2/3] Rendering (${LOCALES[*]})..."
for loc in "${LOCALES[@]}"; do
  if [ "$loc" = "en" ]; then out="$OUT/mac-app.png"; else out="$OUT/mac-app-$loc.png"; fi
  # The harness renders + writes synchronously during the first view load, then
  # the process is no longer needed; run it briefly and stop it.
  "$BIN" -RenderApp "$out" -AppleLanguages "($loc)" -AppleLocale "$loc" &
  pid=$!
  sleep 4
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  echo "  wrote $out"
done

echo "[3/3] Done."
ls -la "$OUT"/mac-app*.png 2>/dev/null || true
