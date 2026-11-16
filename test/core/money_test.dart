import 'package:clock/clock.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:ledgable_app/core/formatters.dart';
import 'package:ledgable_app/core/money.dart';

void main() {
  setUpAll(() async {
    // en_AU date symbols are not compiled in by default; the app loads them in
    // main() and the tests must do the same or every DateFormat here throws.
    await initialiseFormatting();
    Intl.defaultLocale = 'en_AU';
  });

  group('parse', () {
    test('reads a fixed-2 API string exactly', () {
      expect(Money.parse('1234.50'), Decimal.parse('1234.50'));
      expect(Money.parse('-89.00'), Decimal.parse('-89.00'));
      expect(Money.parse('0.00'), Decimal.zero);
    });

    test('keeps precision a double would lose', () {
      // Twelve significant digits with cents: outside what an IEEE-754 double
      // holds exactly, which is the whole reason the API sends a string.
      const raw = '9999999999.99';
      final parsed = Money.parse(raw)!;

      expect(parsed.toString(), raw);
      expect(parsed, Decimal.parse(raw));
    });

    test('returns null rather than zero for a missing or malformed figure', () {
      // A malformed amount rendered as $0.00 would read as a real zero balance.
      expect(Money.parse(null), isNull);
      expect(Money.parse(''), isNull);
      expect(Money.parse('  '), isNull);
      expect(Money.parse('not money'), isNull);
    });
  });

  group('cents', () {
    test('converts Transaction.total cents to dollars exactly', () {
      expect(Money.fromCents(123450), Decimal.parse('1234.50'));
      expect(Money.fromCents(-8900), Decimal.parse('-89.00'));
      expect(Money.fromCents(1), Decimal.parse('0.01'));
      expect(Money.fromCents(0), Decimal.zero);
    });

    test('converts dollars to integer cents for invoice line input', () {
      expect(Money.toCents(Decimal.parse('45.00')), 4500);
      expect(Money.toCents(Decimal.parse('0.01')), 1);
      expect(Money.toCents(Decimal.parse('1234.56')), 123456);
    });

    test('refuses to round sub-cent precision away', () {
      // The API rejects a fractional unitPriceCents for the same reason: an app
      // must not silently alter an invoice amount.
      expect(() => Money.toCents(Decimal.parse('10.005')), throwsArgumentError);
      expect(() => Money.toCents(Decimal.parse('0.001')), throwsArgumentError);
    });

    test('round-trips cents through dollars and back', () {
      for (final cents in [0, 1, 99, 100, 123456, -4550]) {
        expect(Money.toCents(Money.fromCents(cents)), cents);
      }
    });
  });

  group('format', () {
    test('renders Australian currency', () {
      expect(Money.format(Decimal.parse('1234.50')), r'$1,234.50');
      expect(Money.format(Decimal.parse('0.00')), r'$0.00');
      expect(Money.format(Decimal.parse('-89.00')), r'-$89.00');
    });

    test('renders a missing amount as an em dash, never as zero', () {
      expect(Money.format(null), '—');
      expect(Money.formatCents(null), '—');
    });

    test('shows an explicit plus only when asked', () {
      expect(Money.format(Decimal.parse('10.00'), showSign: true), r'+$10.00');
      expect(Money.format(Decimal.parse('10.00')), r'$10.00');
      expect(Money.format(Decimal.parse('-10.00'), showSign: true), r'-$10.00');
    });

    test('formats large figures without going through a double', () {
      expect(Money.format(Decimal.parse('9999999999.99')), r'$9,999,999,999.99');
    });

    test('trend percentages are signed, and an em dash when unmeasured', () {
      expect(Money.formatTrendPct(12.44), '+12.4%');
      expect(Money.formatTrendPct(-3), '-3.0%');
      expect(Money.formatTrendPct(0), '0.0%');
      // Null means the server had no comparable prior period. Rendering that as
      // 0% would claim flat performance that was never measured.
      expect(Money.formatTrendPct(null), '—');
    });
  });

  group('dates', () {
    test('formats day-month-year, not the US order', () {
      expect(Dates.format(DateTime(2026, 11, 3)), '3 Nov 2026');
    });

    test('date-only ISO drops the local time component', () {
      expect(Dates.toIso(DateTime(2026, 7, 1, 23, 45)), '2026-07-01T00:00:00.000Z');
    });

    test('labels the Australian financial year by the year it ends', () {
      // 1 July starts a new FY; 30 June is still the old one.
      expect(Dates.financialYearLabel(DateTime(2026, 7, 1)), 'FY27');
      expect(Dates.financialYearLabel(DateTime(2026, 6, 30)), 'FY26');
      expect(Dates.financialYearLabel(DateTime(2026, 1, 15)), 'FY26');
    });

    test('relative labels read naturally near today', () {
      final now = DateTime(2026, 9, 27, 12);
      expect(Dates.relative(DateTime(2026, 9, 27, 8), now: now), 'Today');
      expect(Dates.relative(DateTime(2026, 9, 26), now: now), 'Yesterday');
      expect(Dates.relative(DateTime(2026, 9, 24), now: now), '3 days ago');
      expect(Dates.relative(DateTime(2026, 9, 28), now: now), 'Tomorrow');
      expect(Dates.relative(DateTime(2026, 8, 1), now: now), '1 Aug 2026');
    });

    test('the inline form lowercases only the word forms, never a month', () {
      final now = DateTime(2026, 9, 27, 12);
      // "Due today" reads correctly mid-sentence…
      expect(Dates.relativeInline(DateTime(2026, 9, 27), now: now), 'today');
      expect(Dates.relativeInline(DateTime(2026, 9, 24), now: now), '3 days ago');
      // …but "Due 15 aug 2026" does not.
      expect(Dates.relativeInline(DateTime(2026, 8, 15), now: now), '15 Aug 2026');
    });

    test('without an explicit now, relative dates follow the ambient clock', () {
      // Screens call these with no `now`, so the goldens rely on this to pin
      // the day. If it reads the wall clock again they drift a week later.
      withClock(Clock.fixed(DateTime(2026, 9, 27, 12)), () {
        expect(Dates.relative(DateTime(2026, 9, 24)), '3 days ago');
        expect(Dates.sinceShort(DateTime(2026, 9, 27, 11, 50)), '10 min ago');
      });
    });

    test('day counts survive a daylight saving change', () {
      // Sydney clocks go forward on 4 Oct 2026, so local midnight 4 Oct to
      // local midnight 5 Oct is 23 hours. Counting elapsed hours called
      // yesterday "Today". Run under TZ=Australia/Sydney to exercise it; in a
      // zone without DST it passes either way.
      final now = DateTime(2026, 10, 5, 9);
      expect(Dates.relative(DateTime(2026, 10, 4, 9), now: now), 'Yesterday');
      expect(Dates.relative(DateTime(2026, 10, 1), now: now), '4 days ago');
      // Forward across the same change: 3 Oct to 5 Oct is 47 hours.
      expect(Dates.relative(DateTime(2026, 10, 5), now: DateTime(2026, 10, 3, 9)), 'In 2 days');
    });

    test('adding days lands on the same calendar day across DST', () {
      // 14-day terms from 1 Apr 2026 cross the 5 Apr change. Adding 14×24h to
      // local midnight gave 11pm on 14 Apr: due a day early.
      expect(Dates.addDays(DateTime(2026, 4, 1), 14), DateTime(2026, 4, 15));
      expect(Dates.addDays(DateTime(2026, 9, 30, 15, 30), 14), DateTime(2026, 10, 14));
    });

    test('humanise keeps Australian tax initialisms upper-cased', () {
      expect(humanise('travel_expenses'), 'Travel expenses');
      expect(humanise('gst_free_sales'), 'GST free sales');
      expect(humanise('payg_withholding'), 'PAYG withholding');
      expect(humanise(null), '');
    });
  });
}
