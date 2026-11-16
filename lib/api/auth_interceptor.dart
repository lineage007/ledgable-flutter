import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'session_manager.dart';

/// Per-request flags, set through `Options.extra`.
class RequestFlags {
  const RequestFlags._();

  /// Skip the bearer header entirely — login, refresh, and the logout variant
  /// that presents a refresh token in the body.
  static const skipAuth = 'ledgable.skipAuth';

  /// Do not send `X-Ledgable-Workspace`. Account deletion is an account-level
  /// operation and the spec says to send no workspace header for it: a caller
  /// who never finished setup has no workspace to send.
  static const noWorkspace = 'ledgable.noWorkspace';

  /// Internal marker so a retried request is never retried twice.
  static const retried = 'ledgable.retried';
}

/// Attaches credentials, and implements the client half of the token contract
/// in the spec's "Client token flow".
///
/// The rules, in the order they are applied:
///  1. Before the request: if the held access token has expired by the clock,
///     refresh first (serialised by [SessionManager]).
///  2. On `401 TOKEN_EXPIRED`: refresh once, retry the original request once.
///  3. On `401 REFRESH_REJECTED | INVALID_TOKEN | MISSING_TOKEN |
///     DEVICE_REVOKED`: clear the keychain and surface sign-in. Never retry.
///  4. On `403 WORKSPACE_FORBIDDEN`: the cached workspace is stale. Forget it
///     so the next call falls back to the default workspace, and let the error
///     through so the UI can re-read `/me`.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._session, this._retryClient);

  final SessionManager _session;

  /// A Dio carrying **no interceptors** but the same HTTP adapter as the
  /// authenticated client. Replaying through the authenticated client would
  /// re-enter [onRequest] and refresh a second time; replaying through a
  /// freshly constructed Dio would bypass whatever adapter the app (or a test)
  /// installed.
  final Dio _retryClient;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[RequestFlags.skipAuth] == true) {
      return handler.next(options);
    }

    final tokens = await _session.tokensForRequest();
    if (tokens == null) {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: const SessionExpiredException('no credentials'),
        ),
        true,
      );
    }

    options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';

    final workspaceId = _session.workspaceId;
    if (workspaceId != null && options.extra[RequestFlags.noWorkspace] != true) {
      options.headers['X-Ledgable-Workspace'] = workspaceId;
    }

    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final response = err.response;

    if (response == null || options.extra[RequestFlags.skipAuth] == true) {
      return handler.next(err);
    }

    final api = ApiException.fromDioException(err);

    if (response.statusCode == 403 && api.code == ApiErrorCode.workspaceForbidden) {
      // Stale selection. Dropping it makes the next request use the default
      // workspace rather than repeating a request the server will refuse.
      await _session.selectWorkspace(null);
      return handler.next(err);
    }

    if (response.statusCode != 401) {
      return handler.next(err);
    }

    if (api.isTerminalAuthFailure) {
      await _session.handleTerminalAuthFailure(api.code);
      return handler.next(err);
    }

    if (api.code != ApiErrorCode.tokenExpired) {
      return handler.next(err);
    }

    // One retry, ever. A second 401 on the retried request means something is
    // wrong that another token will not fix.
    if (options.extra[RequestFlags.retried] == true) {
      await _session.handleTerminalAuthFailure(api.code);
      return handler.next(err);
    }

    final presented = _bearerOf(options);
    if (presented == null) return handler.next(err);

    try {
      final refreshed = await _session.refresh(failedAccessToken: presented);
      final retryOptions = options
        ..headers['Authorization'] = 'Bearer ${refreshed.accessToken}'
        ..extra[RequestFlags.retried] = true
        ..data = _replayableBody(options.data);
      final retried = await _retry(retryOptions);
      return handler.resolve(retried);
    } on SessionExpiredException {
      // The session is already torn down by SessionManager; pass the original
      // 401 through so the caller sees a coherent error.
      return handler.next(err);
    } on DioException catch (retryError) {
      // The replay was rejected too. A fresh token did not help, so another
      // refresh will not either — end the session rather than leave the app
      // looping against a credential the server will not accept.
      if (retryError.response?.statusCode == 401) {
        await _session.handleTerminalAuthFailure(ApiException.fromDioException(retryError).code);
      }
      return handler.next(retryError);
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options) => _retryClient.fetch<dynamic>(options);

  /// A receipt upload is `multipart/form-data`, and a [FormData] whose stream
  /// has been read cannot be sent a second time. `clone()` rebuilds it from the
  /// same source — the file on disk — which is why receipt uploads build their
  /// part with `MultipartFile.fromFile` rather than from an in-memory stream.
  static Object? _replayableBody(Object? data) => data is FormData ? data.clone() : data;

  static String? _bearerOf(RequestOptions options) {
    final header = options.headers['Authorization'];
    if (header is! String || !header.startsWith('Bearer ')) return null;
    return header.substring('Bearer '.length);
  }
}
