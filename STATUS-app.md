# STATUS — worker `app` (Ledgable mobile, Flutter)

Branch `cowork/20260927-ledgable-app`. Phase 1 of `docs/mobile/PLAN.md` built as
a real app against the mobile API v1, plus the Phase 2 and Phase 3 screens the
brief listed. Fresh run — no previous STATUS file to resume from, and no
`extra-app.md` was present.

## Gates

| Gate | Result |
|---|---|
| `flutter analyze` | **0 issues**, whole project. |
| `flutter test` | **131 passing**, 0 failing. |
| `flutter build ios --no-codesign` | **Built** `build/ios/iphoneos/Runner.app` (20.1 MB), `co.ledgable.app`. |
| `flutter build apk --debug` | **Built** `build/app/outputs/flutter-apk/app-debug.apk`. |
| Secrets | None. Config is `--dart-define` only; the app holds no API key. |

Test breakdown: 22 token-flow · 19 money and date · 29 repository ·
7 router/boot · 46 widget (6 screens) · 8 golden (4 screens × both themes).

## Done

**Foundation**
- Bundle id `co.ledgable.app` on both platforms, app name "Ledgable". The
  Kotlin package moved with the Android namespace. Renamed now because the
  identifier cannot be changed once an App Store record exists.
- Typed API client hand-written from `docs/mobile/openapi.yaml`, covering all
  17 endpoints. Repository layer per area. Riverpod for state, go_router for
  routing, Dio for HTTP, `flutter_secure_storage` for credentials.
- **Token handling** per PLAN.md §4 — the part the plan flagged as most likely
  to be got wrong, so it is built around the server's rule:
  - One refresh in flight globally. A caller passes the access token it failed
    with; if the in-memory pair has already rotated it uses that instead. Two
    parallel refreshes with the same token is the reuse signal that revokes the
    device.
  - The successor pair is written to the keychain **before** it is published or
    used, so an app killed mid-rotation comes back with a usable token.
  - Branches on `code`, never on the message. `TOKEN_EXPIRED` → refresh once,
    retry once. `REFRESH_REJECTED`/`INVALID_TOKEN`/`MISSING_TOKEN`/
    `DEVICE_REVOKED` → clear keychain, no retry. `WORKSPACE_FORBIDDEN` → drop
    the stale selection.
  - A 503, a 429 or a network failure during refresh does **not** sign the user
    out. A lift is not a compromise.
  - Proactive refresh 30s before expiry, so a request does not go out with a
    token the server will reject on arrival.
  - No token is ever logged: debug logging is a redacting interceptor rather
    than Dio's `LogInterceptor`, and `AuthTokens.toString` omits both tokens.
  - `installId` is a client-generated UUID in the keychain, not a hardware
    identifier. It survives sign-out so signing back in reuses the device row.
- Device registration, remote sign-out (Settings → Devices), logout that works
  past the access-token TTL, workspace switcher.

**Screens** — sign in; splash/restore; dashboard KPIs; receipt capture
(camera/gallery → upload → OCR poll → review); receipts list; transaction
review queue with swipe-categorise and undo; invoices list/detail/create/send;
approvals (read-only); settings; devices; delete account.

**Australian correctness**
- Money never touches a `double`. Dollars parse to `Decimal` and are formatted
  as `Decimal`. `Transaction.total` and `unitPriceCents` are integer cents, the
  two documented exceptions. A sub-cent invoice line is **rejected, not
  rounded**, matching the API.
- GST checks on a receipt: the tax line is compared against **one eleventh** of
  a GST-inclusive total (not 10% of it, which overstates the credit), and a
  supplier the ABR says is not GST-registered charging GST is flagged as a BAS
  problem.
- `PERSONAL` leave is labelled "Personal / carer's leave" — under the NES it is
  one entitlement, not two.
- Pay-run approvals name **PAYG withholding** and **super guarantee**
  explicitly rather than "tax" and "super".
- Dates are `d MMM yyyy`; the FY is labelled by the year it ends (1 July 2026 →
  FY27). `en_AU` locale data is loaded at startup.
- Australian English throughout ("categorise", "organisation").

**UI**
- Light and dark both complete. Semantic colours come from a `ThemeExtension`,
  so no screen hard-codes a status colour; the pairs that fail on a dark canvas
  (emerald 500 as text, slate 500 on slate 950, default hint/disabled/label
  colours) are set explicitly.
- Checked at 390px. Errors are surfaced in the visible layer — toast or inline,
  never behind a modal — and carry the `x-request-id` so support can trace them.
- Role-aware: a `READ`-only membership sees no write affordances rather than a
  403 after the tap.
- No "Subscribe", "Upgrade" or pricing anywhere — Apple guideline 3.1.3(f).

**Bugs found and fixed while testing** (all would have shipped):
1. `LedgerCard`'s accent stripe used `Row(crossAxisAlignment: stretch)`, which
   hands a child an infinite height constraint inside a `ListView` — an
   assertion failure on every invoice and approval row.
2. The review queue mutated the repository's fixed-length list, so the **first
   swipe** threw `Cannot remove from a fixed-length list`.
3. `en_AU` date symbols are not compiled into `intl` by default; every
   Australian date format threw `LocaleDataException` at runtime.
4. Four layout overflows at 390px (`StatusPill`, `DetailRow`, the receipt field
   row, the invoice due-date row).
5. `"Due ${relative(d).toLowerCase()}"` rendered "Due 15 aug 2026".
6. A paid invoice headlined `$0.00`, because `amountDue` is zero once settled.
7. `humanise` title-cased, producing "Travel Expenses" and "Gst Free Sales".
8. A failed pull-to-refresh left an **unhandled exception** in the zone on
   every list screen — `ref.refresh(provider.future)` rejects and
   `RefreshIndicator.onRefresh` does not catch it. Exactly the case that fires
   when the session has just ended or the phone is offline.

**Fonts bundled rather than fetched.** `google_fonts` downloaded Inter and Plus
Jakarta Sans on first launch, so a new install showed a fallback face until the
download landed — and kept showing it with no signal. An accounting figure in an
unexpected face reads as a rendering fault. Removed the dependency; both
families ship as assets (~2.2 MB) with their SIL OFL 1.1 licences.

## Partial / deliberately not done

- **MFA: not built, because the API has no MFA.** `POST /auth/login` is email +
  password + device descriptor, and the route verifies via `authenticateUser`
  with no second factor. A challenge screen for something the server never
  issues would be invented. See Handoff 2.
- **Offline capture queue not built.** PLAN.md puts the Drift queue in Phase 2
  and the brief scoped Phase 1; the app requires connectivity. A failed upload
  reports clearly and the photo is not consumed, so nothing is lost — but it is
  not queued for later either.
- **Push notifications not wired.** Phase 3 in PLAN.md. The client sends no
  `pushToken`, and omitting it never clears one server-side, so this is safe to
  add later without touching the login path.
- **No in-app receipt image preview.** The API returns metadata and extractions;
  there is no endpoint serving the stored image bytes. See Handoff 3.
- **Receipt review shows and checks, but cannot "confirm".** The brief asked for
  "review/confirm"; the review half is built, the confirm half has no endpoint.
  `/receipts` is GET and POST, `/receipts/{id}` is GET only — there is no way to
  mark an extraction `REVIEWED`, correct a misread figure, or match a receipt to
  a bank transaction. The screen surfaces the reading, flags what is worth
  checking, and says the corrections happen on the web. Adding a
  `PATCH /receipts/{id}/extraction` would close this; folded into Handoff 3.
- **Recording a payment and voiding an invoice** are likewise web-only, for the
  same reason. Each screen says so rather than offering a control that cannot
  save.
- **Category list is derived, not fetched.** See Handoff 1.
- **Receipt list pagination** loads 50 and does not page further. The API does
  it in memory anyway (a known gap in PLAN.md §10); fine at hundreds.
- **Accessibility pass is partial.** Tap targets are ≥48px, buttons and nav
  items carry semantics, and contrast was checked in both themes. A full
  Dynamic Type and VoiceOver/TalkBack pass is Phase 4 and has not been done.
- **No crash reporting.** Deliberate for now: adding an SDK that does cross-app
  tracking would change the privacy-label table in PLAN.md §8 and the review
  outcome. Worth a decision before submission.

## Handoffs

1. **`GET /api/mobile/v1/categories` is needed** (web/mobile API owner). There
   is no way for the client to learn a workspace's category codes — they are
   per-workspace `Category` rows, keyed `(code, userId, workspaceId)`, not an
   enum. The picker currently derives its options from codes already assigned
   to categorised transactions, which is honest but cannot offer a category
   created on the web and never used; the sheet also accepts a typed code so
   such a category is still reachable. A `{ code, name, type }` list endpoint
   would replace both. **This is the most valuable API addition for the app.**
2. **MFA on the mobile login path** (web/mobile API owner). If MFA is enforced
   for web sign-in, a phone currently bypasses it. Worth confirming whether
   that is intended; if not, the mobile login needs a challenge step.
3. **Receipt review needs two things from the API** (web/mobile API owner):
   a **signed short-lived image URL** on `GET /receipts/{id}` — reviewing an
   extraction without seeing the photograph means checking a figure against a
   receipt that is no longer in your hand — and a **write path for the
   extraction**, so "confirm this reading" and "that total is wrong" can happen
   where the receipt was captured rather than back at a desk.
4. **Native approvals** — already filed in `STATUS-mobile.md` on the web side;
   restating the dependency. The app is ready to add the actions as soon as the
   pay-run and leave state machines are shared services.

## What Gary must do for TestFlight

Nothing in this repository blocks a build; what is left is account setup.

1. **`MOBILE_TOKEN_SECRET`** on the Vercel project, all environments
   (`openssl rand -hex 32`). The mobile API fails closed without it, so **the
   app cannot sign in at all until this exists.** Blocking everything below.
2. **Apple Developer Program team** (Organization, with the D-U-N-S number) and
   access for whoever builds. Blocks TestFlight.
3. **App Store Connect record for `co.ledgable.app`.** Not created — the brief
   said not to create store records. The bundle id in this repo is final and
   must match exactly; it cannot be changed after the record exists.
4. **Signing.** `flutter build ios --no-codesign` passes. A signed build needs
   the team selected in Xcode (`ios/Runner.xcodeproj`) and an automatically
   managed provisioning profile.
5. **Icons: already present and final.** `assets/icons/app-icon-1024.png`, the
   iOS `AppIcon.appiconset` and the Android adaptive layers are all in the repo
   from the earlier icon work. Nothing to supply.
6. **Privacy policy and support URLs** reachable, and specific about financial
   data. The app links to `/legal/privacy`, `/legal/terms` and `/contact`.
7. **Privacy labels / Data Safety** — the table in PLAN.md §8 is accurate for
   what this build does. No tracking, no ad SDKs, no IDFA, so **no App Tracking
   Transparency prompt**. Keep it that way.
8. **A demo workspace with realistic Australian data, and a reviewer account.**
   An App Review reviewer who signs in to an empty workspace rejects the app as
   non-functional. This is the most common avoidable rejection.
9. **Screenshots** for every required device size, from demo data — never a
   real workspace.
10. **Decide on crash reporting** before submission (see above).

## Decisions Gary may want to revisit

- **Approvals read-only in v1.** Correct as built, but it does limit what the
  app is worth a push notification for. Native approval needs the payroll state
  machines extracted first (Handoff 4).
- **No offline queue in this build.** Receipt capture is the reason the app gets
  installed, and a tradesperson in a basement cannot capture right now. Worth
  scheduling early in Phase 2.
- **Crash reporting**, as above — a diagnostics decision with a privacy-label
  consequence.
