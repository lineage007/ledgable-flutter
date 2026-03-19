import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class MoneyRulesScreen extends StatelessWidget {
  const MoneyRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rules = [
      ('Operating Costs', 40, 38, kTeal, '⚙️'),
      ('Tax Reserve', 25, 22, kAmber, '🏛️'),
      ('Owner Pay', 20, 21, const Color(0xFF6366F1), '👤'),
      ('Growth Fund', 15, 19, const Color(0xFFEC4899), '📈'),
    ];
    const revenue = 42500.0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Money Rules™', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('March 2026 · Revenue: \$42,500', style: GoogleFonts.inter(fontSize: 13, color: kTextTertiary)),
            ]),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kTeal, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
          ]),
          const SizedBox(height: 20),

          // Allocation bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Revenue Allocation', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: kTextTertiary)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 14,
                  child: Row(children: rules.map((r) => Expanded(
                    flex: r.$2,
                    child: Container(color: r.$4),
                  )).toList()),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 14, runSpacing: 6, children: rules.map((r) => Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: r.$4, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Text('${r.$1} (${r.$2}%)', style: GoogleFonts.inter(fontSize: 11, color: kTextSecondary)),
              ])).toList()),
            ]),
          ),
          const SizedBox(height: 16),

          // Rule cards
          ...rules.map((r) {
            final ratio = r.$3 / r.$2;
            final over = r.$3 > r.$2;
            final barColor = over ? kError : ratio > 0.9 ? kAmber : kSuccess;
            final target = revenue * r.$2 / 100;
            final actual = revenue * r.$3 / 100;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: r.$4.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text(r.$5, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.$1, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
                    Text('${r.$2}% of revenue', style: GoogleFonts.inter(fontSize: 12, color: kTextTertiary)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: barColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(over ? Icons.warning_rounded : Icons.check_circle_rounded, size: 14, color: barColor),
                      const SizedBox(width: 4),
                      Text('${over ? "+" : ""}${r.$3 - r.$2}%', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: barColor)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 8,
                    child: LinearProgressIndicator(
                      value: (ratio).clamp(0.0, 1.0),
                      backgroundColor: kBg,
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Actual: ${r.$3}%', style: GoogleFonts.inter(fontSize: 11, color: kTextTertiary)),
                  Text('Target: ${r.$2}%', style: GoogleFonts.inter(fontSize: 11, color: kTextTertiary)),
                ]),
                const SizedBox(height: 12),
                // Amounts
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Target', style: GoogleFonts.inter(fontSize: 10, color: kTextTertiary)),
                    Text('\$${target.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary)),
                  ])),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Actual', style: GoogleFonts.inter(fontSize: 10, color: kTextTertiary)),
                    Text('\$${actual.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: over ? kError : r.$4)),
                  ])),
                ]),
              ]),
            );
          }),

          // AI Insight
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kTealDark, kTeal700]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: kTeal700, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.auto_awesome_rounded, color: kAmber, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AI Insight', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  'Growth Fund is 4% over target. Consider redirecting \$1,700 to Tax Reserve — BAS due in 41 days.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF99F6E4), height: 1.5),
                ),
              ])),
            ]),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}
