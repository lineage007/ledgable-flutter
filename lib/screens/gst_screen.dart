import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class GSTScreen extends StatelessWidget {
  const GSTScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('GST & BAS', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Q3 FY26 · Jan–Mar 2026', style: GoogleFonts.inter(fontSize: 13, color: kTextTertiary)),
          const SizedBox(height: 20),

          // Quarter selector
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['Q3 (Current)', 'Q2', 'Q1', 'Q4 FY25'].map((q) {
                final active = q.contains('Current');
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? kTeal : kWhite,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: active ? kTeal : kBorder),
                    ),
                    child: Text(q, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : kTextSecondary)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Summary cards
          Row(children: [
            Expanded(child: _GSTCard('Collected', '\$4,280', kTeal, Icons.trending_up_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _GSTCard('Credits', '-\$1,843', kSuccess, Icons.trending_down_rounded)),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kAmberLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kAmber.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: kAmberDark),
                const SizedBox(width: 8),
                Text('Net GST Owing', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: kAmberDark)),
              ]),
              const SizedBox(height: 8),
              Text('\$2,437.50', style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, color: kAmberDark)),
              const SizedBox(height: 4),
              Text('BAS due April 28, 2026', style: GoogleFonts.inter(fontSize: 12, color: kAmberDark.withValues(alpha: 0.7))),
            ]),
          ),
          const SizedBox(height: 20),

          // Prepare BAS CTA
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kTealDark, kTeal700]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              Text('Your Q3 BAS is ready', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 6),
              Text('All transactions classified. Review and lodge.', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF99F6E4))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: kAmber, foregroundColor: const Color(0xFF78350F), padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text('Prepare BAS →', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // BAS Breakdown
          Text('BAS Breakdown', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _BASLine('G1', 'Total sales (inc. GST)', '\$48,800.00'),
          _BASLine('G2', 'Export sales', '\$0.00'),
          _BASLine('G3', 'Other GST-free sales', '\$1,242.30'),
          _BASLine('1A', 'GST on sales', '\$4,280.00'),
          _BASLine('1B', 'GST on purchases', '-\$1,842.50'),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kAmber.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Net GST payable', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
              Text('\$2,437.50', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: kAmberDark)),
            ]),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class _GSTCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _GSTCard(this.label, this.value, this.color, this.icon);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 10),
      Text(label, style: GoogleFonts.inter(fontSize: 12, color: kTextTertiary)),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
    ]),
  );
}

Widget _BASLine(String code, String label, String amount) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(
        width: 32, height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: kTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
        child: Text(code, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: kTeal)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary))),
      Text(amount, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
    ]),
  );
}
