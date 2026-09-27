@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgable_app/ui/screens/dashboard_screen.dart';
import 'package:ledgable_app/ui/screens/invoices_screen.dart';
import 'package:ledgable_app/ui/screens/receipt_review_screen.dart';
import 'package:ledgable_app/ui/screens/transaction_review_screen.dart';

import '../support/fake_http.dart';
import '../support/fixtures.dart';
import '../support/harness.dart';

/// Goldens for the screens whose layout is load-bearing.
///
/// Every screen is captured in **both themes**, because the dark palette is a
/// separate set of colours and a regression in one is invisible in the other.
/// The app's real bundled fonts are registered first, so these compare actual
/// rendered text: a label that stops fitting shows up as a visible truncation in
/// the diff rather than a shift in a row of boxes.
///
/// Regenerate with:
///   flutter test --update-goldens test/golden
void main() {
  setUpAll(() async {
    await setUpFormatting();
    // Real glyphs, not the test binding's boxes — see loadAppFonts.
    await loadAppFonts();
  });

  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.signedIn();
  });

  Future<void> capture(
    WidgetTester tester,
    Widget screen,
    String name, {
    Brightness brightness = Brightness.light,
  }) async {
    useIPhoneSurface(tester);
    await tester.pumpWidget(harness.wrap(screen, me: testMe(), brightness: brightness));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  group('dashboard', () {
    setUp(() {
      harness.http.on('GET', '/dashboard', [FakeReply(200, dashboardPayload())]);
    });

    testWidgets('light', (tester) async {
      await capture(tester, const DashboardScreen(), 'dashboard_light');
    });

    testWidgets('dark', (tester) async {
      await capture(tester, const DashboardScreen(), 'dashboard_dark', brightness: Brightness.dark);
    });
  });

  group('review queue', () {
    setUp(() {
      harness.http.on('GET', '/transactions', [
        FakeReply(200, reviewQueuePayload()),
        FakeReply(200, categorisedTransactionsPayload()),
      ]);
    });

    testWidgets('light', (tester) async {
      await capture(tester, const TransactionReviewScreen(), 'review_light');
    });

    testWidgets('dark', (tester) async {
      await capture(
        tester,
        const TransactionReviewScreen(),
        'review_dark',
        brightness: Brightness.dark,
      );
    });
  });

  group('invoices', () {
    setUp(() {
      harness.http.on('GET', '/invoices', [FakeReply(200, invoiceListPayload())]);
    });

    testWidgets('light', (tester) async {
      await capture(tester, const InvoicesScreen(), 'invoices_light');
    });

    testWidgets('dark', (tester) async {
      await capture(tester, const InvoicesScreen(), 'invoices_dark', brightness: Brightness.dark);
    });
  });

  group('receipt review', () {
    testWidgets('a confident reading', (tester) async {
      harness.http.on('GET', '/receipts/r-1', [FakeReply(200, receiptDetailPayload())]);
      await capture(tester, const ReceiptReviewScreen(receiptId: 'r-1'), 'receipt_review_light');
    });

    testWidgets('a reading with both GST warnings', (tester) async {
      // $18.43 on a $184.30 GST-inclusive total is 10% of the inclusive figure
      // rather than one eleventh, and the supplier is not GST-registered — so
      // both advisories should be on screen at once.
      harness.http.on('GET', '/receipts/r-1', [
        FakeReply(
          200,
          receiptDetailPayload(confidence: 0.58, taxAmount: '18.43', vendorGstRegistered: false),
        ),
      ]);
      await capture(
        tester,
        const ReceiptReviewScreen(receiptId: 'r-1'),
        'receipt_review_warnings_dark',
        brightness: Brightness.dark,
      );
    });
  });
}
