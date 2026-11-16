import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgable_app/ui/screens/delete_account_screen.dart';

import '../support/fake_http.dart';
import '../support/harness.dart';

/// Account deletion is required by App Store guideline 5.1.1(v) and by Google
/// Play, and it is the screen where being wrong costs the most: a Ledgable
/// account is attached to financial records under a seven-year retention
/// commitment, so "delete my account" cannot quietly mean "destroy the books".
void main() {
  setUpAll(setUpFormatting);

  late TestHarness harness;

  Map<String, dynamic> previewPayload({
    bool withLiveSubscription = false,
    bool withRetained = true,
  }) => {
    'retentionYears': 7,
    'activeDeviceCount': 2,
    'totals': {'untouched': 1, 'transferred': 1, 'retained': withRetained ? 1 : 0, 'deleted': 0},
    'workspaces': [
      {
        'workspaceId': 'ws-1',
        'name': 'Salt & Stone Pty Ltd',
        'outcome': 'retained',
        'reason':
            'You are the last member and this workspace holds financial '
            'records, so the books are frozen rather than deleted.',
      },
      {
        'workspaceId': 'ws-2',
        'name': 'Harbour Holdings',
        'outcome': 'transferred',
        'reason': 'Ownership passes to Alex Tran, the longest-standing member.',
      },
      {
        'workspaceId': 'ws-3',
        'name': 'Northside Trust',
        'outcome': 'untouched',
        'reason': 'Another owner remains, so nothing changes.',
      },
    ],
    'workspacesWithLiveSubscription': withLiveSubscription
        ? [
            {'workspaceId': 'ws-1', 'name': 'Salt & Stone Pty Ltd', 'status': 'active'},
          ]
        : <Map<String, dynamic>>[],
    'exportAvailableAt': '/settings/backups',
  };

  setUp(() async {
    harness = await TestHarness.signedIn();
    harness.http.on('GET', '/account', [FakeReply(200, previewPayload())]);
  });

  /// Pumps the screen on a surface tall enough to lay the whole form out at
  /// once. This form is deliberately long — the consequences are read before
  /// the button — and scrolling it step by step in a widget test is fragile
  /// without testing anything these cases are about.
  Future<void> pumpScreen(WidgetTester tester, {Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness.wrap(const DeleteAccountScreen(), me: testMe(), brightness: brightness),
    );
    await tester.pumpAndSettle();
  }

  /// Tick the acknowledgement, enter the password, and press the delete button.
  Future<void> confirmDeletion(WidgetTester tester, {String password = 'hunter2'}) async {
    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Your password'), password);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete my account'));
    await tester.pumpAndSettle();
  }

  testWidgets('says plainly that this deletes the login, not the books', (tester) async {
    await pumpScreen(tester);

    expect(find.text('This deletes your login, not your books'), findsOneWidget);
    expect(find.textContaining('Ledgable commits to 7 years'), findsOneWidget);
  });

  testWidgets('shows every workspace outcome with the server reason verbatim', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Salt & Stone Pty Ltd'), findsOneWidget);
    expect(find.text('Frozen, records kept'), findsOneWidget);
    expect(find.textContaining('the books are frozen rather than deleted'), findsOneWidget);
    expect(find.text('Handed over'), findsOneWidget);
    expect(find.text('Carries on'), findsOneWidget);
  });

  testWidgets('the account header is sent without a workspace header', (tester) async {
    await pumpScreen(tester);

    // Deletion is an account operation; a caller who never finished setup has no
    // workspace to send.
    expect(harness.http.requestsTo('GET', '/account').single.workspaceHeader, isNull);
  });

  testWidgets('warns about a subscription that is still billing', (tester) async {
    harness.http.on('GET', '/account', [
      FakeReply(200, previewPayload(withLiveSubscription: true)),
    ]);

    await pumpScreen(tester);

    expect(find.textContaining('You are still paying for'), findsOneWidget);
    expect(find.textContaining('no refund'), findsOneWidget);
  });

  testWidgets('will not delete until the consequence is acknowledged', (tester) async {
    await pumpScreen(tester);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Delete my account'),
    );
    expect(button.onPressed, isNull, reason: 'disabled until the checkbox is ticked');
  });

  testWidgets('requires the password even after the box is ticked', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete my account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your password to confirm.'), findsOneWidget);
    expect(harness.http.countOf('DELETE', '/account'), 0);
  });

  testWidgets('confirms once more, then sends password and the literal DELETE', (tester) async {
    harness.http.on('DELETE', '/account', [
      FakeReply(200, {
        'deleted': true,
        'reference': 'LGD-7Q2F4K8M',
        'retainedWorkspaces': [
          {
            'id': 'ws-1',
            'name': 'Salt & Stone Pty Ltd',
            'retentionUntil': '2033-09-27T00:00:00.000Z',
          },
        ],
        'devicesRevoked': 2,
        'billingCancellations': <Map<String, dynamic>>[],
      }),
    ]);

    await pumpScreen(tester);

    await confirmDeletion(tester);

    // A second confirmation, naming what will be kept.
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.textContaining('frozen and kept for 7 years'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete it'));
    // pumpNetwork, not settle: the delete button is still showing its spinner
    // under the receipt dialog, so the tree never goes quiet.
    await pumpNetwork(tester);

    final body = harness.http.requestsTo('DELETE', '/account').single.json!;
    expect(body['password'], 'hunter2');
    // The literal string the API requires, as a guard against a replayed body.
    expect(body['confirm'], 'DELETE');
    expect(body['exportAcknowledged'], isFalse);
  });

  testWidgets('shows the support reference and clears the keychain', (tester) async {
    harness.http.on('DELETE', '/account', [
      FakeReply(200, {
        'deleted': true,
        'reference': 'LGD-7Q2F4K8M',
        'retainedWorkspaces': [
          {
            'id': 'ws-1',
            'name': 'Salt & Stone Pty Ltd',
            'retentionUntil': '2033-09-27T00:00:00.000Z',
          },
        ],
        'devicesRevoked': 2,
        'billingCancellations': <Map<String, dynamic>>[],
      }),
    ]);

    await pumpScreen(tester);
    await confirmDeletion(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete it'));
    // pumpNetwork, not settle: the delete button is still showing its spinner
    // under the receipt dialog, so the tree never goes quiet.
    await pumpNetwork(tester);

    // After this response there is no account left to look the reference up
    // from, so it has to be on screen.
    expect(find.text('LGD-7Q2F4K8M'), findsOneWidget);
    expect(find.textContaining('27 Sept 2033'), findsOneWidget);
    expect(harness.client.session.hasSession, isFalse);
  });

  testWidgets('surfaces a billing cancellation that failed', (tester) async {
    harness.http.on('DELETE', '/account', [
      FakeReply(200, {
        'deleted': true,
        'reference': 'LGD-ZZ11',
        'retainedWorkspaces': <Map<String, dynamic>>[],
        'devicesRevoked': 1,
        'billingCancellations': [
          {
            'workspaceId': 'ws-1',
            'name': 'Salt & Stone Pty Ltd',
            'outcome': 'retained',
            'status': 'active',
            'result': 'failed',
            'message': 'Stripe rejected the cancellation',
          },
        ],
      }),
    ]);

    await pumpScreen(tester);
    await confirmDeletion(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete it'));
    // pumpNetwork, not settle: the delete button is still showing its spinner
    // under the receipt dialog, so the tree never goes quiet.
    await pumpNetwork(tester);

    // The account is gone but money is still moving, and there is no account
    // left to cancel it from. This is the one the client MUST surface.
    expect(find.text('A subscription is still billing'), findsOneWidget);
    expect(find.textContaining('Contact support with the reference'), findsOneWidget);
  });

  testWidgets('a wrong password reports inline and keeps the session', (tester) async {
    harness.http.on('DELETE', '/account', [
      FakeReply.error(401, code: 'INVALID_CREDENTIALS', message: 'That password is not right'),
    ]);

    await pumpScreen(tester);
    await confirmDeletion(tester, password: 'wrong');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete it'));
    // pumpNetwork, not settle: the delete button is still showing its spinner
    // under the receipt dialog, so the tree never goes quiet.
    await pumpNetwork(tester);

    expect(find.textContaining('That password is not right'), findsOneWidget);
    expect(harness.client.session.hasSession, isTrue);
  });

  testWidgets('renders in dark mode', (tester) async {
    await pumpScreen(tester, brightness: Brightness.dark);

    expect(tester.takeException(), isNull);
    expect(find.text('This deletes your login, not your books'), findsOneWidget);
  });
}
