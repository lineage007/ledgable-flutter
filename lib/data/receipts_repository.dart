import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../api/api_client.dart';
import '../api/models/page.dart';
import '../api/models/receipt.dart';

class ReceiptsRepository {
  ReceiptsRepository(this._client);

  final ApiClient _client;

  Future<Paged<ReceiptSummary>> list({
    int limit = 25,
    int offset = 0,
    OcrStatus? ocrStatus,
    bool archived = false,
  }) async {
    final body = await _client.get(
      '/receipts',
      query: {
        'limit': limit,
        'offset': offset,
        if (ocrStatus != null) 'ocrStatus': ocrStatus.wire,
        // Sent as the literal string the API's enum accepts. A boolean would
        // serialise to `true`/`false` too, but being explicit here documents that
        // the server rejects anything else rather than guessing.
        'archived': archived ? 'true' : 'false',
      },
    );
    return Paged<ReceiptSummary>(
      items: asMapList(body['receipts']).map(ReceiptSummary.fromJson).toList(growable: false),
      page: Page.fromJson(asMap(body['page'])),
    );
  }

  Future<ReceiptDetail> detail(String receiptId) async =>
      ReceiptDetail.fromJson(await _client.get('/receipts/$receiptId'));

  /// Upload a photographed or chosen receipt.
  ///
  /// The part is built with `MultipartFile.fromFile` rather than from bytes so
  /// that the auth interceptor can clone and replay it if the access token
  /// expired mid-upload — a stream that has already been read cannot be sent
  /// twice.
  ///
  /// Always resolves to a `202`: OCR runs on background compute, so the caller
  /// polls [detail] rather than getting an extraction back here.
  Future<ReceiptUploadAccepted> upload(
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final fileName = file.uri.pathSegments.isEmpty ? 'receipt.jpg' : file.uri.pathSegments.last;
    final form = FormData();
    form.files.add(
      MapEntry(
        'file',
        await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: _mediaTypeFor(fileName),
        ),
      ),
    );

    final body = await _client.upload(
      '/receipts',
      form,
      onProgress: onProgress == null ? null : (sent, total) => onProgress(sent, total),
    );
    return ReceiptUploadAccepted.fromJson(body);
  }

  /// Poll until OCR reaches a terminal state.
  ///
  /// The backoff is the one the spec recommends — 1s, 2s, 4s, then every 5s —
  /// because receipt uploads have their own hourly budget (120) and a tight
  /// poll loop would spend it on a single receipt. [timeout] bounds the wait so
  /// a stuck job shows a "still working" state rather than spinning forever.
  Stream<ReceiptDetail> pollUntilSettled(
    String receiptId, {
    Duration timeout = const Duration(minutes: 2),
  }) async* {
    final deadline = DateTime.now().add(timeout);
    var attempt = 0;

    while (true) {
      final receipt = await detail(receiptId);
      yield receipt;
      if (receipt.ocrStatus.isTerminal) return;
      if (DateTime.now().isAfter(deadline)) return;
      await Future<void>.delayed(delayForAttempt(attempt));
      attempt++;
    }
  }

  /// 1s, 2s, 4s, then 5s for every subsequent attempt.
  static Duration delayForAttempt(int attempt) => switch (attempt) {
    0 => const Duration(seconds: 1),
    1 => const Duration(seconds: 2),
    2 => const Duration(seconds: 4),
    _ => const Duration(seconds: 5),
  };

  /// The API accepts JPEG, PNG, HEIC and PDF. Sending the right content type
  /// matters: the server validates on it, and `image_picker` hands back a
  /// `.heic` on an iPhone set to High Efficiency.
  static MediaType _mediaTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return MediaType('image', 'heic');
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    return MediaType('image', 'jpeg');
  }
}
