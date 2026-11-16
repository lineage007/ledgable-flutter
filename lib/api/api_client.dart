import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'session_manager.dart';
import 'token_store.dart';

/// The HTTP surface of the app.
///
/// Three Dio instances, because the token contract demands it:
///  * [dio] — authenticated calls, carrying [AuthInterceptor].
///  * [authlessDio] — `/auth/login`, `/auth/refresh` and the body-based
///    `/auth/logout`. No interceptor, so refreshing cannot recurse.
///  * an internal retry client — same adapter, no interceptors, used to replay
///    exactly one request after a successful refresh.
///
/// Every method converts a [DioException] into an [ApiException] so no caller
/// above this layer ever imports `dio`.
class ApiClient {
  ApiClient._({
    required this.dio,
    required this.authlessDio,
    required Dio retryDio,
    required this.session,
  }) : _retryDio = retryDio;

  factory ApiClient({TokenStore? store, String? baseUrl}) {
    final root = baseUrl ?? Env.apiRoot;
    final options = BaseOptions(
      baseUrl: root,
      // Generous enough for a slow regional connection, short enough that a
      // dead server does not leave a spinner running for a minute.
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: const {'Accept': 'application/json'},
    );

    final authless = Dio(options.copyWith());
    final retry = Dio(options.copyWith());
    final authed = Dio(options.copyWith());

    final session = SessionManager(store: store ?? SecureTokenStore(), refreshClient: authless);

    authed.interceptors.add(AuthInterceptor(session, retry));
    if (kDebugMode) {
      final logger = _RedactingLogInterceptor();
      authed.interceptors.add(logger);
      authless.interceptors.add(logger);
    }

    return ApiClient._(dio: authed, authlessDio: authless, retryDio: retry, session: session);
  }

  final Dio dio;
  final Dio authlessDio;
  final Dio _retryDio;
  final SessionManager session;

  /// Point every client at one adapter. Tests install a fake here; without
  /// this the retry path would escape to the real network.
  @visibleForTesting
  void useAdapter(HttpClientAdapter adapter) {
    dio.httpClientAdapter = adapter;
    authlessDio.httpClientAdapter = adapter;
    _retryDio.httpClientAdapter = adapter;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool noWorkspace = false,
  }) => _send(
    () => dio.get<dynamic>(
      path,
      queryParameters: _pruned(query),
      options: _options(noWorkspace: noWorkspace),
    ),
  );

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool noWorkspace = false,
    bool skipAuth = false,
    Dio? using,
  }) => _send(
    () => (using ?? dio).post<dynamic>(
      path,
      data: body,
      options: _options(noWorkspace: noWorkspace, skipAuth: skipAuth),
    ),
  );

  Future<Map<String, dynamic>> delete(String path, {Object? body, bool noWorkspace = false}) =>
      _send(
        () => dio.delete<dynamic>(
          path,
          data: body,
          options: _options(noWorkspace: noWorkspace),
        ),
      );

  Future<Map<String, dynamic>> upload(String path, FormData form, {ProgressCallback? onProgress}) =>
      _send(
        () => dio.post<dynamic>(
          path,
          data: form,
          onSendProgress: onProgress,
          options: Options(contentType: 'multipart/form-data'),
        ),
      );

  Options _options({bool noWorkspace = false, bool skipAuth = false}) => Options(
    extra: {
      if (noWorkspace) RequestFlags.noWorkspace: true,
      if (skipAuth) RequestFlags.skipAuth: true,
    },
  );

  /// Drops null query values so `?status=null` never reaches the server, which
  /// validates enums strictly and would reject the literal string.
  static Map<String, dynamic>? _pruned(Map<String, dynamic>? query) {
    if (query == null) return null;
    final pruned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value != null) pruned[key] = value;
    });
    return pruned.isEmpty ? null : pruned;
  }

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      final body = response.data;
      if (body == null) return const {};
      if (body is Map<String, dynamic>) return body;
      if (body is Map) return body.cast<String, dynamic>();
      // An HTML error page from an edge proxy lands here. Better a clear
      // message than a cast error in a widget build.
      throw ApiException(
        message: 'Ledgable returned an unexpected response. Try again.',
        statusCode: response.statusCode,
        requestId: response.headers.value('x-request-id'),
      );
    } on DioException catch (error) {
      if (error.error is SessionExpiredException) {
        throw error.error as SessionExpiredException;
      }
      // A proactive refresh that failed with a 503 or a 429 throws its own
      // ApiException from inside onRequest, and Dio wraps it. Unwrap it rather
      // than re-deriving one from a DioException that has no response attached,
      // which would replace "Ledgable had a problem at its end" with a generic
      // connection message.
      if (error.error is ApiException) {
        throw error.error as ApiException;
      }
      throw ApiException.fromDioException(error);
    }
  }
}

/// Debug-only request log.
///
/// Deliberately not Dio's `LogInterceptor`: that prints headers and bodies,
/// which on this API means printing bearer and refresh tokens into the device
/// console. Method, path and status are enough to debug a call, and the spec
/// is explicit that a token must never be logged.
class _RedactingLogInterceptor extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _log(
      '${response.requestOptions.method} ${response.requestOptions.path} → ${response.statusCode}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final code = err.response?.data is Map ? (err.response!.data as Map)['code'] : null;
    _log(
      '${err.requestOptions.method} ${err.requestOptions.path} → '
      '${err.response?.statusCode ?? err.type.name}${code == null ? '' : ' ($code)'}',
    );
    handler.next(err);
  }

  void _log(String message) => developer.log(message, name: 'ledgable.api');
}
