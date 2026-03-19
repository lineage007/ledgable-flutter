import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Greeting
          Text('Good morning, Gary 👋', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: kTextPrimary)),
          const SizedBox(height: 4),
          Text('Thursday, March 19 · AEDT', style: GoogleFonts.inter(fontSize: 13, color: kTextTertiary)),
          const SizedBox(height: 24),

          // Stats row
          Row(children: [
            Expanded(child: _StatCard('Cash Position', '\$51,332', kTeal, Icons.account_balance_wallet_rounded, '+12%')),
            const SizedBox(width: 12),
            Expanded(child: _StatCard('GST Owing', '\$2,438', kAmber, Icons.receipt_rounded, 'Due Apr 28')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatCard('Invoices Due', '\$17,600', const Color(0xFF6366F1), Icons.mail_rounded, '3 unpaid')),
            const SizedBox(width: 12),
            Expanded(child: _StatCard('This Month', '\$33,400', kError, Icons.trending_down_rounded, 'Expenses')),
          ]),
          const SizedBox(height: 24),

          // Cashflow chart
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Cashflow', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
                Row(children: [
                  _ChartLegend(kTeal, 'Income'),
                  const SizedBox(width: 12),
                  _ChartLegend(kError.withValues(alpha: 0.7), 'Expenses'),
                ]),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                height: 160,
                child: BarChart(BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 50,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                      const m = ['Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];
                      return Padding(padding: const EdgeInsets.only(top: 8), child: Text(m[v.toInt()], style: GoogleFonts.inter(fontSize: 10, color: kTextTertiary)));
                    })),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _bar(0, 38.2, 28.1), _bar(1, 41.5, 31.2), _bar(2, 35.8, 29.8),
                    _bar(3, 42.5, 30.5), _bar(4, 39.2, 32.1), _bar(5, 44.1, 33.4),
                  ],
                )),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // AI Insight
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kTealDark, kTeal700]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: kTeal700, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.auto_awesome_rounded, color: kAmber, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AI Insight', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  'Based on last quarter, set aside \$3,200 for GST. Your next BAS is due April 28. March is historically your strongest month.',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF99F6E4), height: 1.5),
                ),
              ])),
            ]),
          ),
          const SizedBox(height: 24),

          // Quick Actions
          Text('Quick Actions', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _QuickAction(Icons.camera_alt_rounded, 'Scan Receipt', kTeal)),
            const SizedBox(width: 10),
            Expanded(child: _QuickAction(Icons.add_circle_rounded, 'Add Income', const Color(0xFF6366F1))),
            const SizedBox(width: 10),
            Expanded(child: _QuickAction(Icons.description_rounded, 'Prepare BAS', kAmber)),
          ]),
          const SizedBox(height: 24),

          // Recent Transactions
          Text('Recent Transactions', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...List.generate(5, (i) {
            final txns = [
              ('Officeworks', 'Office Supplies', -247.50, 'Mar 18'),
              ('Acme Corp', 'Client Payment', 5500.00, 'Mar 17'),
              ('Telstra', 'Mobile Plan', -89.00, 'Mar 16'),
              ('Bank Interest', 'Finance', 42.30, 'Mar 15'),
              ('Adobe', 'Software', -79.99, 'Mar 14'),
            ];
            final t = txns[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: t.$3 > 0 ? kTeal.withValues(alpha: 0.1) : kBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    t.$3 > 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: t.$3 > 0 ? kTeal : kTextTertiary, size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.$1, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
                  Text(t.$2, style: GoogleFonts.inter(fontSize: 12, color: kTextTertiary)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    '${t.$3 > 0 ? "+" : ""}\$${t.$3.abs().toStringAsFixed(2)}',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: t.$3 > 0 ? kTeal : kTextPrimary),
                  ),
                  Text(t.$4, style: GoogleFonts.inter(fontSize: 11, color: kTextTertiary)),
                ]),
              ]),
            );
          }),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  BarChartGroupData _bar(int x, double income, double expense) {
    return BarChartGroupData(x: x, barRods: [
      BarChartRodData(toY: income, color: kTeal, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
      BarChartRodData(toY: expense, color: kError.withValues(alpha: 0.7), width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, badge;
  final Color color;
  final IconData icon;
  const _StatCard(this.label, this.value, this.color, this.icon, this.badge);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Icon(icon, size: 18, color: color),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(badge, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ),
      ]),
      const SizedBox(height: 12),
      Text(label, style: GoogleFonts.inter(fontSize: 12, color: kTextTertiary)),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary)),
    ]),
  );
}

class _ChartLegend extends StatelessWidget {
  final Color color; final String label;
  const _ChartLegend(this.color, this.label);
  @override Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 4),
    Text(label, style: GoogleFonts.inter(fontSize: 11, color: kTextTertiary)),
  ]);
}

class _QuickAction extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _QuickAction(this.icon, this.label, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 24),
      const SizedBox(height: 8),
      Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]),
  );
}
