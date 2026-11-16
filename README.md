# Ledgable for iOS and Android

The mobile companion to [Ledgable](https://ledgable.co), the Australian
AI-native accounting app. This is a **client of the web app, not a second
product**: every figure it shows comes from the same service functions the web
dashboard renders from, and every write goes through the same validated,
workspace-scoped implementation, over `/api/mobile/v1`.

The alternative — a mobile backend that reimplements invoicing, GST and
categorisation — produces two systems that disagree about the ledger, and in
accounting software a disagreement about the ledger is the whole failure.

- API contract: `docs/mobile/openapi.yaml` in the web repository.
- Architecture and phasing: `docs/mobile/PLAN.md` in the web repository.
- Current state and handoffs: [`STATUS-app.md`](STATUS-app.md).

## What it does

| Screen | What it is for |
|---|---|
| Sign in | Email and password, per-device tokens. |
| Home | Cash position, receivables, payables, FY income/expenses/profit, a 12-month chart and recent activity. |
| Review | The uncategorised-transaction queue. Swipe right to accept a category, left to pick one. Every action is undoable. |
| Receipts | Capture with the camera or library, OCR polling, and a review screen that is explicit about confidence and checks the GST. |
| Invoices | List, detail, create a draft, and send. Sending is a separate confirmed step. |
| Approvals | Bills, pay runs and leave awaiting sign-off. Read-only — see below. |
| You | Workspace switcher, signed-in devices, legal links, sign out, delete account. |

**Approvals are read-only on purpose.** Approving a pay run commits PAYG
withholding and super guarantee liabilities; approving leave deducts an accrued
balance. Those state machines live inside the payroll routes on the web, and an
Approve button here would be a second copy of the transition rules that could
drift from the first. Each item deep-links to the page that can act on it.

## Running it

Requires Flutter 3.41 or newer (`flutter --version`).

```bash
flutter pub get

# Against production.
flutter run

# Against a local Next.js dev server. Use your machine's LAN address rather
# than localhost when running on a physical handset — localhost on the phone is
# the phone.
flutter run --dart-define=LEDGABLE_API_BASE_URL=http://192.168.1.10:7331

# The Android emulator reaches the host at 10.0.2.2.
flutter run --dart-define=LEDGABLE_API_BASE_URL=http://10.0.2.2:7331
```

Configuration is `--dart-define` only, and there are no secrets in this
repository by construction: the app holds no API key, only the per-device
tokens it earns at sign-in, which live in the iOS Keychain / Android Keystore.

| Define | Default | What it is |
|---|---|---|
| `LEDGABLE_API_BASE_URL` | `https://ledgable.co` | Origin of the deployment. `/api/mobile/v1` is appended by the client. |
| `LEDGABLE_WEB_BASE_URL` | same as the API URL | Where "open on the web" links point. |

The server needs `MOBILE_TOKEN_SECRET` set, in every environment. The mobile
API fails closed without it, by design — there is no fallback.

## Tests

```bash
flutter analyze                                  # must be clean
flutter test                                     # everything
flutter test --exclude-tags golden               # logic only
flutter test --tags golden                       # pixel comparisons
flutter test --update-goldens test/golden        # after an intentional UI change
```

| Suite | What it covers |
|---|---|
| `test/api/token_refresh_test.dart` | The token contract. The most important tests here. |
| `test/core/money_test.dart` | Decimal money, cents, Australian dates and the FY. |
| `test/data/repositories_test.dart` | Request shapes, response mapping, error surfacing. |
| `test/ui/` | Sign in, the review queue, the dashboard, the invoice list. |
| `test/golden/` | Four screens in both themes. |

Goldens register the app's real bundled fonts and the SDK's Material icon font,
so they compare actual rendered text. They are generated on macOS; a different
rasteriser may produce sub-pixel differences, so treat an unexpected diff as a
question rather than a failure.

## Notes for anyone working on this

**The token flow is the part to be careful with.** A refresh token is
single-use, and presenting one that has already been exchanged revokes every
credential on the device — immediately, with no way back except signing in
again. `SessionManager` therefore keeps exactly one refresh in flight globally,
and persists the successor pair before using it. If you touch
`lib/api/session_manager.dart` or `lib/api/auth_interceptor.dart`, run
`test/api/token_refresh_test.dart` and read why each test exists.

**Money is never a `double`.** The API sends dollars as fixed-2 strings because
`Decimal(12,2)` exceeds what an IEEE-754 double holds exactly. Use
`Money.parse`, and `Money.format`, which formats the `Decimal` directly.
`Transaction.total` and invoice `unitPriceCents` are integer cents — the two
documented exceptions.

**Colours come from the theme, not from constants.** `context.c` gives the
semantic palette. `kSuccess` on the dark canvas is 3.4:1, which fails as text,
so a hard-coded status colour is a dark-mode bug waiting to happen.

**No purchasing, anywhere.** The app ships as a free companion to the paid web
service under Apple's guideline 3.1.3(f), which permits no purchasing inside the
app and no call to action pointing at purchasing outside it. No "Subscribe",
no "Upgrade", no "See pricing".

## Licences

Inter and Plus Jakarta Sans are bundled under the SIL Open Font License 1.1;
the licences are in `assets/fonts/`.
