import '../api/api_client.dart';
import '../api/models/page.dart';
import '../api/models/transaction.dart';

/// Which slice of the ledger to list.
enum TransactionFilter {
  /// Uncategorised, newest first — the swipe queue. The API's default.
  needsReview,

  /// Everything, for browsing and searching.
  all;

  String get wire => this == TransactionFilter.needsReview ? 'needs_review' : 'all';
}

class TransactionsRepository {
  TransactionsRepository(this._client);

  final ApiClient _client;

  Future<Paged<TransactionRecord>> list({
    TransactionFilter filter = TransactionFilter.needsReview,
    int limit = 25,
    int offset = 0,
    String? search,
  }) async {
    final trimmed = search?.trim();
    final body = await _client.get(
      '/transactions',
      query: {
        'filter': filter.wire,
        'limit': limit,
        'offset': offset,
        // The API caps search at 120 characters and rejects longer, so trim here
        // rather than surfacing a validation error for a paste.
        if (trimmed != null && trimmed.isNotEmpty)
          'search': trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed,
      },
    );
    return Paged<TransactionRecord>(
      items: asMapList(
        body['transactions'],
      ).map(TransactionRecord.fromJson).toList(growable: false),
      page: Page.fromJson(asMap(body['page'])),
    );
  }

  /// The action behind a swipe. Reversible by categorising again, which is what
  /// the returned `previousCategoryCode` is for.
  Future<CategorisationResult> categorise({
    required String transactionId,
    required String categoryCode,
  }) async => CategorisationResult.fromJson(
    await _client.post(
      '/transactions/$transactionId/categorise',
      body: {'categoryCode': categoryCode},
    ),
  );

  /// The categories this workspace actually uses.
  ///
  /// There is no `/categories` endpoint on the mobile API, and category codes
  /// are per-workspace rows rather than a fixed enum, so the client cannot know
  /// them a priori. Sampling the codes already assigned to categorised
  /// transactions is the honest alternative: it can only ever offer a code the
  /// workspace really holds, and the codes in recent use are the ones most
  /// likely wanted next.
  ///
  /// The gap it leaves — a category created on the web but never used cannot be
  /// offered — is why the picker also accepts a code typed by hand, and why a
  /// real endpoint is filed as a handoff.
  Future<List<CategoryOption>> usedCategories({int sample = 100}) async {
    final page = await list(filter: TransactionFilter.all, limit: sample.clamp(1, 100));
    final counts = <String, int>{};
    for (final transaction in page.items) {
      final code = transaction.categoryCode;
      if (code == null || code.isEmpty) continue;
      counts[code] = (counts[code] ?? 0) + 1;
    }
    final options = counts.entries
        .map((entry) => CategoryOption(code: entry.key, usageCount: entry.value))
        .toList();
    // Most-used first, then alphabetically so the order is stable between
    // loads rather than shuffling on every fetch.
    options.sort((a, b) {
      final byUsage = b.usageCount.compareTo(a.usageCount);
      return byUsage != 0 ? byUsage : a.code.compareTo(b.code);
    });
    return options;
  }
}
