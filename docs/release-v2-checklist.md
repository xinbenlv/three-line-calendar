# v2.0 release checklist

Code-side work is in the repo. These are the **manual** Developer-Portal / App Store
Connect / device steps that cannot be scripted with the current credentials.

## 1. Developer portal (developer.apple.com → Identifiers)

- [ ] Register App ID **`im.zzn.apps.threelinecal.widget`** with the **App Groups**
      capability (assign `group.im.zzn.apps.threelinecal`). One App ID covers both the
      iOS and macOS widget appexes.
- [ ] Edit App ID **`im.zzn.apps.threelinecal`**: add the **App Groups** capability
      (the iOS app gained the entitlement in v2; it didn't have it in v1). Also confirm
      the App ID is enabled for macOS (Mac App Store) — the Mac app shares it.
- [ ] **Regenerate the existing iOS App Store profile** ("3LineCal iOS Store") — adding
      a capability invalidates it.
- [ ] Create new App Store provisioning profiles and note their names:
  - iOS App Store profile for `…threelinecal.widget` (e.g. "3LineCal iOS Widget Store")
  - Mac App Store profile for `…threelinecal` (e.g. "3LineCal Mac Store")
  - Mac App Store profile for `…threelinecal.widget` (e.g. "3LineCal Mac Widget Store")
- [ ] Update the gitignored `build/ExportOptions.plist` `provisioningProfiles` map with
      the regenerated iOS app profile + the new widget profile; create a second
      ExportOptions for the macOS archive with the two Mac profiles.

## 2. App Store Connect — app record

- [ ] Add the **macOS platform** to the existing app record (universal purchase; this
      is effectively irreversible). Set macOS availability/pricing (free).
- [ ] Create version **2.0** for iOS and version **2.0** for macOS
      (metadata upload needs an editable version to exist).
- [ ] Decide the "iPhone & iPad Apps on Apple Silicon Macs" toggle — with a native Mac
      app shipping you likely want the iOS app **not** offered on Macs.

## 3. Localized metadata + screenshots (scripted)

- [ ] `scripts/upload_metadata.py` — pushes the 21 `metadata/<locale>/` listings
      (description, keywords, subtitle, what's-new) to every editable version and
      creates missing ASC locales. Store **name** stays English everywhere by design;
      localize names later in ASC UI if desired.
- [ ] `scripts/make_screenshots.sh` then `scripts/upload_screenshots.py` — iPhone 6.9",
      iPad 13" (required again now that iPad is back), Watch, and the Mac desktop
      canvas. Screenshots upload to **en-US**; other locales fall back to it.

## 4. Archive & upload (same CLI recipe as v1, now × 2 platforms)

```bash
xcodegen generate
# iOS (carries the watch app + both watch/iOS widget appexes):
xcodebuild archive -project ThreeLineCal.xcodeproj -scheme ThreeLineCal \
  -destination 'generic/platform=iOS' -archivePath build/ThreeLineCal.xcarchive
xcodebuild -exportArchive -archivePath build/ThreeLineCal.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist -exportPath build/ipa
# macOS:
xcodebuild archive -project ThreeLineCal.xcodeproj -scheme ThreeLineCalMac \
  -destination 'generic/platform=macOS' -archivePath build/ThreeLineCalMac.xcarchive
xcodebuild -exportArchive -archivePath build/ThreeLineCalMac.xcarchive \
  -exportOptionsPlist build/ExportOptionsMac.plist -exportPath build/pkg
```

## 5. On-device QA before submitting

- [ ] **Watch-face regression**: existing complication placement survives the update;
      rows look identical apart from the two intended changes (locale-aware time
      format, "45 min" style live countdown — both called out in what's-new).
- [ ] **iOS widget**: `scripts/render_widget_screenshots.sh` already covers this
      programmatically — it renders every family per locale, adds the real widget to
      the simulator home screen via XCUITest, and captures it with the snapshot
      cleared + demo fallback disabled (verified 2026-07-13: the appex reads EventKit
      itself). On device, just spot-check: add the Home Screen + Lock Screen widgets
      and confirm events appear.
- [ ] **iPad**: app + widgets on a 13" iPad (new App Store requirement returns).
- [ ] **Mac**: launch the app, grant calendar access (expect a one-time app-group
      consent prompt on macOS 15+ dev builds), add the desktop widget from the widget
      gallery, confirm `~/Library/Group Containers/group.im.zzn.apps.threelinecal`
      is shared by app + widget.
- [ ] **Locale spot-check** on any device: Settings → Language → 日本語 / العربية
      (RTL) / Deutsch — app, widget gallery names, and widget content all localize;
      12-hour regions show "9:41 a"-style compact times on the watch face.
- [ ] TestFlight: iPhone + iPad + Watch build, and the Mac build.

## 6. Optional polish (non-blocking)

- [ ] Mac Dock icon: the current icon is the square iOS artwork; macOS masks it, but a
      proper rounded-rect mac icon would look better.
- [ ] `PrivacyInfo.xcprivacy` (UserDefaults reason CA92.1) per target — v1 shipped
      without and passed review, but enforcement keeps tightening.
- [ ] Localize the store *name* per locale (subtitle is already localized).
