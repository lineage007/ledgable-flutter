import 'package:intl/date_symbol_data_local.dart';
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

  /// [relative], but safe to drop into the middle of a sentence.
  ///
  /// Callers were lower-casing the whole of [relative] to get "due today" —
  /// which also turned "15 Aug 2026" into "15 aug 2026". Only the word forms
  /// are lower-cased here; a real date keeps its capital month.
  static String relativeInline(DateTime? value, {DateTime? now}) {
    final rendered = relative(value, now: now);
    // A rendered date starts with a digit and contains a month abbreviation.
    final isWordForm = !RegExp(r'\d{4}$').hasMatch(rendered);
    return isWordForm ? rendered.toLowerCase() : rendered;
  }

  /// How long ago, to the minute — for a "last updated 3 min ago" stamp on
  /// cached reads, which the plan requires never be presented as live.
  static String sinceShort(DateTime? value, {DateTime? now}) {
    if (value == null) return 'never';
    final delta = (now ?? DateTime.now()).difference(value);
    if (delta.inSeconds < 45) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    return relativeInline(value, now: now);
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
///
/// Sentence case rather than title case — `travel_expenses` becomes
/// "Travel expenses", because "Travel Expenses" reads like a heading in the
/// middle of a list. Australian tax initialisms stay upper-cased: "Gst free
/// sales" is wrong in a way a user notices immediately.
String humanise(String? code) {
  if (code == null || code.isEmpty) return '';
  final spaced = code.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  if (spaced.isEmpty) return '';

  // Initialisms, matched case-insensitively against each word.
  const initialisms = {'gst', 'abn', 'tfn', 'bsb', 'payg', 'bas', 'usi', 'ato', 'stp', 'acn', 'id'};

  final words = spaced.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  for (var i = 0; i < words.length; i++) {
    final lower = words[i].toLowerCase();
    if (initialisms.contains(lower)) {
      words[i] = lower.toUpperCase();
    } else if (i == 0) {
      words[i] = lower[0].toUpperCase() + lower.substring(1);
    } else {
      words[i] = lower;
    }
  }
  return words.join(' ');
}

/// Loads the locale data `en_AU` date formats need.
///
/// Without this, `DateFormat` only knows `en_US` and every Australian date
/// format in this app throws a `LocaleDataException` at runtime. Called once
/// from `main()`, and from test setup.
Future<void> initialiseFormatting() async {
  await initializeDateFormatting('en_AU');
  Intl.defaultLocale = 'en_AU';
}
