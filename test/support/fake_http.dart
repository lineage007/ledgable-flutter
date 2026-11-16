import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// One canned HTTP reply.
class FakeReply {
  FakeReply(this.statusCode, this.body, {this.headers = const {}, this.delay = Duration.zero});

  /// A JSON error body in the API's shape.
  factory FakeReply.error(
    int statusCode, {
    required String code,
    String message = 'Something went wrong',
    Map<String, dynamic>? details,
  }) => FakeReply(statusCode, {
    'error': message,
    'code': code,
    'requestId': 'req_test',
    'details': ?details,
  });

  final int statusCode;
  final Object? body;
  final Map<String, List<String>> headers;
  final Duration delay;
}

/// One observed request, for assertions.
class RecordedRequest {
  RecordedRequest(this.method, this.path, this.headers, this.body, this.query);

  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final Object? body;
  final Map<String, dynamic> query;

  String? get authorization => headers['Authorization']?.toString();

  String? get bearer {
    final header = authorization;
    if (header == null || !header.startsWith('Bearer ')) return null;
    return header.substring('Bearer '.length);
  }

  String? get workspaceHeader => headers['X-Ledgable-Workspace']?.toString();

  /// The decoded JSON body, when there was one.
  Map<String, dynamic>? get json {
    final data = body;
    if (data is Map<String, dynamic>) return data;
    if (data is String && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      return decoded is Map<String, dynamic> ? decoded : null;
    }
    return null;
  }

  @override
  String toString() => '$method $path';
}

/// A Dio adapter that answers from a script instead of the network.
///
/// Replies are queued per `METHOD /path`; each call to the same key consumes
/// the next queued reply, which is what makes "expired, then refreshed, then
/// fine" testable. A key with one reply left repeats it, so a poll loop does
/// not need a reply per iteration.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter();

  final Map<String, List<FakeReply>> _replies = {};
  final List<RecordedRequest> requests = [];

  /// Set to have every matching request block until the returned completer is
  /// completed — used to hold a refresh in flight while a second caller
  /// arrives.
  final Map<String, Completer<void>> gates = {};

  void on(String method, String path, List<FakeReply> replies) {
    _replies['${method.toUpperCase()} $path'] = List.of(replies);
  }

  /// Blocks matching requests until the returned completer is completed.
  Completer<void> gate(String method, String path) {
    final completer = Completer<void>();
    gates['${method.toUpperCase()} $path'] = completer;
    return completer;
  }

  List<RecordedRequest> requestsTo(String method, String path) => requests
      .where((request) => request.method == method.toUpperCase() && request.path == path)
      .toList(growable: false);

  int countOf(String method, String path) => requestsTo(method, path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method.toUpperCase()} ${options.path}';

    // Dio hands every body over as a stream, so drain it here. A JSON body is
    // recorded as its text so assertions can read the fields; a multipart body
    // is recorded as its byte count, which is what proves a replayed upload was
    // rebuilt rather than reused.
    Object? body = options.data;
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      final bytes = chunks.expand((chunk) => chunk).toList();
      final contentType = options.contentType ?? '';
      body = contentType.startsWith('multipart/')
          ? 'stream:${bytes.length}'
          : utf8.decode(bytes, allowMalformed: true);
    }

    requests.add(
      RecordedRequest(
        options.method.toUpperCase(),
        options.path,
        Map<String, dynamic>.from(options.headers),
        body,
        Map<String, dynamic>.from(options.queryParameters),
      ),
    );

    final held = gates[key];
    if (held != null) await held.future;

    final queue = _replies[key];
    if (queue == null || queue.isEmpty) {
      return ResponseBody.fromString(
        jsonEncode({'error': 'No fake reply scripted for $key', 'requestId': 'req_test'}),
        501,
        headers: _jsonHeaders(),
      );
    }

    // Keep the last reply in place so repeated polling works.
    final reply = queue.length == 1 ? queue.first : queue.removeAt(0);
    if (reply.delay > Duration.zero) await Future<void>.delayed(reply.delay);

    return ResponseBody.fromString(
      reply.body == null ? '' : jsonEncode(reply.body),
      reply.statusCode,
      headers: {..._jsonHeaders(), ...reply.headers},
    );
  }

  static Map<String, List<String>> _jsonHeaders() => {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    'x-request-id': ['req_test'],
  };

  @override
  void close({bool force = false}) {}
}

/// Token-pair JSON in the shape `/auth/login` and `/auth/refresh` return.
Map<String, dynamic> tokenPair({
  required String access,
  required String refresh,
  int expiresIn = 900,
  String deviceId = 'device-1',
  Duration refreshTtl = const Duration(days: 60),
}) => {
  'accessToken': access,
  'tokenType': 'Bearer',
  'expiresIn': expiresIn,
  'refreshToken': refresh,
  'refreshExpiresAt': DateTime.now().toUtc().add(refreshTtl).toIso8601String(),
  'deviceId': deviceId,
};
