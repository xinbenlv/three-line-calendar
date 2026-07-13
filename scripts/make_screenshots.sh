#!/usr/bin/env bash
# Build the app, run it on the iOS/iPadOS/watchOS simulators + this Mac, and capture
# App Store screenshots.
# Output: screenshots/{iphone-companion,ipad-companion,watch-app,mac-app}.png
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/screenshots"; mkdir -p "$OUT"
PROJ="$ROOT/ThreeLineCal.xcodeproj"
IPHONE="${IPHONE_SIM:-iPhone 17 Pro Max}"           # 6.9" display (App Store size)
IPAD="${IPAD_SIM:-iPad Pro 13-inch (M5)}"           # 13" display (App Store size)
WATCH="${WATCH_SIM:-Apple Watch Ultra 3 (49mm)}"
IOS_BID="im.zzn.apps.threelinecal"
WATCH_BID="im.zzn.apps.threelinecal.watchkitapp"
GROUP="group.im.zzn.apps.threelinecal"

echo "[1/7] Generating project + building..."
command -v xcodegen >/dev/null 2>&1 && (cd "$ROOT" && xcodegen generate >/dev/null)
xcodebuild -project "$PROJ" -scheme ThreeLineCal -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$ROOT/build/dd" CODE_SIGNING_ALLOWED=NO build >/dev/null
# Watch app: ad-hoc sign so the App Group container provisions on the simulator.
xcodebuild -project "$PROJ" -scheme ThreeLineCalWatch -destination "generic/platform=watchOS Simulator" \
  -derivedDataPath "$ROOT/build/ddwatch" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="" CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES build >/dev/null
IOS_APP="$(find "$ROOT/build/dd/Build/Products" -name ThreeLineCal.app -maxdepth 3 | head -1)"
WATCH_APP="$(find "$ROOT/build/ddwatch/Build/Products" -name ThreeLineCalWatch.app -maxdepth 3 | head -1)"

echo "[2/7] Booting simulators ($IPHONE, $IPAD, $WATCH)..."
xcrun simctl boot "$IPHONE" 2>/dev/null || true
xcrun simctl boot "$IPAD" 2>/dev/null || true
xcrun simctl boot "$WATCH" 2>/dev/null || true
sleep 25

echo "[3/7] iPhone screenshot..."
xcrun simctl install "$IPHONE" "$IOS_APP"
xcrun simctl terminate "$IPHONE" "$IOS_BID" 2>/dev/null || true
# -ScreenshotMode (Debug builds only) makes the app render demo events, no calendar needed.
xcrun simctl launch "$IPHONE" "$IOS_BID" -ScreenshotMode || true
sleep 4
xcrun simctl io "$IPHONE" screenshot "$OUT/iphone-companion.png"

echo "[4/7] iPad screenshot..."
xcrun simctl install "$IPAD" "$IOS_APP"
xcrun simctl terminate "$IPAD" "$IOS_BID" 2>/dev/null || true
xcrun simctl launch "$IPAD" "$IOS_BID" -ScreenshotMode || true
sleep 4
xcrun simctl io "$IPAD" screenshot "$OUT/ipad-companion.png"

echo "[5/7] Watch screenshot..."
xcrun simctl install "$WATCH" "$WATCH_APP"
xcrun simctl terminate "$WATCH" "$WATCH_BID" 2>/dev/null || true
xcrun simctl launch "$WATCH" "$WATCH_BID" -ScreenshotMode || true
sleep 3
xcrun simctl io "$WATCH" screenshot "$OUT/watch-app.png"

echo "[6/7] Mac app screenshot (window capture)..."
xcodebuild -project "$PROJ" -scheme ThreeLineCalMac -destination "platform=macOS" \
  -derivedDataPath "$ROOT/build/ddmac" CODE_SIGNING_ALLOWED=NO build >/dev/null
MAC_APP="$(find "$ROOT/build/ddmac/Build/Products" -name ThreeLineCalMac.app -maxdepth 3 | head -1)"
open "$MAC_APP" --args -ScreenshotMode
sleep 5
MAC_PID="$(pgrep -xn ThreeLineCalMac || true)"
if [[ -n "$MAC_PID" ]]; then
  SWIFT_SRC="$(mktemp -t winid).swift"
  cat > "$SWIFT_SRC" <<'EOF'
import CoreGraphics
import Foundation
let pid = Int(CommandLine.arguments[1])!
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in list where (w["kCGWindowOwnerPID"] as? Int) == pid {
    if let n = w["kCGWindowNumber"] as? Int { print(n); break }
}
EOF
  WID="$(swift "$SWIFT_SRC" "$MAC_PID" 2>/dev/null | head -1 || true)"
  if [[ -n "$WID" ]]; then
    screencapture -x -o -l"$WID" "$OUT/mac-app.png" \
      || echo "  (screencapture failed — grant Screen Recording to your terminal and re-run)"
  else
    echo "  (could not find the app window — capture manually with Cmd-Shift-4 + Space)"
  fi
  kill "$MAC_PID" 2>/dev/null || true
fi

echo "[7/7] Done."
ls -la "$OUT"
