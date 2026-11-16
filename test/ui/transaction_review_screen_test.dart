import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgable_app/api/api_exception.dart';
import 'package:ledgable_app/ui/screens/transaction_review_screen.dart';

import '../support/fake_http.dart';
import '../support/fixtures.dart';
import '../support/harness.dart';

void main() {
  setUpAll(setUpFormatting);

  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.signedIn();
  });

  /// The screen makes two `/transactions` calls on load: the needs-review queue,
  /// then `filter=all` for the category options. The fake keys on path only, so
  /// script them in order.
  void scriptQueue({Map<String, dynamic>? queue, Map<String, dynamic>? history}) {
    harness.http.on('GET', '/transactions', [
      FakeReply(200, queue ?? reviewQueuePayload()),
      FakeReply(200, history ?? categorisedTransactionsPayload()),
    ]);
  }

  testWidgets('shows the queue with the outstanding count', (tester) async {
    scriptQueue();

    await tester.pumpWidget(harness.wrap(const TransactionReviewScreen(), me: testMe()));
    await tester.pumpAndSettle();

    expect(find.text('Officeworks'), findsOneWidget);
    expect(find.text('Reece Plumbing'), findsOneWidget);
    expect(find.text('3 to sort'), findsOneWidget);
    // Cents from the API rendered as Australian dollars.
    expect(find.text(r'$184.30'), findsOneWidget);
    expect(find.text(r'$1,342.90'), findsOneWidget);
  });

  testWidgets('a swipe right files the transaction under the suggested category', (tester) async {
    scriptQueue();
    harness.http.on('POST', '/transactions/txn-a/categorise', [
      FakeReply(200, {
        'transactionId': 'txn-a',
        'previousCategoryCode': null,
        'categoryCode': 'materials_and_parts',
      }),
    ]);

    await tester.pumpWidget(harness.wrap(const TransactionReviewScreen(), me: testMe()));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Officeworks'), const Offset(500, 0));
    await settleWithNetwork(tester);

    final calls = harness.http.requestsTo('POST', '/transactions/txn-a/categorise');
    expect(calls, hasLength(1));
    // The most-used code in the workspace, which is what the card's label named.
    expect(calls.single.json?['categoryCode'], 'materials_and_parts');
    // Removed from the queue, and the count follows.
    expect(find.text('Officeworks'), findsNothing);
    expect(find.text('2 to sort'), findsOneWidget);
  });

  testWidgets('undo still works after switching tab while the snackbar shows', (tester) async {
    // The shell rebuilds a tab's screen from scratch on every switch, but the
    // snackbar lives on the app's messenger and outlasts it. Tapping Undo then
    // ran setState and ref on a disposed screen: it threw and undid nothing.
    scriptQueue();
    harness.http.on('POST', '/transactions/txn-a/categorise', [
      FakeReply(200, {
        'transactionId': 'txn-a',
        'previousCategoryCode': 'general_expenses',
        'categoryCode': 'materials_and_parts',
      }),
      FakeReply(200, {
        'transactionId': 'txn-a',
        'previousCategoryCode': 'materials_and_parts',
        'categoryCode': 'general_expenses',
      }),
    ]);
    final onReviewTab = ValueNotifier(true);
    addTearDown(onReviewTab.dispose);

    await tester.pumpWidget(
      harness.wrap(
        Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: onReviewTab,
            builder: (_, showReview, _) =>
                showReview ? const TransactionReviewScreen() : const Text('Another tab'),
          ),
        ),
        me: testMe(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Officeworks'), const Offset(500, 0));
    await settleWithNetwork(tester);
    expect(find.text('Undo'), findsOneWidget);

    onReviewTab.value = false;
    await tester.pump();
    expect(find.text('Another tab'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settleWithNetwork(tester);

    expect(tester.takeException(), isNull);
    final calls = harness.http.requestsTo('POST', '/transactions/txn-a/categorise');
    expect(calls, hasLength(2));
    expect(calls.last.json!['categoryCode'], 'general_expenses');
    expect(find.textContaining('Put back to General expenses'), findsOneWidget);
  });

  testWidgets('offers an undo that categorises back to the prior code', (tester) async {
    scriptQueue();
    harness.http.on('POST', '/transactions/txn-a/categorise', [
      FakeReply(200, {
        'transactionId': 'txn-a',
        'previousCategoryCode': 'general_expenses',
        'categoryCode': 'materials_and_parts',
      }),
      FakeReply(200, {
        'transactionId': 'txn-a',
        'previousCategoryCode': 'materials_and_parts',
        'categoryCode': 'general_expenses',
      }),
    ]);

    await tester.pumpWidget(harness.wrap(const TransactionReviewScreen(), me: testMe()));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Officeworks'), const Offset(500, 0));
    await settleWithNetwork(tester);

    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settleWithNetwork(tester);

    final calls = harness.http.requestsTo('POST', '/transactions/txn-a/categorise');
    expect(calls, hasLength(2));
    expect(calls.last.json?['categoryCode'], 'general_expenses');
  });

  testWidgets('a failed categorisation puts the row back rather than losing it', (tester) async {
    scriptQueue();
    harness.http.on('POST', '/transactions/txn-a/categorise', [
      FakeReply.error(403, code: 'PERMISSION_DENIED', message: 'Not allowed'),
    ]);

    await tester.pumpWidget(harness.wrap(const TransactionReviewScreen(), me: testMe()));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Officeworks'), const Offset(500, 0));
    await settleWithNetwork(tester);

    // The error is in the visible layer, and no work was lost.
    expect(find.textContaining('Not allowed'), findsOneWidget);
    expect(find.text('Officeworks'), findsOneWidget);
    expect(find.text('3 to sort'), findsOneWidget);
  });

  testWidgets('a swipe left opens the picker, which lists used codes', (tester) async {
    scriptQueue();

    await tester.pumpWidget(harness.wrap(const TransactionReviewScreen(), me: testMe()));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Officeworks'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Categorise'), findsOneWidget);
    expect(find.text('Materials and parts'), findsOneWidget);
    expect(find.textContaining('used 3 times recently'), findsOneWidget);
    expect(find.text('Fuel'), findsOneWidget);
  });

  testWidgets('the picker accepts a code typed by hand', (tester) async {
    // A category created on the web and never used cannot appear in the derived
    // list, so typing it must be possible or it would be unreachable.
    scriptQueue();
    harness.http.on('POST', '/transactions/txn-a/categorise', [
      FakeReply(200, {
        'transactionId': 'txn-a',
        'previousCategoryCode': null,
        'categoryCode': '703',
      }),
    ]);

    await tester.pumpWidget(harness.wrap(const TransactionReviewScreen(), me: testMe()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Officeworks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '703');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use "703"'));
    await settleWithNetwork(tester);

    expect(
      harness.http
          .requestsTo('POST', '/transactions/txn-a/categorise')
          .single
          .json?['categoryCode'],
      '703',
    );
  });

  testWidgets('a read-only role sees the queue but no gestures', (tester) async {
    scriptQueue();

    await tester.pumpWidget(
      harness.wrap(const TransactionReviewScreen(), me: testMe(permissions: const ['READ'])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Officeworks'), findsOneWidget);
    // No Dismissible: a tap the API would refuse is not offered at all.
    expect(find.byType(Dismissible), findsNothing);
    expect(find.textContaining('read-only'), findsOneWidget);
  });

  testWidgets('an empty queue reads as good news, not as an error', (tester) async {
    scriptQueue(
      queue: {
        'transactions': <Map<String, dynamic>>[],
        'page': {'limit': 25, 'offset': 0, 'total': 0, 'hasMore': false},
      },
    );

    await tester.pumpWidget(harness.wrap(const TransactionReviewScreen(), me: testMe()));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to review'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry and shows the request id', (tester) async {
    harness.http.on('GET', '/transactions', [
      FakeReply.error(500, code: 'INTERNAL', message: 'Something broke'),
    ]);

    await tester.pumpWidget(harness.wrap(const TransactionReviewScreen(), me: testMe()));
    await tester.pumpAndSettle();

    expect(find.text('Something broke'), findsOneWidget);
    expect(find.text('Reference req_test'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the queue still loads when the category sample fails', (tester) async {
    // The picker degrades to a typed code; the queue must not go down with it.
    harness.http.on('GET', '/transactions', [
      FakeReply(200, reviewQueuePayload()),
      FakeReply.error(500, code: 'INTERNAL'),
    ]);

    await tester.pumpWidget(harness.wrap(const TransactionReviewScreen(), me: testMe()));
    await tester.pumpAndSettle();

    expect(find.text('Officeworks'), findsOneWidget);
    expect(find.textContaining('Swipe left or tap'), findsWidgets);
  });

  testWidgets('an expired token mid-swipe refreshes and the categorisation lands', (tester) async {
    scriptQueue();
    harness.http.on('POST', '/transactions/txn-a/categorise', [
      FakeReply.error(401, code: ApiErrorCode.tokenExpired),
      FakeReply(200, {
        'transactionId': 'txn-a',
        'previousCategoryCode': null,
        'categoryCode': 'materials_and_parts',
      }),
    ]);
    harness.http.on('POST', '/auth/refresh', [
      FakeReply(200, tokenPair(access: 'access-2', refresh: 'refresh-2')),
    ]);

    await tester.pumpWidget(harness.wrap(const TransactionReviewScreen(), me: testMe()));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Officeworks'), const Offset(500, 0));
    await settleWithNetwork(tester);

    expect(harness.http.countOf('POST', '/auth/refresh'), 1);
    expect(find.text('Officeworks'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('renders in dark mode', (tester) async {
    scriptQueue();

    await tester.pumpWidget(
      harness.wrap(const TransactionReviewScreen(), me: testMe(), brightness: Brightness.dark),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Officeworks'), findsOneWidget);
  });
}
