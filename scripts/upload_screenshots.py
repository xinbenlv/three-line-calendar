#!/usr/bin/env python3
"""Upload marketing/store/*.png to App Store Connect via the API.

These are the "rich" AI-framed device marketing images (real screenshot pixels
faithfully composited into a generated device/desk frame, per
docs: [[screenshots-must-be-faithful]]) — the same images that power the
website's platform gallery (www/screenshots/wdev-*.png are just downscaled
copies of these). This replaces the older plain screenshots/*.png upload.

Reads credentials from .creds/asc.env (gitignored). Requires PyJWT + Pillow:
    pip install PyJWT cryptography Pillow

Gallery (upload order per displayType = store display order; widget-first):
    APP_IPHONE_67          <- iphone-widget, iphone-widget-dark, iphone (companion)
    APP_IPAD_PRO_3GEN_129  <- ipad-widget, ipad (companion)
    APP_WATCH_ULTRA        <- watch (ultra face), watch-modular, watch-app
    APP_DESKTOP (macOS)    <- mac (app), mac-widget
The first file in each displayType clears the set; the rest append. Uploads target
the current *editable* appStoreVersion per platform (PREPARE_FOR_SUBMISSION / rejected
states) rather than just the newest version, since a platform can have both a
READY_FOR_SALE version and an editable one at the same time (so if a platform's
version is locked in review, its sets are simply skipped).
"""
import os, re, sys, json, time, hashlib, socket, urllib.request, urllib.error
import jwt

NETWORK_ERRORS = (urllib.error.URLError, socket.timeout, TimeoutError, ConnectionError)
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CREDS = os.path.join(ROOT, ".creds", "asc.env")

EDITABLE = {"PREPARE_FOR_SUBMISSION", "METADATA_REJECTED", "DEVELOPER_REJECTED",
            "REJECTED", "INVALID_BINARY"}


def load_env():
    env = {}
    for line in open(CREDS):
        m = re.match(r'\s*export\s+(\w+)="?([^"\n]+)"?', line)
        if m:
            env[m.group(1)] = m.group(2)
    return env


ENV = load_env()
KEY_ID = ENV["ASC_KEY_ID"]; ISSUER = ENV["ASC_ISSUER_ID"]
KEY = open(os.path.join(ROOT, ".creds", f"AuthKey_{KEY_ID}.p8")).read()
BUNDLE = ENV.get("ZWF_APP_BUNDLE_ID", "im.zzn.apps.threelinecal")
BASE = "https://api.appstoreconnect.apple.com"

# ordered list of (filename, ASC platform, displayType, accepted (w,h) list; first is the
# resize target). Order within a displayType IS the store gallery order — lead with the
# widget (the core feature), companion-app views last. Files consecutive in a displayType
# accumulate (the first clears the set, the rest append). See scripts/make_widget_store_shots.py
# for how the iPhone/iPad widget shots are produced.
SPECS = [
    ("iphone-widget.png",      "IOS",    "APP_IPHONE_67",         [(1320, 2868), (1290, 2796)]),
    ("iphone-widget-dark.png", "IOS",    "APP_IPHONE_67",         [(1320, 2868), (1290, 2796)]),
    ("iphone.png",             "IOS",    "APP_IPHONE_67",         [(1320, 2868), (1290, 2796)]),
    ("ipad-widget.png",        "IOS",    "APP_IPAD_PRO_3GEN_129", [(2064, 2752), (2048, 2732)]),
    ("ipad.png",               "IOS",    "APP_IPAD_PRO_3GEN_129", [(2064, 2752), (2048, 2732)]),
    ("watch.png",              "IOS",    "APP_WATCH_ULTRA",       [(422, 514), (410, 502)]),
    ("watch-modular.png",      "IOS",    "APP_WATCH_ULTRA",       [(422, 514), (410, 502)]),
    ("watch-app.png",          "IOS",    "APP_WATCH_ULTRA",       [(422, 514), (410, 502)]),
    ("mac.png",                "MAC_OS", "APP_DESKTOP",           [(2560, 1600), (1280, 800)]),
    ("mac-widget.png",         "MAC_OS", "APP_DESKTOP",           [(2560, 1600), (1280, 800)]),
]


def tok():
    n = int(time.time())
    return jwt.encode({"iss": ISSUER, "iat": n, "exp": n + 600, "aud": "appstoreconnect-v1"},
                      KEY, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})


def api(path, method="GET", body=None, retries=4):
    data = json.dumps(body).encode() if body else None
    for attempt in range(retries):
        req = urllib.request.Request(BASE + path, data=data,
                                     headers={"Authorization": f"Bearer {tok()}", "Content-Type": "application/json"},
                                     method=method)
        try:
            raw = urllib.request.urlopen(req, timeout=60).read()
            return json.loads(raw) if raw else {"ok": True}
        except urllib.error.HTTPError as e:
            print("  ERR", e.code, method, path, "->", e.read().decode()[:240]); return None
        except NETWORK_ERRORS as e:
            if attempt == retries - 1:
                print("  ERR (network, giving up)", method, path, "->", e); return None
            print(f"  retrying ({e}) [{attempt + 1}/{retries}]"); time.sleep(3 * (attempt + 1))


def normalize(path, accepted):
    img = Image.open(path).convert("RGB")
    if img.size in accepted:
        return path
    target = accepted[0]
    out = path.replace(".png", f".{target[0]}x{target[1]}.png")
    src_ratio, dst_ratio = img.width / img.height, target[0] / target[1]
    if abs(src_ratio - dst_ratio) / dst_ratio > 0.02:
        # Aspect mismatch (e.g. the mac window capture): letterbox onto the canvas.
        scale = min(target[0] / img.width, target[1] / img.height) * 0.92
        inner = img.resize((int(img.width * scale), int(img.height * scale)), Image.LANCZOS)
        canvas = Image.new("RGB", target, (28, 28, 30))
        canvas.paste(inner, ((target[0] - inner.width) // 2, (target[1] - inner.height) // 2))
        canvas.save(out)
        print(f"  composed {img.size} onto {target}")
    else:
        img.resize(target, Image.LANCZOS).save(out)
        print(f"  resized {img.size} -> {target}")
    return out


def upload_one(setid, path):
    data = open(path, "rb").read()
    r = api("/v1/appScreenshots", "POST", {"data": {"type": "appScreenshots",
            "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": setid}}}}})
    if not r:
        return False
    sid = r["data"]["id"]
    for op in r["data"]["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        for attempt in range(4):
            rq = urllib.request.Request(op["url"], data=chunk, method=op["method"])
            for h in op["requestHeaders"]:
                rq.add_header(h["name"], h["value"])
            try:
                urllib.request.urlopen(rq, timeout=120)
                break
            except NETWORK_ERRORS as e:
                if attempt == 3:
                    raise
                print(f"  chunk retry ({e}) [{attempt + 1}/4]"); time.sleep(3 * (attempt + 1))
    c = api(f"/v1/appScreenshots/{sid}", "PATCH", {"data": {"type": "appScreenshots", "id": sid,
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return bool(c)


def localization_for(app, platform):
    """en-US localization id of the current *editable* version for the platform, or None."""
    vers = [v for v in api(f"/v1/apps/{app}/appStoreVersions")["data"]
            if v["attributes"]["platform"] == platform
            and v["attributes"]["appStoreState"] in EDITABLE]
    if not vers:
        return None
    locs = api(f"/v1/appStoreVersions/{vers[0]['id']}/appStoreVersionLocalizations")["data"]
    return next((l["id"] for l in locs if l["attributes"]["locale"] == "en-US"), None)


def main():
    app = api(f"/v1/apps?filter[bundleId]={BUNDLE}")["data"][0]["id"]
    lids = {}  # platform -> en-US localization id
    cleared = set()  # (lid, dtype) sets already cleared this run
    for fname, platform, dtype, accepted in SPECS:
        path = os.path.join(ROOT, "marketing", "store", fname)
        if not os.path.exists(path):
            print(f"skip {fname} (not found)"); continue
        if platform not in lids:
            lids[platform] = localization_for(app, platform)
        lid = lids[platform]
        if not lid:
            print(f"skip {fname} (no editable {platform} version in ASC)"); continue
        sets = {s["attributes"]["screenshotDisplayType"]: s["id"]
                for s in api(f"/v1/appStoreVersionLocalizations/{lid}/appScreenshotSets")["data"]}
        setid = sets.get(dtype) or api("/v1/appScreenshotSets", "POST", {"data": {"type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": dtype},
                "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": lid}}}}})["data"]["id"]
        if (lid, dtype) not in cleared:
            for s in (api(f"/v1/appScreenshotSets/{setid}/appScreenshots")["data"] or []):
                api(f"/v1/appScreenshots/{s['id']}", "DELETE")
            cleared.add((lid, dtype))
        ok = upload_one(setid, normalize(path, accepted))
        print(f"{dtype} <- {fname}: {'OK' if ok else 'FAIL'}")


if __name__ == "__main__":
    main()
