# Ledgable — Next Release Notes

**Version:** 1.0.0 (build 4)
**Target:** TestFlight / App Store Connect
**Prepared:** 2026-07-09, updated 2026-09-27

---

## What's New for Users

### The app now does something (2026-09-27)

Until this build the app was a design prototype with mock data and no backend.
It is now a working client of the Ledgable web app, signing in to a real
account and reading and writing real books over `/api/mobile/v1`.

- **Sign in** with your Ledgable email and password. The phone gets its own
  credential, so signing in on a browser no longer signs the phone out.
- **Home** shows cash position, what you are owed, what you owe, and income,
  expenses and profit for the financial year — the same figures as the web
  dashboard, from the same source.
- **Snap a receipt** with the camera or pick one from your library. Ledgable
  reads the vendor, total and GST, and tells you how sure it is. It checks the
  GST against one eleventh of the total and warns if a supplier that is not
  GST-registered has charged GST.
- **Review transactions** by swiping. Right files it, left picks a category,
  and every action can be undone.
- **Invoices** — see them, raise one, and send it. Sending is always a separate,
  confirmed step.
- **Approvals** — bills, pay runs and leave waiting on you. Read-only for now:
  signing off a pay run commits PAYG and super, so that stays on the web.
- **Delete my account** in Settings, with a clear explanation of what happens to
  each workspace first.

Dark mode throughout. Australian dates, Australian English, and amounts that
are never rounded by the app.

### Bundle identifier (2026-09-27)

Changed to `co.ledgable.app` on both platforms, from the prototype's
`co.ledgable.ledgableApp` / `co.ledgable.ledgable_app`. **This had to happen
before the first App Store Connect record exists — the identifier cannot be
changed afterwards.** The record must be created with `co.ledgable.app`.

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

## Before this build can be uploaded

`MOBILE_TOKEN_SECRET` must be set on the Vercel project, in every environment
(`openssl rand -hex 32`). The mobile API fails closed without it, by design —
there is no fallback — so the app cannot sign in at all until it exists.

The App Store Connect record must use the bundle identifier `co.ledgable.app`.

Full list in `STATUS-app.md`.

---

## TestFlight Upload Instructions (for Gary)

### Option A — Xcode Organizer (recommended)
1. Open the workspace in Xcode: `open ios/Runner.xcworkspace` from the repository root
2. Select the **Runner** scheme, destination **Any iOS Device (arm64)**
3. Product → Archive
4. In Organizer window: select the new archive → **Distribute App** → App Store Connect → Upload
5. Sign in with your Apple ID, select the Ledgable app record, follow prompts

### Option B — xcrun altool (command line)
```bash
# First archive from terminal, from the repository root
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
