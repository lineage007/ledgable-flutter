import 'dart:async';

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'token_store.dart';

/// Why a session ended, for the message shown on the sign-in screen.
enum SignedOutReason {
  /// The person tapped "Sign out".
  userInitiated,

  /// The refresh chain is gone — expired, revoked, or the device was signed
  /// out from another handset.
  sessionExpired,

  /// The server revoked this device, including the reuse-detection case.
  deviceRevoked,

  /// The account was deleted from this device.
  accountDeleted,
}

/// Owns the device's credentials and the one rule that matters most:
/// **there is never more than one refresh in flight.**
///
/// The server treats a refresh token as single-use and treats presenting a
/// spent one as a compromise, revoking every credential on the device. Two
/// parallel refreshes with the same token therefore do not merely waste a
/// round trip — they sign the user out of their own phone. Everything in this
/// class exists to make that impossible:
///
///  * [_inFlight] holds the single refresh future; concurrent callers await it
///    rather than starting their own.
///  * A caller passes the access token it *failed with*. If the tokens in
///    memory have already moved on, someone else's refresh already fixed it
///    and this caller just uses the result.
///  * The successor pair is written to the store **before** it is published to
///    memory or used for any request, so an app killed mid-rotation comes back
///    holding a usable token instead of a spent one.
class SessionManager {
  SessionManager({required TokenStore store, required Dio refreshClient})
    : _store = store,
      _refreshClient = refreshClient;

  final TokenStore _store;

  /// A Dio instance with **no auth interceptor**. Refreshing through the
  /// authenticated client would recurse: the refresh call would itself try to
  /// attach a token, fail, and refresh again.
  final Dio _refreshClient;

  AuthTokens? _tokens;
  String? _workspaceId;
  bool _restored = false;

  Future<AuthTokens>? _inFlight;

  final _signedOut = StreamController<SignedOutReason>.broadcast();

  /// Emits when the session ends for any reason. The router listens and sends
  /// the user to sign-in; screens do not have to handle it individually.
  Stream<SignedOutReason> get onSignedOut => _signedOut.stream;

  AuthTokens? get tokens => _tokens;

  bool get hasSession => _tokens != null;

  /// Active workspace, sent as `X-Ledgable-Workspace`. Null means "let the
  /// server use the caller's default workspace", which is what a fresh install
  /// does before `/me` has been read.
  String? get workspaceId => _workspaceId;

  /// Read the keychain once per process. Called by the splash screen.
  Future<AuthTokens?> restore() async {
    if (_restored) return _tokens;
    _restored = true;
    final stored = await _store.read();
    _workspaceId = await _store.readWorkspaceId();
    if (stored == null) return null;
    // A dead refresh token cannot be revived, so there is no point starting the
    // app as if signed in and failing on the first call.
    if (stored.isRefreshExpired()) {
      await _store.clear();
      return null;
    }
    _tokens = stored;
    return stored;
  }

  /// Adopt the pair returned by `/auth/login`.
  Future<void> adopt(AuthTokens tokens) async {
    await _store.save(tokens);
    _tokens = tokens;
  }

  Future<String> installId() => _store.installId();

  Future<void> selectWorkspace(String? workspaceId) async {
    _workspaceId = workspaceId;
    await _store.saveWorkspaceId(workspaceId);
  }

  /// The token to put on an outgoing request, refreshing first if the one held
  /// has expired by the clock. Refreshing before the call rather than after a
  /// 401 saves a round trip and, more importantly, keeps the number of
  /// rejected-token responses low enough that a real reuse signal stands out.
  ///
  /// Returns null when there is no session at all.
  Future<AuthTokens?> tokensForRequest() async {
    final current = _tokens;
    if (current == null) return null;
    if (!current.isAccessExpired()) return current;
    try {
      return await refresh(failedAccessToken: current.accessToken);
    } on SessionExpiredException {
      return null;
    }
  }

  /// Exchange the refresh token for a successor.
  ///
  /// [failedAccessToken] is the access token the caller was using when it got a
  /// 401 (or found expired). If the tokens in memory no longer match it, a
  /// refresh has already completed and the current pair is returned untouched —
  /// this is what stops a burst of parallel 401s from each spending a token.
  Future<AuthTokens> refresh({required String failedAccessToken}) {
    final current = _tokens;
    if (current == null) {
      throw const SessionExpiredException('no session');
    }
    if (current.accessToken != failedAccessToken) {
      // Somebody else already rotated. Use theirs.
      return Future.value(current);
    }

    final existing = _inFlight;
    if (existing != null) return existing;

    final attempt = _performRefresh(current).whenComplete(() => _inFlight = null);
    _inFlight = attempt;
    return attempt;
  }

  Future<AuthTokens> _performRefresh(AuthTokens current) async {
    if (current.isRefreshExpired()) {
      await _endSession(SignedOutReason.sessionExpired);
      throw const SessionExpiredException('refresh token expired');
    }

    final Response<dynamic> response;
    try {
      response = await _refreshClient.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': current.refreshToken},
      );
    } on DioException catch (error) {
      final api = ApiException.fromDioException(error);
      // A network failure is not a rejection. Keeping the token means the next
      // attempt can still succeed; clearing it here would sign people out
      // every time they walked into a lift.
      if (api.isNetworkError || (api.statusCode != null && api.statusCode! >= 500)) {
        throw api;
      }
      if (api.isRateLimited) throw api;
      await _endSession(SignedOutReason.sessionExpired);
      throw SessionExpiredException(api.code ?? 'refresh rejected');
    }

    final body = response.data;
    if (body is! Map<String, dynamic>) {
      await _endSession(SignedOutReason.sessionExpired);
      throw const SessionExpiredException('malformed refresh response');
    }

    final next = AuthTokens.fromJson(body);
    // Persist before publishing. If the process dies on the next line, the
    // keychain already holds the successor and the spent token is gone.
    await _store.save(next);
    _tokens = next;
    return next;
  }

  /// Called by the interceptor when the server reports a credential that can
  /// never work again.
  Future<void> handleTerminalAuthFailure(String? code) async {
    await _endSession(
      code == ApiErrorCode.deviceRevoked
          ? SignedOutReason.deviceRevoked
          : SignedOutReason.sessionExpired,
    );
  }

  /// Local teardown after a deliberate sign-out or an account deletion. The
  /// server-side revocation is the caller's job — this only clears the device.
  Future<void> signOutLocally(SignedOutReason reason) => _endSession(reason);

  Future<void> _endSession(SignedOutReason reason) async {
    if (_tokens == null && reason != SignedOutReason.userInitiated) {
      // Already torn down; a second 401 from an in-flight request should not
      // push the user to sign-in twice.
      return;
    }
    _tokens = null;
    _workspaceId = null;
    await _store.clear();
    if (!_signedOut.isClosed) _signedOut.add(reason);
  }

  Future<void> dispose() async {
    await _signedOut.close();
  }
}
