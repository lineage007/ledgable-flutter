import 'package:decimal/decimal.dart';
import 'package:decimal/intl.dart';
import 'package:intl/intl.dart';

/// Money handling for the mobile client.
///
/// The API sends dollar amounts as fixed-2 **strings** (`"1234.50"`) because
/// `Decimal(12,2)` values exceed what an IEEE-754 double represents exactly,
/// and Dart's `double` has the same limitation. Parsing one into a `double`
/// anywhere in this app would reintroduce the loss the API was shaped to
/// avoid, so every dollar figure goes through [parse] into a [Decimal] and is
/// rendered by [format], which formats the `Decimal` directly rather than via
/// `toDouble()`.
///
/// Two exceptions, both explicit in the spec:
///  * `Transaction.total` and invoice line `unitPriceCents` are integer cents.
///  * `Dashboard.kpis` are JSON numbers — display aggregates, not postings.
class Money {
  const Money._();

  static final DecimalFormatter _aud = DecimalFormatter(
    NumberFormat.currency(locale: 'en_AU', symbol: r'$', decimalDigits: 2),
  );

  static final NumberFormat _audDouble = NumberFormat.currency(
    locale: 'en_AU',
    symbol: r'$',
    decimalDigits: 2,
  );

  static final NumberFormat _audWhole = NumberFormat.currency(
    locale: 'en_AU',
    symbol: r'$',
    decimalDigits: 0,
  );

  static final Decimal _hundred = Decimal.fromInt(100);

  /// Parse a money value from the API. Returns null for null, empty, and for
  /// anything unparseable — a malformed figure must not render as `$0.00`,
  /// which would read as a real balance of zero.
  static Decimal? parse(Object? raw) {
    if (raw == null) return null;
    if (raw is Decimal) return raw;
    if (raw is int) return Decimal.fromInt(raw);
    if (raw is double) return Decimal.parse(raw.toString());
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return Decimal.tryParse(text);
  }

  /// Integer cents (`Transaction.total`) to dollars. Exact: a division by 100
  /// terminates, so there is no rounding decision to make here.
  static Decimal fromCents(int cents) =>
      (Decimal.fromInt(cents) / _hundred).toDecimal(scaleOnInfinitePrecision: 2);

  /// Dollars to integer cents for invoice line input. Throws rather than
  /// rounds when the value carries sub-cent precision — the API rejects a
  /// fractional `unitPriceCents` for the same reason: an app must not
  /// silently alter an invoice amount.
  static int toCents(Decimal dollars) {
    final cents = dollars * _hundred;
    if (!cents.isInteger) {
      throw ArgumentError.value(
        dollars.toString(),
        'dollars',
        'carries sub-cent precision and cannot be sent as integer cents',
      );
    }
    return cents.toBigInt().toInt();
  }

  /// `$1,234.50`. Null renders as an em dash, never as a zero.
  static String format(Decimal? value, {bool showSign = false}) {
    if (value == null) return '—';
    final formatted = _aud.format(value);
    if (showSign && value > Decimal.zero) return '+$formatted';
    return formatted;
  }

  static String formatCents(int? cents, {bool showSign = false}) =>
      cents == null ? '—' : format(fromCents(cents), showSign: showSign);

  /// Dashboard KPIs arrive as JSON numbers. They are display aggregates, so a
  /// double is acceptable here and only here. [whole] drops the cents, which
  /// is what a KPI tile wants once a figure runs to five digits.
  static String formatDouble(num? value, {bool whole = false}) {
    if (value == null) return '—';
    if (whole || value.abs() >= 100000) return _audWhole.format(value);
    return _audDouble.format(value);
  }

  /// A signed percentage for trend labels: `+12.4%`, `-3.0%`, `—` when the
  /// server could not compute one (no comparable prior period).
  static String formatTrendPct(num? pct) {
    if (pct == null) return '—';
    final sign = pct > 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }
}
