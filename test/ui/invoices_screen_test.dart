import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgable_app/ui/screens/invoices_screen.dart';

import '../support/fake_http.dart';
import '../support/fixtures.dart';
import '../support/harness.dart';

void main() {
  setUpAll(setUpFormatting);

  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.signedIn();
    harness.http.on('GET', '/invoices', [FakeReply(200, invoiceListPayload())]);
  });

  testWidgets('lists invoices with the customer and the invoice number', (tester) async {
    await tester.pumpWidget(harness.wrap(const InvoicesScreen(), me: testMe()));
    await tester.pumpAndSettle();

    expect(find.text('Harbour Cafe'), findsOneWidget);
    expect(find.text('INV-0042'), findsOneWidget);
    expect(find.text('Northside Strata'), findsOneWidget);
  });

  testWidgets('overdue outranks the status so a late invoice is not buried', (tester) async {
    await tester.pumpWidget(harness.wrap(const InvoicesScreen(), me: testMe()));
    await tester.pumpAndSettle();

    // INV-0042 is `authorised`, which would normally read "Awaiting payment";
    // being three weeks late is the more important fact.
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Awaiting payment'), findsNothing);
  });

  testWidgets('a paid invoice headlines what it was worth, not zero', (tester) async {
    await tester.pumpWidget(harness.wrap(const InvoicesScreen(), me: testMe()));
    await tester.pumpAndSettle();

    // amountDue on a paid invoice is 0.00, and "$0.00" reads as an invoice for
    // nothing rather than one that has been settled.
    expect(find.text(r'$6,380.00'), findsOneWidget);
    expect(find.text(r'$0.00'), findsNothing);
    // Outstanding invoices still show what is owed.
    expect(find.text(r'$2,750.00'), findsOneWidget);
  });

  testWidgets('a due date keeps its capitalised month mid-sentence', (tester) async {
    await tester.pumpWidget(harness.wrap(const InvoicesScreen(), me: testMe()));
    await tester.pumpAndSettle();

    expect(find.text('Due 15 Aug 2026'), findsOneWidget);
    expect(find.text('Due 15 aug 2026'), findsNothing);
  });

  testWidgets('flags a draft that has not been sent', (tester) async {
    await tester.pumpWidget(harness.wrap(const InvoicesScreen(), me: testMe()));
    await tester.pumpAndSettle();

    expect(find.text('Not sent yet'), findsOneWidget);
    expect(find.text('Draft'), findsWidgets);
  });

  testWidgets('filtering re-queries the API with the status', (tester) async {
    harness.http.on('GET', '/invoices', [
      FakeReply(200, invoiceListPayload()),
      FakeReply(200, {
        'invoices': <Map<String, dynamic>>[],
        'page': {'limit': 25, 'offset': 0, 'total': 0, 'hasMore': false},
      }),
    ]);

    await tester.pumpWidget(harness.wrap(const InvoicesScreen(), me: testMe()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Drafts'));
    await settleWithNetwork(tester);

    expect(harness.http.requestsTo('GET', '/invoices').last.query['status'], 'draft');
    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets('hides the new-invoice action from a read-only role', (tester) async {
    await tester.pumpWidget(
      harness.wrap(const InvoicesScreen(), me: testMe(permissions: const ['READ'])),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  testWidgets('renders in dark mode', (tester) async {
    await tester.pumpWidget(
      harness.wrap(const InvoicesScreen(), me: testMe(), brightness: Brightness.dark),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Harbour Cafe'), findsOneWidget);
  });
}
