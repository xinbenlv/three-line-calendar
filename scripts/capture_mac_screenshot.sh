#!/usr/bin/env bash
# FAITHFUL macOS App Store screenshot — captures the REAL running app window with
# `screencapture` (real pixels, not an ImageRenderer redraw or an AI repaint).
# This is the honest replacement for the -RenderApp harness, which cannot render
# the app's real SwiftUI List/Toggle controls.
#
# REQUIRES: Screen Recording permission for the host app that runs this script
# (System Settings > Privacy & Security > Screen Recording). When Claude Code runs
# inside Claude.app, grant it to "Claude" and restart Claude. From a terminal,
# grant it to that terminal. Without it, screencapture prints
# "could not create image from display".
#
# Output: screenshots/mac-app.png
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/screenshots"; mkdir -p "$OUT"
PROJ="$ROOT/ThreeLineCal.xcodeproj"

echo "[1/3] Building ThreeLineCalMac..."
command -v xcodegen >/dev/null 2>&1 && (cd "$ROOT" && xcodegen generate >/dev/null)
xcodebuild -project "$PROJ" -scheme ThreeLineCalMac -destination "platform=macOS" \
  -derivedDataPath "$ROOT/build/ddmac" CODE_SIGNING_ALLOWED=NO build >/dev/null
MAC_APP="$(find "$ROOT/build/ddmac/Build/Products" -name ThreeLineCalMac.app -maxdepth 3 | head -1)"

# Pick the app's MAIN content window (largest area, tall enough) — skips the
# transient title-bar strips a fresh launch briefly shows. Window number needs no
# Screen Recording permission; the capture does. `.optionAll` finds it even if the
# window opens off-screen (screencapture -l still grabs it from the compositor).
SWIFT_SRC="$(mktemp -t winid).swift"
cat > "$SWIFT_SRC" <<'EOF'
import CoreGraphics
import Foundation
let pid = Int(CommandLine.arguments[1])!
let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
var best: (num: Int, area: CGFloat)? = nil
for w in list where (w["kCGWindowOwnerPID"] as? Int) == pid {
    guard let num = w["kCGWindowNumber"] as? Int,
          let b = w["kCGWindowBounds"] as? [String: CGFloat],
          let width = b["Width"], let height = b["Height"], height >= 200 else { continue }
    let area = width * height
    if best == nil || area > best!.area { best = (num, area) }
}
if let best { print(best.num) }
EOF

shot() {  # $1 = light|dark
  local mode="$1" out="$OUT/mac-app-$1.png"
  echo "[$mode] launching (-ScreenshotMode, demo data)..."
  pkill -x ThreeLineCalMac 2>/dev/null || true; sleep 1
  open "$MAC_APP" --args -ScreenshotMode -ScreenshotAppearance "$mode"
  # Poll until the real content window has settled (it can start as a thin strip).
  local pid="" wid=""
  for _ in $(seq 1 15); do
    sleep 1
    pid="$(pgrep -xn ThreeLineCalMac || true)"
    [ -n "$pid" ] || continue
    wid="$(swift "$SWIFT_SRC" "$pid" 2>/dev/null | head -1 || true)"
    [ -n "$wid" ] && break
  done
  [ -n "$wid" ] || { echo "  could not find the app window"; kill "$pid" 2>/dev/null || true; return 1; }
  # -x: silent, -o: no window shadow (clean edges for compositing).
  if ! screencapture -x -o -l"$wid" "$out"; then
    echo "  screencapture FAILED — grant Screen Recording to the host app in System"
    echo "  Settings (Claude / your terminal), then re-run this script."
    kill "$pid" 2>/dev/null || true; return 1
  fi
  kill "$pid" 2>/dev/null || true
  echo "  -> $out ($(sips -g pixelWidth -g pixelHeight "$out" \
    | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w"x"h}'))"
}

echo "[2/3] Capturing light + dark..."
shot light
shot dark

echo "[3/3] Done."
