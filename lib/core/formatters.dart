import 'package:intl/intl.dart';

/// Date and time rendering, Australian conventions throughout: `d MMM yyyy`
/// rather than the US month-first order, because an Australian reading
/// "3/11/2026" and an American reading it disagree by eight months.
class Dates {
  const Dates._();

  static final DateFormat _dayMonth = DateFormat('d MMM', 'en_AU');
  static final DateFormat _full = DateFormat('d MMM yyyy', 'en_AU');
  static final DateFormat _withTime = DateFormat('d MMM yyyy, h:mma', 'en_AU');
  static final DateFormat _monthLabel = DateFormat('MMM', 'en_AU');

  /// Parse an ISO-8601 instant from the API into local time. Returns null
  /// rather than throwing: one unparseable timestamp should cost a date
  /// label, not the whole screen.
  static DateTime? parse(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  static String format(DateTime? value) => value == null ? '—' : _full.format(value);

  static String formatWithTime(DateTime? value) =>
      value == null ? '—' : _withTime.format(value).replaceAll('AM', 'am').replaceAll('PM', 'pm');

  static String formatDayMonth(DateTime? value) => value == null ? '—' : _dayMonth.format(value);

  /// Date-only ISO for request bodies that take a `date-time` but mean a day.
  static String toIso(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day).toIso8601String();

  /// `Today`, `Yesterday`, `3 days ago`, then falls back to a date. Used for
  /// "last updated" labels, where the point is recency rather than precision.
  static String relative(DateTime? value, {DateTime? now}) {
    if (value == null) return '—';
    final reference = now ?? DateTime.now();
    final days = DateTime(
      reference.year,
      reference.month,
      reference.day,
    ).difference(DateTime(value.year, value.month, value.day)).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days > 1 && days < 7) return '$days days ago';
    if (days == -1) return 'Tomorrow';
    if (days < -1 && days > -7) return 'In ${-days} days';
    return _full.format(value);
  }

  /// How long ago, to the minute — for a "last updated 3 min ago" stamp on
  /// cached reads, which the plan requires never be presented as live.
  static String sinceShort(DateTime? value, {DateTime? now}) {
    if (value == null) return 'never';
    final delta = (now ?? DateTime.now()).difference(value);
    if (delta.inSeconds < 45) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    return relative(value, now: now).toLowerCase();
  }

  /// `2026-07` or an ISO instant from `Dashboard.monthlySeries` to `Jul`.
  static String monthLabel(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw.length == 7 ? '$raw-01' : raw);
    if (parsed == null) return raw;
    return _monthLabel.format(parsed);
  }

  /// The Australian financial year an instant falls in: 1 July – 30 June,
  /// rendered as `FY26` for the year ending 30 June 2026.
  static String financialYearLabel(DateTime value) {
    final endYear = value.month >= 7 ? value.year + 1 : value.year;
    return 'FY${endYear % 100}';
  }
}

/// Turns a category or status code into something a person reads.
/// `travel_expenses` → `Travel expenses`, `ACCREC` → `Accrec` is wrong, so
/// known codes are mapped explicitly and only unknown ones are humanised.
String humanise(String? code) {
  if (code == null || code.isEmpty) return '';
  final spaced = code.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  if (spaced.isEmpty) return '';
  // ALL-CAPS enum values read better title-cased word by word.
  final words = spaced.split(RegExp(r'\s+')).map((word) {
    if (word.length <= 3 && word == word.toUpperCase() && !RegExp(r'^[A-Z]{2,3}$').hasMatch(word)) {
      return word;
    }
    final lower = word.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }).toList();
  // Keep GST, ABN, TFN, BSB, PAYG upper-cased — they are initialisms, not words.
  const initialisms = {'Gst', 'Abn', 'Tfn', 'Bsb', 'Payg', 'Bas', 'Usi', 'Ato', 'Id'};
  for (var i = 0; i < words.length; i++) {
    if (initialisms.contains(words[i])) words[i] = words[i].toUpperCase();
  }
  return words.join(' ');
}
