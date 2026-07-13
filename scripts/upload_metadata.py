#!/usr/bin/env python3
"""Upload metadata/<asc-locale>/*.txt to App Store Connect via the API.

Per locale:
    subtitle.txt                      -> appInfoLocalizations (created if missing)
    description/keywords/whats_new    -> appStoreVersionLocalizations of every
                                         *editable* version (iOS and macOS)

The store NAME is left untouched (stays the English name in every locale).
whats_new is skipped automatically where ASC rejects it (a platform's first version).

Reads credentials from .creds/asc.env (gitignored). Requires PyJWT:
    pip install PyJWT cryptography

Usage: upload_metadata.py [--platform IOS|MAC_OS] [--locale zh-Hans]
"""
import os, re, sys, json, time, urllib.request, urllib.error
import jwt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CREDS = os.path.join(ROOT, ".creds", "asc.env")
META = os.path.join(ROOT, "metadata")

# Metadata is editable only in these appStoreState values.
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


def tok():
    n = int(time.time())
    return jwt.encode({"iss": ISSUER, "iat": n, "exp": n + 600, "aud": "appstoreconnect-v1"},
                      KEY, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})


def api(path, method="GET", body=None, quiet=False):
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(BASE + path, data=data,
                                 headers={"Authorization": f"Bearer {tok()}",
                                          "Content-Type": "application/json"},
                                 method=method)
    try:
        raw = urllib.request.urlopen(req, timeout=40).read()
        return json.loads(raw) if raw else {"ok": True}
    except urllib.error.HTTPError as e:
        if not quiet:
            print("  ERR", e.code, method, path, "->", e.read().decode()[:240])
        return None


def read_meta(locale, name):
    path = os.path.join(META, locale, name)
    return open(path, encoding="utf-8").read().strip() if os.path.exists(path) else None


def locales_on_disk(only=None):
    locs = sorted(d for d in os.listdir(META) if os.path.isdir(os.path.join(META, d)))
    return [l for l in locs if only is None or l == only]


def update_app_info(app_id, locales):
    """Subtitle per locale on the editable appInfo. Name is intentionally untouched."""
    infos = api(f"/v1/apps/{app_id}/appInfos")["data"]
    info = next((i for i in infos if i["attributes"].get("appStoreState") in EDITABLE), infos[0])
    existing = {l["attributes"]["locale"]: l
                for l in api(f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]}
    base_name = next((l["attributes"].get("name") for l in existing.values()
                      if l["attributes"].get("name")), None)
    for loc in locales:
        subtitle = read_meta(loc, "subtitle.txt")
        if subtitle is None:
            continue
        if loc in existing:
            r = api(f"/v1/appInfoLocalizations/{existing[loc]['id']}", "PATCH",
                    {"data": {"type": "appInfoLocalizations", "id": existing[loc]["id"],
                              "attributes": {"subtitle": subtitle}}})
        else:
            r = api("/v1/appInfoLocalizations", "POST",
                    {"data": {"type": "appInfoLocalizations",
                              "attributes": {"locale": loc, "name": base_name, "subtitle": subtitle},
                              "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}}}})
        print(f"  appInfo {loc}: {'OK' if r else 'FAIL'}")


def update_version(ver, locales):
    vid, plat = ver["id"], ver["attributes"]["platform"]
    print(f"version {ver['attributes']['versionString']} ({plat})")
    existing = {l["attributes"]["locale"]: l
                for l in api(f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]}
    for loc in locales:
        attrs = {}
        for key, fname in [("description", "description.txt"), ("keywords", "keywords.txt"),
                           ("whatsNew", "whats_new.txt")]:
            v = read_meta(loc, fname)
            if v is not None:
                attrs[key] = v
        if not attrs:
            continue
        if loc in existing:
            lid = existing[loc]["id"]
            r = api(f"/v1/appStoreVersionLocalizations/{lid}", "PATCH",
                    {"data": {"type": "appStoreVersionLocalizations", "id": lid,
                              "attributes": attrs}}, quiet=True)
            if not r and "whatsNew" in attrs:  # first version of a platform rejects whatsNew
                attrs.pop("whatsNew")
                r = api(f"/v1/appStoreVersionLocalizations/{lid}", "PATCH",
                        {"data": {"type": "appStoreVersionLocalizations", "id": lid,
                                  "attributes": attrs}})
        else:
            body = {"data": {"type": "appStoreVersionLocalizations",
                             "attributes": {"locale": loc, **attrs},
                             "relationships": {"appStoreVersion":
                                 {"data": {"type": "appStoreVersions", "id": vid}}}}}
            r = api("/v1/appStoreVersionLocalizations", "POST", body, quiet=True)
            if not r and "whatsNew" in attrs:
                body["data"]["attributes"].pop("whatsNew")
                r = api("/v1/appStoreVersionLocalizations", "POST", body)
        print(f"  {loc}: {'OK' if r else 'FAIL'}")


def main():
    args = sys.argv[1:]
    platform = args[args.index("--platform") + 1] if "--platform" in args else None
    only_locale = args[args.index("--locale") + 1] if "--locale" in args else None
    locales = locales_on_disk(only_locale)

    app_id = api(f"/v1/apps?filter[bundleId]={BUNDLE}")["data"][0]["id"]
    update_app_info(app_id, locales)

    versions = api(f"/v1/apps/{app_id}/appStoreVersions?limit=20")["data"]
    editable = [v for v in versions
                if v["attributes"].get("appStoreState") in EDITABLE
                and (platform is None or v["attributes"]["platform"] == platform)]
    if not editable:
        print("no editable appStoreVersions found — create the new version in ASC first")
        return
    for ver in editable:
        update_version(ver, locales)


if __name__ == "__main__":
    main()
