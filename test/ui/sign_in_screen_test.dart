import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgable_app/api/api_exception.dart';
import 'package:ledgable_app/api/session_manager.dart';
import 'package:ledgable_app/ui/screens/sign_in_screen.dart';

import '../support/fake_http.dart';
import '../support/harness.dart';

void main() {
  setUpAll(setUpFormatting);

  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.signedIn();
    // Start from no session: this screen is what a signed-out app shows.
    await harness.client.session.signOutLocally(SignedOutReason.userInitiated);
  });

  testWidgets('validates both fields before calling the API', (tester) async {
    await tester.pumpWidget(harness.wrap(const SignInScreen()));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(harness.http.countOf('POST', '/auth/login'), 0);
  });

  testWidgets('rejects an address that is not an email', (tester) async {
    await tester.pumpWidget(harness.wrap(const SignInScreen()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'gary');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'hunter2');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('That does not look like an email address'), findsOneWidget);
    expect(harness.http.countOf('POST', '/auth/login'), 0);
  });

  testWidgets('shows the server message inline when credentials are wrong', (tester) async {
    harness.http.on('POST', '/auth/login', [
      FakeReply.error(
        401,
        code: ApiErrorCode.invalidCredentials,
        message: 'Incorrect email or password',
      ),
    ]);

    await tester.pumpWidget(harness.wrap(const SignInScreen()));
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'gary@example.test');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrong');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Inline, next to the fields — not in a dialog the user has to dismiss
    // before they can correct their typing.
    expect(find.text('Incorrect email or password'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('says how long to wait when rate-limited', (tester) async {
    harness.http.on('POST', '/auth/login', [
      FakeReply(429, {
        'error': 'Too many sign-in attempts. Try again shortly.',
        'retryAfter': 45,
        'requestId': 'req_test',
      }),
    ]);

    await tester.pumpWidget(harness.wrap(const SignInScreen()));
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'gary@example.test');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'hunter2');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Try again in 45 seconds'), findsOneWidget);
  });

  testWidgets('offers no route to purchasing — guideline 3.1.3(f)', (tester) async {
    await tester.pumpWidget(harness.wrap(const SignInScreen()));

    for (final forbidden in ['Sign up', 'Subscribe', 'Upgrade', 'Pricing', 'Free trial']) {
      expect(
        find.textContaining(forbidden, findRichText: true),
        findsNothing,
        reason: 'the app ships as a free companion to the paid web service',
      );
    }
  });

  testWidgets('the password can be revealed and hidden again', (tester) async {
    await tester.pumpWidget(harness.wrap(const SignInScreen()));

    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('renders in dark mode without unreadable text', (tester) async {
    await tester.pumpWidget(harness.wrap(const SignInScreen(), brightness: Brightness.dark));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sign in'), findsWidgets);
  });
}
