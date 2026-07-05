# Ledgable — Next Release Notes

**Version:** 1.0.0 (build 2)  
**Target:** TestFlight / App Store Connect  
**Prepared:** 2026-07-05

---

## What's New for Users

### New App Icon
Complete ground-up icon redesign. The new mark shows a stylised accounting ledger page — a white sheet with a bold teal corner fold and four teal rule lines — on an ink-navy background. Designed to be instantly legible at every size from the App Store (1024px) down to the iPhone home screen spotlight (20px).

Brand colours: Ledger Teal `#0D9488` on Ink Navy `#0F172A`, per the Ledgable brand standard.

---

## Technical Changes This Build

- `flutter_launcher_icons ^0.14.3` added as dev dependency
- Master icon PNG (1024×1024) at `assets/icons/app-icon-1024.png`
- iOS `AppIcon.appiconset` fully regenerated — all required sizes including 1024@1x, 83.5@2x, 60@2x/3x, 40@1x/2x/3x, 29@1x/2x/3x, 20@1x/2x/3x, 76@1x/2x, 50@1x/2x, 57@1x/2x, 72@1x/2x
- Android mipmaps regenerated — mdpi / hdpi / xhdpi / xxhdpi / xxxhdpi
- Build number bumped: +1 → 2

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
