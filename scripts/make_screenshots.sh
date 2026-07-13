#!/usr/bin/env bash
# Build the app, run it on the iOS + watchOS simulators, and capture App Store screenshots.
# Output: screenshots/iphone-companion.png, screenshots/watch-app.png
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/screenshots"; mkdir -p "$OUT"
PROJ="$ROOT/zWatchface.xcodeproj"
IPHONE="${IPHONE_SIM:-iPhone 17 Pro Max}"           # 6.9" display (App Store size)
WATCH="${WATCH_SIM:-Apple Watch Ultra 3 (49mm)}"
IOS_BID="im.zzn.apps.threelinecal"
WATCH_BID="im.zzn.apps.threelinecal.watchkitapp"
GROUP="group.im.zzn.apps.threelinecal"

echo "[1/5] Generating project + building..."
command -v xcodegen >/dev/null 2>&1 && (cd "$ROOT" && xcodegen generate >/dev/null)
xcodebuild -project "$PROJ" -scheme ThreeLineCal -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$ROOT/build/dd" CODE_SIGNING_ALLOWED=NO build >/dev/null
# Watch app: ad-hoc sign so the App Group container provisions on the simulator.
xcodebuild -project "$PROJ" -scheme zWatchface -destination "generic/platform=watchOS Simulator" \
  -derivedDataPath "$ROOT/build/ddwatch" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="" CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES build >/dev/null
IOS_APP="$(find "$ROOT/build/dd/Build/Products" -name ThreeLineCal.app -maxdepth 3 | head -1)"
WATCH_APP="$(find "$ROOT/build/ddwatch/Build/Products" -name zWatchface.app -maxdepth 3 | head -1)"

echo "[2/5] Booting simulators ($IPHONE, $WATCH)..."
xcrun simctl boot "$IPHONE" 2>/dev/null || true
xcrun simctl boot "$WATCH" 2>/dev/null || true
sleep 25

echo "[3/5] iPhone screenshot..."
xcrun simctl install "$IPHONE" "$IOS_APP"
xcrun simctl launch "$IPHONE" "$IOS_BID" || true
sleep 4
xcrun simctl io "$IPHONE" screenshot "$OUT/iphone-companion.png"

echo "[4/5] Watch screenshot (screenshot mode shows demo events)..."
xcrun simctl install "$WATCH" "$WATCH_APP"
xcrun simctl terminate "$WATCH" "$WATCH_BID" 2>/dev/null || true
# -ScreenshotMode (Debug builds only) makes the app render demo events, no calendar needed.
xcrun simctl launch "$WATCH" "$WATCH_BID" -ScreenshotMode || true
sleep 3
xcrun simctl io "$WATCH" screenshot "$OUT/watch-app.png"

echo "[5/5] Done."
ls -la "$OUT"
