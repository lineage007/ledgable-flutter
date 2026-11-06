import 'package:dio/dio.dart';

/// Stable machine-readable error codes from the mobile API.
///
/// The spec is explicit that clients must branch on `code` and never on the
/// message string, so these are the only values any control flow in this app
/// is allowed to test against.
class ApiErrorCode {
  const ApiErrorCode._();

  static const validationError = 'VALIDATION_ERROR';
  static const invalidCredentials = 'INVALID_CREDENTIALS';

  /// Refresh once and retry the original request.
  static const tokenExpired = 'TOKEN_EXPIRED';

  /// Terminal: clear the keychain and show sign-in. Do not retry.
  static const refreshRejected = 'REFRESH_REJECTED';
  static const invalidToken = 'INVALID_TOKEN';
  static const missingToken = 'MISSING_TOKEN';
  static const deviceRevoked = 'DEVICE_REVOKED';

  /// The cached workspace id is stale: re-fetch `/me` and re-select.
  static const workspaceForbidden = 'WORKSPACE_FORBIDDEN';
  static const noWorkspace = 'NO_WORKSPACE';

  static const notFound = 'NOT_FOUND';
  static const toolError = 'TOOL_ERROR';
  static const fileTooLarge = 'FILE_TOO_LARGE';

  /// Codes that mean the device's credentials are gone for good.
  static const terminalAuthCodes = <String>{
    refreshRejected,
    invalidToken,
    missingToken,
    deviceRevoked,
  };
}

/// One field-level problem from a `VALIDATION_ERROR` response.
class ApiFieldIssue {
  const ApiFieldIssue({required this.path, required this.message});

  /// Dotted field path, or `(root)`.
  final String path;
  final String message;

  static List<ApiFieldIssue> fromDetails(Object? details) {
    if (details is! Map) return const [];
    final issues = details['issues'];
    if (issues is! List) return const [];
    return issues
        .whereType<Map>()
        .map(
          (issue) => ApiFieldIssue(
            path: issue['path']?.toString() ?? '(root)',
            message: issue['message']?.toString() ?? 'Invalid value',
          ),
        )
        .toList(growable: false);
  }

  @override
  String toString() => '$path: $message';
}

/// Everything the UI needs to tell a person what went wrong.
///
/// [message] is the server's own `error` string, which the API documents as
/// safe to show verbatim. [requestId] is surfaced on error screens because
/// support cannot trace a report without it.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.requestId,
    this.issues = const [],
    this.retryAfter,
    this.isNetworkError = false,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final String? requestId;
  final List<ApiFieldIssue> issues;

  /// Seconds to wait, from a `429`.
  final int? retryAfter;

  /// No response at all — aeroplane mode, captive portal, server unreachable.
  /// Worth distinguishing because the remedy is "try again", not "fix this".
  final bool isNetworkError;

  bool get isUnauthorised => statusCode == 401;

  bool get isRateLimited => statusCode == 429;

  bool get isTerminalAuthFailure => code != null && ApiErrorCode.terminalAuthCodes.contains(code);

  bool get isWorkspaceProblem =>
      code == ApiErrorCode.workspaceForbidden || code == ApiErrorCode.noWorkspace;

  /// A single line for a toast or an inline error. Field issues are folded in
  /// because a bare "Invalid request" tells the user nothing actionable.
  String get displayMessage {
    if (issues.isEmpty) return message;
    final detail = issues.map((issue) => issue.message).join('. ');
    return message.endsWith('.') ? '$message $detail' : '$message: $detail';
  }

  /// Builds an [ApiException] from whatever Dio surfaced. Tolerant by design:
  /// a proxy or an edge error page can return HTML where JSON was expected,
  /// and that must still produce a readable message rather than a crash.
  factory ApiException.fromDioException(DioException error) {
    final response = error.response;

    if (response == null) {
      final offline = switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'The connection timed out. Check your signal and try again.',
        DioExceptionType.connectionError =>
          'Cannot reach Ledgable. Check your connection and try again.',
        DioExceptionType.cancel => 'Request cancelled.',
        _ => 'Something went wrong reaching Ledgable. Try again.',
      };
      return ApiException(message: offline, isNetworkError: error.type != DioExceptionType.cancel);
    }

    final requestId = response.headers.value('x-request-id');
    final body = response.data;

    if (body is Map) {
      final retryAfterRaw = body['retryAfter'] ?? response.headers.value('retry-after');
      return ApiException(
        message: (body['error'] ?? body['message'] ?? _fallbackFor(response.statusCode)).toString(),
        code: body['code']?.toString(),
        statusCode: response.statusCode,
        requestId: (body['requestId'] ?? requestId)?.toString(),
        issues: ApiFieldIssue.fromDetails(body['details']),
        retryAfter: retryAfterRaw == null ? null : int.tryParse(retryAfterRaw.toString()),
      );
    }

    return ApiException(
      message: _fallbackFor(response.statusCode),
      statusCode: response.statusCode,
      requestId: requestId,
    );
  }

  static String _fallbackFor(int? status) => switch (status) {
    400 => 'That request was not valid.',
    401 => 'Your session has expired. Sign in again.',
    403 => 'You do not have permission to do that.',
    404 => 'That could not be found.',
    429 => 'Too many requests. Wait a moment and try again.',
    final int code when code >= 500 => 'Ledgable had a problem at its end. Try again shortly.',
    _ => 'Something went wrong. Try again.',
  };

  @override
  String toString() => 'ApiException(${code ?? statusCode}): $message';
}

/// The device's credentials are gone and the only remedy is signing in again.
/// Thrown by the refresh path so callers can distinguish "retry this" from
/// "there is no session any more".
class SessionExpiredException implements Exception {
  const SessionExpiredException([this.reason]);

  final String? reason;

  @override
  String toString() => 'SessionExpiredException(${reason ?? 'refresh rejected'})';
}
