#!/usr/bin/env bash
# Programmatic widget screenshots — no manual GUI needed.
#
#  1. Headless renders: every widget family x locale via the DEBUG -RenderWidgets
#     harness (SwiftUI ImageRenderer), for iOS and macOS.
#  2. Real home-screen widget: an XCUITest drives Springboard to add the medium
#     widget, then the sim screen is captured. Before the capture the App Group
#     snapshot is cleared and the demo fallback disabled, so whatever the widget
#     shows comes from the appex's own EventKit read (the end-to-end proof).
#
# Output: screenshots/widgets/{ios,mac}/<locale>/<family>-<state>.png
#         screenshots/widgets/ios-homescreen.png
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/screenshots/widgets"
PROJ="$ROOT/ThreeLineCal.xcodeproj"
SIM="${IPHONE_SIM:-iPhone 17 Pro}"
BID="im.zzn.apps.threelinecal"
GROUP="group.im.zzn.apps.threelinecal"
read -ra LOCALES <<< "${WIDGET_LOCALES:-en ja ar de zh-Hans}"

ADHOC=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM=""
       PROVISIONING_PROFILE_SPECIFIER="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES)

echo "[1/5] Building (ad-hoc signed so the App Group container provisions)..."
command -v xcodegen >/dev/null 2>&1 && (cd "$ROOT" && xcodegen generate >/dev/null)
xcodebuild -project "$PROJ" -scheme ThreeLineCal -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$ROOT/build/ddsig" "${ADHOC[@]}" build >/dev/null
IOS_APP="$(find "$ROOT/build/ddsig/Build/Products" -name ThreeLineCal.app -maxdepth 3 | head -1)"

echo "[2/5] iOS headless family renders (${LOCALES[*]})..."
if [[ "${WIDGET_CLEAN:-0}" = "1" ]]; then
  xcrun simctl shutdown "$SIM" 2>/dev/null || true
  xcrun simctl erase "$SIM"   # fresh home screen: no stale widgets/seeded events
fi
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || true
xcrun simctl install "$SIM" "$IOS_APP"
for loc in "${LOCALES[@]}"; do
  xcrun simctl terminate "$SIM" "$BID" 2>/dev/null || true
  xcrun simctl launch "$SIM" "$BID" -RenderWidgets -AppleLanguages "($loc)" -AppleLocale "$loc" >/dev/null
  sleep 4
done
xcrun simctl terminate "$SIM" "$BID" 2>/dev/null || true
CONT="$(xcrun simctl get_app_container "$SIM" "$BID" data)"
rm -rf "$OUT/ios"; mkdir -p "$OUT/ios"
cp -R "$CONT/Documents/widget-renders/." "$OUT/ios/"

echo "[3/5] macOS headless family renders..."
xcodebuild -project "$PROJ" -scheme ThreeLineCalMac -destination "platform=macOS" \
  -derivedDataPath "$ROOT/build/ddmac" CODE_SIGNING_ALLOWED=NO build >/dev/null
MAC_APP="$(find "$ROOT/build/ddmac/Build/Products" -name ThreeLineCalMac.app -maxdepth 3 | head -1)"
MACOUT="$(mktemp -d)"
for loc in "${LOCALES[@]}"; do
  "$MAC_APP/Contents/MacOS/ThreeLineCalMac" -RenderWidgets "$MACOUT" -AppleLanguages "($loc)" &
  MPID=$!
  sleep 4
  kill "$MPID" 2>/dev/null || true
done
rm -rf "$OUT/mac"; mkdir -p "$OUT/mac"
cp -R "$MACOUT/." "$OUT/mac/"

echo "[4/5] Adding the real widget to the sim home screen (XCUITest)..."
xcrun simctl privacy "$SIM" grant calendar "$BID" 2>/dev/null || true
xcodebuild test -project "$PROJ" -scheme ThreeLineCalUITests \
  -destination "platform=iOS Simulator,name=$SIM" \
  -derivedDataPath "$ROOT/build/ddsig" "${ADHOC[@]}" \
  -only-testing:ThreeLineCalUITests/WidgetHomeScreenTests >/dev/null 2>&1 \
  || echo "  (widget-add UI test failed — add the widget manually, then re-capture)"

# Make the widget's next render provably EventKit-sourced: clear the snapshot,
# disable the DEBUG demo fallback, and restart the sim so timelines reload.
PLIST="$(xcrun simctl get_app_container "$SIM" "$BID" "$GROUP")/Library/Preferences/$GROUP"
xcrun simctl spawn "$SIM" defaults delete "$PLIST" eventsSnapshot 2>/dev/null || true
xcrun simctl spawn "$SIM" defaults write "$PLIST" debugDisableDemoFallback -bool true
xcrun simctl shutdown "$SIM"
xcrun simctl boot "$SIM"
xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || true
sleep 20

echo "[5/5] Revealing the widget page and capturing the home screen..."
# The reboot resets to page 1; this test swipes to the widget's page WITHOUT
# launching the app (which would rewrite the snapshot and spoil the proof).
xcodebuild test -project "$PROJ" -scheme ThreeLineCalUITests \
  -destination "platform=iOS Simulator,name=$SIM" \
  -derivedDataPath "$ROOT/build/ddsig" "${ADHOC[@]}" \
  -only-testing:ThreeLineCalUITests/RevealWidgetTests >/dev/null 2>&1 \
  || echo "  (reveal test failed — the capture may show page 1)"
xcrun simctl io "$SIM" screenshot "$OUT/ios-homescreen.png"
xcrun simctl spawn "$SIM" defaults delete "$PLIST" debugDisableDemoFallback 2>/dev/null || true
echo "Done."
find "$OUT" -name '*.png' | sort
