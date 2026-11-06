/// The `Page` envelope every list endpoint returns.
class Page {
  const Page({
    required this.limit,
    required this.offset,
    required this.total,
    required this.hasMore,
  });

  final int limit;
  final int offset;
  final int total;
  final bool hasMore;

  /// Offset to request next, or null when the list is exhausted.
  int? get nextOffset => hasMore ? offset + limit : null;

  static const empty = Page(limit: 25, offset: 0, total: 0, hasMore: false);

  factory Page.fromJson(Map<String, dynamic>? json) {
    if (json == null) return empty;
    return Page(
      limit: _int(json['limit'], 25),
      offset: _int(json['offset'], 0),
      total: _int(json['total'], 0),
      hasMore: json['hasMore'] == true,
    );
  }

  static int _int(Object? value, int fallback) =>
      value is int ? value : int.tryParse('$value') ?? fallback;
}

/// A page of results plus its envelope, so a list screen can decide whether to
/// keep paging without a second type per endpoint.
class Paged<T> {
  const Paged({required this.items, required this.page});

  final List<T> items;
  final Page page;

  static Paged<T> empty<T>() => Paged<T>(items: const [], page: Page.empty);

  Paged<T> followedBy(Paged<T> next) => Paged<T>(items: [...items, ...next.items], page: next.page);

  bool get isEmpty => items.isEmpty;
}

/// Shared JSON coercion helpers.
///
/// Every model reads through these rather than casting, because one unexpected
/// null from the API must cost a field, not a whole screen. A Flutter app that
/// throws inside a `fromJson` shows a red error box; one that tolerates the
/// null shows the rest of the receipt.
String? asString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

String asStringOr(Object? value, String fallback) => asString(value) ?? fallback;

int? asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is String) {
    if (value == 'true') return true;
    if (value == 'false') return false;
  }
  return fallback;
}

Map<String, dynamic>? asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is! List) return const [];
  return value.map(asMap).whereType<Map<String, dynamic>>().toList(growable: false);
}

List<String> asStringList(Object? value) {
  if (value is! List) return const [];
  return value.map(asString).whereType<String>().toList(growable: false);
}
