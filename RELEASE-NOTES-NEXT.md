# Ledgable — Next Release Notes

**Version:** 1.0.0 (build 3)
**Target:** TestFlight / App Store Connect
**Prepared:** 2026-07-05

---

## What's New for Users

### New App Icon (build 3)
Complete ground-up icon redesign — v9 final. The mark shows a stylised accounting ledger page: pure white sheet with a dominant teal corner fold (41% of page edge) and three bold teal rule lines, on an ink-navy background. Designed to be instantly legible at every size from the App Store (1024px) down to the iPhone home screen spotlight (20px).

Brand colours: Ledger Teal `#0D9488` on Ink Navy `#0F172A` per the Ledgable brand standard.

Changes from build 2 icon:
- Page changed from pale grey `#EDF2F7` to pure white `#FFFFFF` — stronger contrast at all sizes
- Fold triangle enlarged to 360px legs (41% of page edge) — dominant and readable at 60px
- Rules reduced from 4 to 3 — each rule is bolder (36px stroke) and holds its legibility at 20px
- Removed crease line and vertical column divider — cleaner silhouette at small sizes
- Rules redistributed vertically (y=330/530/730) for even spacing across page body

---

## Technical Changes This Build

- Master icon PNG (1024×1024) updated at `assets/icons/app-icon-1024.png`
- iOS `AppIcon.appiconset` fully regenerated — 21 PNG files covering all required sizes:
  1024@1x, 83.5@2x, 76@1x/2x, 72@1x/2x, 60@2x/3x, 57@1x/2x, 50@1x/2x, 40@1x/2x/3x, 29@1x/2x/3x, 20@1x/2x/3x
- Android mipmaps regenerated — mdpi / hdpi / xhdpi / xxhdpi / xxxhdpi
- Build number bumped: 2 → 3

---

## TestFlight Upload Instructions (for Gary)

### Option A — Xcode Organizer (recommended)
1. Open `ledgable_app` in Xcode: `open /Users/cakirfamily/clawd/projects/ledgable_app/ios/Runner.xcworkspace`
2. Select the **Runner** scheme, destination **Any iOS Device (arm64)**
3. Product → Archive
4. In Organizer window: select the new archive → **Distribute App** → App Store Connect → Upload
5. Sign in with your Apple ID, select the Ledgable app record, follow prompts

### Option B — xcrun altool (command line)
```bash
# First archive from terminal
cd /Users/cakirfamily/clawd/projects/ledgable_app
flutter build ipa --release

# Then upload the IPA (requires app-specific password from appleid.apple.com)
xcrun altool --upload-app \
  --type ios \
  --file "build/ios/ipa/ledgable_app.ipa" \
  --username "gary.cakir@gmail.com" \
  --password "@keychain:AC_PASSWORD"
# Or pass the app-specific password directly with --password "xxxx-xxxx-xxxx-xxxx"
```

**Note:** `flutter build ipa` requires a valid provisioning profile and distribution certificate in Keychain. If signing is not configured locally, use Xcode Organizer (Option A) which handles signing interactively.

---

## Design Assets

- Master SVG: `/Users/cakirfamily/clawd/claudecode/projects/portfolio-audit-2026-07-03/icons/ledgable/icon-1024.svg`
- Master PNG: `/Users/cakirfamily/clawd/claudecode/projects/portfolio-audit-2026-07-03/icons/ledgable/icon-1024.png`
- Preview grid (1024/180/120/64): `/Users/cakirfamily/clawd/claudecode/projects/portfolio-audit-2026-07-03/icons/ledgable-preview.png`
