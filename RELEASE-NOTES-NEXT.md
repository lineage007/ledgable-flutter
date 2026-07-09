# Ledgable — Next Release Notes

**Version:** 1.0.0 (build 4)
**Target:** TestFlight / App Store Connect
**Prepared:** 2026-07-09

---

## What's New for Users

### New App Icon (build 4) — Ground-Up Redesign
Complete redesign of the app icon (v10). The mark shows a white accounting ledger page with a bold teal corner fold (top-right, 360×360px / 45° diagonal) and three ledger entry rows in the lower half. Each row uses a **two-column format** — a wider description bar on the left and a narrower amount bar on the right — representing a classic double-column accounting ledger.

Brand colours: Ledger Teal `#0D9488` on White page, Ink Navy `#0F172A` background.

Key changes from build 3:
- Solid filled rectangles replace rounded stroke lines — reads as an accounting tool, not a generic document icon
- Two-column layout (description | amount) is specific to ledgers, not shared by every file/note app
- Sharp square corners throughout — precision over friendliness
- Row proportions tuned: 76px height, 56px gaps, balanced head/foot margins
- `remove_alpha_ios: true` added to pubspec — App Store alpha-channel compliant

### Previous Release (build 3)
Icon v9: white page with teal corner fold and three horizontal rule lines. First major icon redesign.

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
