#!/usr/bin/env python3
"""Upload screenshots/*.png to App Store Connect via the API.

Reads credentials from .creds/asc.env (gitignored). Requires PyJWT + Pillow:
    pip install PyJWT cryptography Pillow

Maps:
    screenshots/iphone-companion.png -> APP_IPHONE_67  (6.9"/6.7")
    screenshots/watch-app.png        -> APP_WATCH_ULTRA (410x502)
Existing screenshots in each set are replaced.
"""
import os, re, sys, json, time, hashlib, urllib.request, urllib.error
import jwt
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CREDS = os.path.join(ROOT, ".creds", "asc.env")


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

# displayType -> list of accepted (w,h); first is the resize target
SPECS = {
    "iphone-companion.png": ("APP_IPHONE_67", [(1320, 2868), (1290, 2796)]),
    "watch-app.png":        ("APP_WATCH_ULTRA", [(410, 502)]),
}


def tok():
    n = int(time.time())
    return jwt.encode({"iss": ISSUER, "iat": n, "exp": n + 600, "aud": "appstoreconnect-v1"},
                      KEY, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})


def api(path, method="GET", body=None):
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(BASE + path, data=data,
                                 headers={"Authorization": f"Bearer {tok()}", "Content-Type": "application/json"},
                                 method=method)
    try:
        raw = urllib.request.urlopen(req, timeout=40).read()
        return json.loads(raw) if raw else {"ok": True}
    except urllib.error.HTTPError as e:
        print("  ERR", e.code, method, path, "->", e.read().decode()[:240]); return None


def normalize(path, accepted):
    img = Image.open(path).convert("RGB")
    if img.size in accepted:
        return path
    target = accepted[0]
    out = path.replace(".png", f".{target[0]}x{target[1]}.png")
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
        rq = urllib.request.Request(op["url"], data=chunk, method=op["method"])
        for h in op["requestHeaders"]:
            rq.add_header(h["name"], h["value"])
        urllib.request.urlopen(rq, timeout=120)
    c = api(f"/v1/appScreenshots/{sid}", "PATCH", {"data": {"type": "appScreenshots", "id": sid,
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return bool(c)


def main():
    app = api(f"/v1/apps?filter[bundleId]={BUNDLE}")["data"][0]["id"]
    ver = [v for v in api(f"/v1/apps/{app}/appStoreVersions")["data"]
           if v["attributes"]["platform"] == "IOS"][0]["id"]
    lid = [l for l in api(f"/v1/appStoreVersions/{ver}/appStoreVersionLocalizations")["data"]
           if l["attributes"]["locale"] == "en-US"][0]["id"]
    sets = {s["attributes"]["screenshotDisplayType"]: s["id"]
            for s in api(f"/v1/appStoreVersionLocalizations/{lid}/appScreenshotSets")["data"]}
    for fname, (dtype, accepted) in SPECS.items():
        path = os.path.join(ROOT, "screenshots", fname)
        if not os.path.exists(path):
            print(f"skip {fname} (not found)"); continue
        setid = sets.get(dtype) or api("/v1/appScreenshotSets", "POST", {"data": {"type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": dtype},
                "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": lid}}}}})["data"]["id"]
        # clear existing
        for s in (api(f"/v1/appScreenshotSets/{setid}/appScreenshots")["data"] or []):
            api(f"/v1/appScreenshots/{s['id']}", "DELETE")
        ok = upload_one(setid, normalize(path, accepted))
        print(f"{dtype}: {'OK' if ok else 'FAIL'}")


if __name__ == "__main__":
    main()
