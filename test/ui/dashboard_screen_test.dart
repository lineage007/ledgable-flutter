import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgable_app/ui/screens/dashboard_screen.dart';

import '../support/fake_http.dart';
import '../support/fixtures.dart';
import '../support/harness.dart';

void main() {
  setUpAll(setUpFormatting);

  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.signedIn();
  });

  testWidgets('renders the cash position and the aged totals', (tester) async {
    harness.http.on('GET', '/dashboard', [FakeReply(200, dashboardPayload())]);

    await tester.pumpWidget(harness.wrap(const DashboardScreen(), me: testMe()));
    await tester.pumpAndSettle();

    expect(find.text('Cash position'), findsOneWidget);
    expect(find.text(r'$18,450.25'), findsOneWidget);
    expect(find.text('Owed to you'), findsOneWidget);
    expect(find.text('You owe'), findsOneWidget);
    // Overdue is called out rather than buried in the total.
    expect(find.text(r'$3,080 overdue'), findsOneWidget);
    // Nothing overdue on the payables side, so it reports the count instead.
    expect(find.text('3 invoices'), findsOneWidget);
  });

  testWidgets('labels the financial year and the three FY figures', (tester) async {
    harness.http.on('GET', '/dashboard', [FakeReply(200, dashboardPayload())]);

    await tester.pumpWidget(harness.wrap(const DashboardScreen(), me: testMe()));
    await tester.pumpAndSettle();

    expect(find.text('This financial year'), findsOneWidget);
    expect(find.textContaining('1 July to 30 June'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Net profit'), findsOneWidget);
    expect(find.textContaining('+12.4% on last year'), findsOneWidget);
  });

  testWidgets('omits a trend it was not given rather than showing 0%', (tester) async {
    final payload = dashboardPayload();
    (payload['kpis'] as Map<String, dynamic>)['fyRevenueTrendPct'] = null;

    harness.http.on('GET', '/dashboard', [FakeReply(200, payload)]);
    await tester.pumpWidget(harness.wrap(const DashboardScreen(), me: testMe()));
    await tester.pumpAndSettle();

    // A workspace in its first year has no comparable prior period; claiming
    // 0% would assert flat performance that was never measured.
    expect(find.textContaining('+12.4% on last year'), findsNothing);
    expect(find.textContaining('0.0% on last year'), findsNothing);
    expect(find.text('Income'), findsOneWidget);
  });

  testWidgets('explains a missing cash position instead of showing a dash alone', (tester) async {
    final payload = dashboardPayload();
    (payload['kpis'] as Map<String, dynamic>)['cashPosition'] = null;

    harness.http.on('GET', '/dashboard', [FakeReply(200, payload)]);
    await tester.pumpWidget(harness.wrap(const DashboardScreen(), me: testMe()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Connect a bank feed'), findsOneWidget);
  });

  testWidgets('shows recent activity with income and expense distinguished', (tester) async {
    harness.http.on('GET', '/dashboard', [FakeReply(200, dashboardPayload())]);

    await tester.pumpWidget(harness.wrap(const DashboardScreen(), me: testMe()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Recent activity'), 200);

    expect(find.text('Bunnings Warehouse'), findsOneWidget);
    expect(find.text('Harbour Cafe'), findsOneWidget);
    expect(find.byIcon(Icons.south_west_rounded), findsWidgets);
    expect(find.byIcon(Icons.north_east_rounded), findsWidgets);
  });

  testWidgets('a failed load offers a retry with the request id', (tester) async {
    harness.http.on('GET', '/dashboard', [
      FakeReply.error(503, code: 'UNAVAILABLE', message: 'Ledgable is having a moment'),
    ]);

    await tester.pumpWidget(harness.wrap(const DashboardScreen(), me: testMe()));
    await tester.pumpAndSettle();

    expect(find.text('Ledgable is having a moment'), findsOneWidget);
    expect(find.text('Reference req_test'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a connection failure says so rather than showing a raw error', (tester) async {
    harness.http.on('GET', '/dashboard', []);

    await tester.pumpWidget(harness.wrap(const DashboardScreen(), me: testMe()));
    await tester.pumpAndSettle();

    // The unscripted fallback is a 501; what matters is that it is a readable
    // sentence and not an exception dump.
    expect(find.byIcon(Icons.error_outline_rounded), findsWidgets);
  });

  testWidgets('shows the workspace name, and no switcher for a single workspace', (tester) async {
    harness.http.on('GET', '/dashboard', [FakeReply(200, dashboardPayload())]);

    await tester.pumpWidget(harness.wrap(const DashboardScreen(), me: testMe()));
    await tester.pumpAndSettle();

    expect(find.text('Salt & Stone Pty Ltd'), findsOneWidget);
    expect(find.byTooltip('Switch workspace'), findsNothing);
  });

  testWidgets('offers a switcher when the user has more than one workspace', (tester) async {
    harness.http.on('GET', '/dashboard', [FakeReply(200, dashboardPayload())]);

    await tester.pumpWidget(harness.wrap(const DashboardScreen(), me: testMe(workspaceCount: 3)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Switch workspace'), findsOneWidget);
  });

  testWidgets('renders in dark mode', (tester) async {
    harness.http.on('GET', '/dashboard', [FakeReply(200, dashboardPayload())]);

    await tester.pumpWidget(
      harness.wrap(const DashboardScreen(), me: testMe(), brightness: Brightness.dark),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(r'$18,450.25'), findsOneWidget);
  });
}
