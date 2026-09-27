import 'package:flutter_test/flutter_test.dart';
import 'package:ledgable_app/api/api_client.dart';
import 'package:ledgable_app/api/api_exception.dart';
import 'package:ledgable_app/api/session_manager.dart';
import 'package:ledgable_app/api/token_store.dart';

import '../support/fake_http.dart';

/// The token contract from docs/mobile/openapi.yaml and PLAN.md §4.
///
/// These are the most important tests in the suite. The server treats a refresh
/// token as single-use and treats a replayed one as a compromise, revoking every
/// credential on the device — so a client bug here does not degrade the
/// experience, it locks people out of their own accounting records.
void main() {
  late FakeHttpAdapter http;
  late InMemoryTokenStore store;
  late ApiClient client;

  AuthTokens tokensExpiring(
    Duration accessTtl, {
    String access = 'access-1',
    String refresh = 'refresh-1',
  }) => AuthTokens(
    accessToken: access,
    accessExpiresAt: DateTime.now().add(accessTtl),
    refreshToken: refresh,
    refreshExpiresAt: DateTime.now().add(const Duration(days: 60)),
    deviceId: 'device-1',
  );

  setUp(() {
    http = FakeHttpAdapter();
    store = InMemoryTokenStore();
    client = ApiClient(store: store, baseUrl: 'https://example.test/api/mobile/v1');
    client.useAdapter(http);
  });

  group('outgoing requests', () {
    test('carries the bearer token and the workspace header', () async {
      await client.session.adopt(tokensExpiring(const Duration(minutes: 15)));
      await client.session.selectWorkspace('ws-1');
      http.on('GET', '/dashboard', [
        FakeReply(200, {'kpis': {}}),
      ]);

      await client.get('/dashboard');

      final request = http.requestsTo('GET', '/dashboard').single;
      expect(request.bearer, 'access-1');
      expect(request.workspaceHeader, 'ws-1');
    });

    test('omits the workspace header when a call is account-scoped', () async {
      await client.session.adopt(tokensExpiring(const Duration(minutes: 15)));
      await client.session.selectWorkspace('ws-1');
      http.on('GET', '/account', [
        FakeReply(200, {'retentionYears': 7}),
      ]);

      await client.get('/account', noWorkspace: true);

      expect(http.requestsTo('GET', '/account').single.workspaceHeader, isNull);
    });

    test('refreshes before the call when the access token has already expired', () async {
      await client.session.adopt(tokensExpiring(const Duration(seconds: -1)));
      http.on('POST', '/auth/refresh', [
        FakeReply(200, tokenPair(access: 'access-2', refresh: 'refresh-2')),
      ]);
      http.on('GET', '/dashboard', [
        FakeReply(200, {'kpis': {}}),
      ]);

      await client.get('/dashboard');

      expect(http.countOf('POST', '/auth/refresh'), 1);
      // The dashboard call must never have gone out with the dead token.
      expect(http.requestsTo('GET', '/dashboard').single.bearer, 'access-2');
    });

    test('treats a token expiring within the guard window as expired', () async {
      // 10 seconds of life left: the server would very likely reject it by the
      // time the request landed, so the client refreshes rather than gambling.
      await client.session.adopt(tokensExpiring(const Duration(seconds: 10)));
      http.on('POST', '/auth/refresh', [
        FakeReply(200, tokenPair(access: 'access-2', refresh: 'refresh-2')),
      ]);
      http.on('GET', '/dashboard', [
        FakeReply(200, {'kpis': {}}),
      ]);

      await client.get('/dashboard');

      expect(http.countOf('POST', '/auth/refresh'), 1);
    });
  });

  group('401 TOKEN_EXPIRED', () {
    test('refreshes once and retries the original request once', () async {
      await client.session.adopt(tokensExpiring(const Duration(minutes: 15)));
      await client.session.selectWorkspace('ws-1');
      http.on('GET', '/dashboard', [
        FakeReply.error(401, code: ApiErrorCode.tokenExpired, message: 'Access token expired'),
        FakeReply(200, {
          'kpis': {'cashPosition': 100},
        }),
      ]);
      http.on('POST', '/auth/refresh', [
        FakeReply(200, tokenPair(access: 'access-2', refresh: 'refresh-2')),
      ]);

      final body = await client.get('/dashboard');

      expect(body['kpis'], isA<Map>());
      expect(http.countOf('POST', '/auth/refresh'), 1);
      final dashboardCalls = http.requestsTo('GET', '/dashboard');
      expect(dashboardCalls, hasLength(2));
      expect(dashboardCalls.first.bearer, 'access-1');
      expect(dashboardCalls.last.bearer, 'access-2', reason: 'the retry must use the new token');
      expect(
        dashboardCalls.last.workspaceHeader,
        'ws-1',
        reason: 'the retry must keep the workspace scoping of the original',
      );
    });

    test('spends the refresh token exactly once and persists its successor', () async {
      await client.session.adopt(tokensExpiring(const Duration(minutes: 15)));
      final savesAfterAdopt = store.saveCount;
      http.on('GET', '/dashboard', [
        FakeReply.error(401, code: ApiErrorCode.tokenExpired),
        FakeReply(200, const {}),
      ]);
      http.on('POST', '/auth/refresh', [
        FakeReply(200, tokenPair(access: 'access-2', refresh: 'refresh-2')),
      ]);

      await client.get('/dashboard');

      final refreshCalls = http.requestsTo('POST', '/auth/refresh');
      expect(refreshCalls, hasLength(1));
      expect(refreshCalls.single.json?['refreshToken'], 'refresh-1');
      expect(
        store.saveCount,
        savesAfterAdopt + 1,
        reason: 'the successor pair must be written to the keychain',
      );
      // Written, not merely held: a cold start must find the new token.
      final persisted = await store.read();
      expect(persisted?.refreshToken, 'refresh-2');
      expect(persisted?.accessToken, 'access-2');
    });

    test('does not attach a bearer token to the refresh call itself', () async {
      await client.session.adopt(tokensExpiring(const Duration(minutes: 15)));
      http.on('GET', '/dashboard', [
        FakeReply.error(401, code: ApiErrorCode.tokenExpired),
        FakeReply(200, const {}),
      ]);
      http.on('POST', '/auth/refresh', [
        FakeReply(200, tokenPair(access: 'access-2', refresh: 'refresh-2')),
      ]);

      await client.get('/dashboard');

      expect(http.requestsTo('POST', '/auth/refresh').single.authorization, isNull);
    });

    test('retries at most once, then ends the session', () async {
      await client.session.adopt(tokensExpiring(const Duration(minutes: 15)));
      // The retried request is rejected too. Another token will not fix this.
      http.on('GET', '/dashboard', [FakeReply.error(401, code: ApiErrorCode.tokenExpired)]);
      http.on('POST', '/auth/refresh', [
        FakeReply(200, tokenPair(access: 'access-2', refresh: 'refresh-2')),
      ]);

      await expectLater(client.get('/dashboard'), throwsA(isA<ApiException>()));

      expect(http.countOf('POST', '/auth/refresh'), 1, reason: 'exactly one refresh, not a loop');
      expect(http.countOf('GET', '/dashboard'), 2, reason: 'original plus one retry, no more');
      expect(client.session.hasSession, isFalse);
    });
  });

  group('concurrency — the rule that matters most', () {
    test('two requests failing at once produce one refresh, not two', () async {
      await client.session.adopt(tokensExpiring(const Duration(minutes: 15)));
      http.on('GET', '/dashboard', [
        FakeReply.error(401, code: ApiErrorCode.tokenExpired),
        FakeReply(200, const {'ok': true}),
      ]);
      http.on('GET', '/approvals', [
        FakeReply.error(401, code: ApiErrorCode.tokenExpired),
        FakeReply(200, const {'ok': true}),
      ]);
      // Hold the refresh open so both 401s are certainly in flight when the
      // second caller asks to refresh.
      final release = http.gate('POST', '/auth/refresh');
      http.on('POST', '/auth/refresh', [
        FakeReply(200, tokenPair(access: 'access-2', refresh: 'refresh-2')),
      ]);

      final calls = Future.wait([client.get('/dashboard'), client.get('/approvals')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      release.complete();
      await calls;

      expect(
        http.countOf('POST', '/auth/refresh'),
        1,
        reason: 'a second exchange would replay a spent token and revoke the device',
      );
      expect(http.requestsTo('GET', '/dashboard').last.bearer, 'access-2');
      expect(http.requestsTo('GET', '/approvals').last.bearer, 'access-2');
    });

    test('a proactive refresh and a 401 refresh do not both fire', () async {
      // Both calls start with a token that is already past its guard window, so
      // both would refresh proactively if the refreshes were not serialised.
      await client.session.adopt(tokensExpiring(const Duration(seconds: -1)));
      final release = http.gate('POST', '/auth/refresh');
      http.on('POST', '/auth/refresh', [
        FakeReply(200, tokenPair(access: 'access-2', refresh: 'refresh-2')),
      ]);
      http.on('GET', '/dashboard', [FakeReply(200, const {})]);
      http.on('GET', '/receipts', [FakeReply(200, const {})]);

      final calls = Future.wait([client.get('/dashboard'), client.get('/receipts')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      release.complete();
      await calls;

      expect(http.countOf('POST', '/auth/refresh'), 1);
    });
  });

  group('terminal failures', () {
    for (final code in [
      ApiErrorCode.refreshRejected,
      ApiErrorCode.invalidToken,
      ApiErrorCode.missingToken,
      ApiErrorCode.deviceRevoked,
    ]) {
      test('$code clears the keychain and does not retry', () async {
        await client.session.adopt(tokensExpiring(const Duration(minutes: 15)));
        final reasons = <SignedOutReason>[];
        client.session.onSignedOut.listen(reasons.add);
        http.on('GET', '/dashboard', [FakeReply.error(401, code: code)]);

        await expectLater(client.get('/dashboard'), throwsA(isA<ApiException>()));
        await Future<void>.delayed(Duration.zero);

        expect(http.countOf('POST', '/auth/refresh'), 0, reason: 'no refresh can fix this');
        expect(http.countOf('GET', '/dashboard'), 1, reason: 'no retry');
        expect(client.session.hasSession, isFalse);
        expect(store.clearCount, greaterThan(0));
        expect(
          reasons.single,
          code == ApiErrorCode.deviceRevoked
              ? SignedOutReason.deviceRevoked
              : SignedOutReason.sessionExpired,
        );
      });
    }

    test('a rejected refresh ends the session', () async {
      await client.session.adopt(tokensExpiring(const Duration(minutes: 15)));
      http.on('GET', '/dashboard', [FakeReply.error(401, code: ApiErrorCode.tokenExpired)]);
      http.on('POST', '/auth/refresh', [FakeReply.error(401, code: ApiErrorCode.refreshRejected)]);

      await expectLater(client.get('/dashboard'), throwsA(isA<ApiException>()));

      expect(client.session.hasSession, isFalse);
      expect(http.countOf('GET', '/dashboard'), 1, reason: 'no retry after a rejected refresh');
    });

    test('a server error during refresh keeps the session — it is not a rejection', () async {
      await client.session.adopt(tokensExpiring(const Duration(seconds: -1)));
      http.on('POST', '/auth/refresh', [
        FakeReply(503, {'error': 'unavailable'}),
      ]);
      http.on('GET', '/dashboard', [FakeReply(200, const {})]);

      await expectLater(client.get('/dashboard'), throwsA(isA<Object>()));

      expect(
        client.session.hasSession,
        isTrue,
        reason: 'a 503 means try again later, not that the credential is dead',
      );
      expect(store.clearCount, 0);
    });

    test('a rate-limited refresh keeps the session', () async {
      await client.session.adopt(tokensExpiring(const Duration(seconds: -1)));
      http.on('POST', '/auth/refresh', [
        FakeReply(429, {'error': 'rate_limited', 'retryAfter': 30}),
      ]);
      http.on('GET', '/dashboard', [FakeReply(200, const {})]);

      await expectLater(client.get('/dashboard'), throwsA(isA<Object>()));

      expect(client.session.hasSession, isTrue);
    });

    test('a refresh token past its own expiry is not presented at all', () async {
      await client.session.adopt(
        AuthTokens(
          accessToken: 'access-1',
          accessExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          refreshToken: 'refresh-1',
          refreshExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
          deviceId: 'device-1',
        ),
      );
      http.on('GET', '/dashboard', [FakeReply(200, const {})]);

      await expectLater(client.get('/dashboard'), throwsA(isA<SessionExpiredException>()));

      expect(
        http.countOf('POST', '/auth/refresh'),
        0,
        reason: 'presenting a dead token cannot succeed and only risks a reuse signal',
      );
      expect(client.session.hasSession, isFalse);
    });
  });

  group('workspace scoping', () {
    test('WORKSPACE_FORBIDDEN drops the stale selection and does not retry', () async {
      await client.session.adopt(tokensExpiring(const Duration(minutes: 15)));
      await client.session.selectWorkspace('ws-stale');
      http.on('GET', '/dashboard', [
        FakeReply.error(403, code: ApiErrorCode.workspaceForbidden, message: 'Not your workspace'),
      ]);

      await expectLater(
        client.get('/dashboard'),
        throwsA(
          isA<ApiException>().having((e) => e.isWorkspaceProblem, 'isWorkspaceProblem', isTrue),
        ),
      );

      expect(
        client.session.workspaceId,
        isNull,
        reason: 'the next call must fall back to the default workspace',
      );
      expect(http.countOf('GET', '/dashboard'), 1);
      expect(client.session.hasSession, isTrue, reason: 'this is not an auth failure');
    });
  });

  group('restore', () {
    test('restores a live session from the store', () async {
      final saved = tokensExpiring(const Duration(minutes: 10));
      final seeded = InMemoryTokenStore(tokens: saved, workspaceId: 'ws-7');
      final restored = ApiClient(store: seeded, baseUrl: 'https://example.test/api/mobile/v1');

      final tokens = await restored.session.restore();

      expect(tokens?.accessToken, 'access-1');
      expect(restored.session.workspaceId, 'ws-7');
    });

    test('discards a stored session whose refresh token has expired', () async {
      final seeded = InMemoryTokenStore(
        tokens: AuthTokens(
          accessToken: 'access-1',
          accessExpiresAt: DateTime.now().subtract(const Duration(days: 61)),
          refreshToken: 'refresh-1',
          refreshExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
          deviceId: 'device-1',
        ),
      );
      final restored = ApiClient(store: seeded, baseUrl: 'https://example.test/api/mobile/v1');

      expect(await restored.session.restore(), isNull);
      expect(seeded.clearCount, 1);
    });
  });

  group('secrets', () {
    test('AuthTokens.toString does not contain either token', () {
      final tokens = tokensExpiring(const Duration(minutes: 15));
      final rendered = tokens.toString();

      expect(rendered, isNot(contains('access-1')));
      expect(rendered, isNot(contains('refresh-1')));
      expect(rendered, contains('device-1'));
    });
  });
}
