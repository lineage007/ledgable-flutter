import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgable_app/api/api_client.dart';
import 'package:ledgable_app/api/api_exception.dart';
import 'package:ledgable_app/api/token_store.dart';
import 'package:ledgable_app/app.dart';
import 'package:ledgable_app/state/providers.dart';
import 'package:ledgable_app/ui/screens/dashboard_screen.dart';
import 'package:ledgable_app/ui/screens/sign_in_screen.dart';

import '../support/fake_http.dart';
import '../support/fixtures.dart';
import '../support/harness.dart';

/// The router is the single place that decides whether the app shows the
/// splash, sign-in, or the signed-in shell. Nothing else pushes to sign-in, so
/// if this is wrong a 401 anywhere in the app has nowhere to land.
void main() {
  setUpAll(setUpFormatting);

  late FakeHttpAdapter http;
  late InMemoryTokenStore store;
  late ApiClient client;

  ApiClient buildClient() {
    client = ApiClient(store: store, baseUrl: 'https://example.test/api/mobile/v1');
    client.useAdapter(http);
    return client;
  }

  Widget bootApp() => ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(buildClient())],
    child: const _BootHarness(),
  );

  AuthTokens liveTokens() => AuthTokens(
    accessToken: 'access-1',
    accessExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
    refreshToken: 'refresh-1',
    refreshExpiresAt: DateTime.now().add(const Duration(days: 60)),
    deviceId: 'device-1',
  );

  Map<String, dynamic> mePayload() => {
    'user': {'id': 'u-1', 'email': 'gary@saltandstone.test', 'name': 'Gary Cakir'},
    'device': {'id': 'device-1', 'installId': 'install-1', 'platform': 'IOS'},
    'workspace': {
      'id': 'ws-1',
      'name': 'Salt & Stone Pty Ltd',
      'kind': 'BUSINESS',
      'status': 'ACTIVE',
      'ownerUserId': 'u-1',
    },
    'membership': {'id': 'm-1', 'role': 'OWNER', 'isDefault': true},
    'workspaces': [
      {'id': 'ws-1', 'name': 'Salt & Stone Pty Ltd', 'role': 'OWNER', 'isDefault': true},
    ],
    'permissions': ['READ', 'WRITE'],
  };

  setUp(() {
    http = FakeHttpAdapter();
    store = InMemoryTokenStore();
  });

  testWidgets('a cold start with no credentials lands on sign in', (tester) async {
    await tester.pumpWidget(bootApp());
    await settleWithNetwork(tester);

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(http.countOf('GET', '/me'), 0, reason: 'nothing to bootstrap');
  });

  testWidgets('a cold start with stored credentials reads /me and lands on home', (tester) async {
    store = InMemoryTokenStore(tokens: liveTokens(), workspaceId: 'ws-1');
    http.on('GET', '/me', [FakeReply(200, mePayload())]);
    http.on('GET', '/dashboard', [FakeReply(200, dashboardPayload())]);

    await tester.pumpWidget(bootApp());
    await settleWithNetwork(tester);

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('Salt & Stone Pty Ltd'), findsWidgets);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('the workspace header follows the workspace /me reports', (tester) async {
    // A stale cached id would 403 every call; the controller re-pins it on load.
    store = InMemoryTokenStore(tokens: liveTokens(), workspaceId: 'ws-gone');
    http.on('GET', '/me', [FakeReply(200, mePayload())]);
    http.on('GET', '/dashboard', [FakeReply(200, dashboardPayload())]);

    await tester.pumpWidget(bootApp());
    await settleWithNetwork(tester);

    expect(client.session.workspaceId, 'ws-1');
    expect(http.requestsTo('GET', '/dashboard').single.workspaceHeader, 'ws-1');
  });

  testWidgets('credentials rejected during bootstrap send the user to sign in', (tester) async {
    store = InMemoryTokenStore(tokens: liveTokens());
    http.on('GET', '/me', [FakeReply.error(401, code: ApiErrorCode.deviceRevoked)]);

    await tester.pumpWidget(bootApp());
    await settleWithNetwork(tester);

    expect(find.byType(SignInScreen), findsOneWidget);
    // And it says why, rather than looking like an unexplained sign-out.
    expect(find.textContaining('This device was signed out'), findsOneWidget);
    expect(store.clearCount, greaterThan(0));
  });

  testWidgets('a network failure during bootstrap offers a retry, not a sign-in', (tester) async {
    // The credentials are fine; only the connection failed. Sending the user
    // back to sign-in would make them re-enter a password for no reason.
    store = InMemoryTokenStore(tokens: liveTokens());
    http.on('GET', '/me', [
      FakeReply(503, {'error': 'unavailable'}),
    ]);

    await tester.pumpWidget(bootApp());
    await settleWithNetwork(tester);

    expect(find.byType(SignInScreen), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    expect(client.session.hasSession, isTrue);
  });

  testWidgets('a successful sign in moves to home without a manual navigation', (tester) async {
    http.on('POST', '/auth/login', [
      FakeReply(200, {
        ...tokenPair(access: 'access-1', refresh: 'refresh-1'),
        'user': {'id': 'u-1', 'email': 'gary@saltandstone.test', 'name': 'Gary Cakir'},
      }),
    ]);
    http.on('GET', '/me', [FakeReply(200, mePayload())]);
    http.on('GET', '/dashboard', [FakeReply(200, dashboardPayload())]);

    await tester.pumpWidget(bootApp());
    await settleWithNetwork(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'gary@saltandstone.test');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'hunter2');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await settleWithNetwork(tester);

    expect(find.byType(DashboardScreen), findsOneWidget);
    // The device descriptor went with the credentials.
    final login = http.requestsTo('POST', '/auth/login').single.json!;
    expect((login['device'] as Map)['installId'], isNotEmpty);
    expect((login['device'] as Map)['platform'], anyOf('IOS', 'ANDROID'));
  });

  testWidgets('a 401 after the app is running returns it to sign in', (tester) async {
    store = InMemoryTokenStore(tokens: liveTokens(), workspaceId: 'ws-1');
    http.on('GET', '/me', [FakeReply(200, mePayload())]);
    http.on('GET', '/dashboard', [
      FakeReply(200, dashboardPayload()),
      FakeReply.error(401, code: ApiErrorCode.refreshRejected),
    ]);

    await tester.pumpWidget(bootApp());
    await settleWithNetwork(tester);
    expect(find.byType(DashboardScreen), findsOneWidget);

    // Pull to refresh, which now fails terminally.
    await tester.fling(find.byType(RefreshIndicator), const Offset(0, 320), 1000);
    await settleWithNetwork(tester);

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.textContaining('session expired'), findsOneWidget);
  });
}

/// Mirrors what `main()` does: kicks off the bootstrap, then shows the app.
class _BootHarness extends ConsumerStatefulWidget {
  const _BootHarness();

  @override
  ConsumerState<_BootHarness> createState() => _BootHarnessState();
}

class _BootHarnessState extends ConsumerState<_BootHarness> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) => const LedgableApp();
}
