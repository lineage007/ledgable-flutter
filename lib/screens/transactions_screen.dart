import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _filter = 'All';

  final _txns = [
    ('Officeworks', 'Office Supplies', -247.50, 'Mar 18', '10%', 'Office'),
    ('Acme Corp', 'Client Payment', 5500.00, 'Mar 17', '10%', 'Revenue'),
    ('Telstra', 'Mobile Plan', -89.00, 'Mar 16', '10%', 'Telecom'),
    ('Bank Interest', 'Finance', 42.30, 'Mar 15', 'Free', 'Finance'),
    ('CGU Insurance', 'Business Insurance', -1200.00, 'Mar 14', 'N/A', 'Insurance'),
    ('Adobe', 'Creative Cloud', -79.99, 'Mar 13', '10%', 'Software'),
    ('Beta Ltd', 'Client Payment', 3300.00, 'Mar 12', '10%', 'Revenue'),
    ('Uber', 'Client transport', -34.50, 'Mar 11', '10%', 'Travel'),
    ('AWS', 'Cloud hosting', -156.00, 'Mar 10', '10%', 'Software'),
    ('Delta Corp', 'Consulting fee', 8800.00, 'Mar 9', '10%', 'Revenue'),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'All' ? _txns :
      _filter == 'Income' ? _txns.where((t) => t.$3 > 0).toList() :
      _txns.where((t) => t.$3 < 0).toList();

    return SafeArea(
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Transactions', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800)),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kTeal, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
            ),
          ]),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search transactions...',
              hintStyle: GoogleFonts.inter(color: kTextTertiary, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: kTextTertiary),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // Filter chips
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: ['All', 'Income', 'Expenses', 'GST'].map((f) {
              final active = _filter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? kTeal.withValues(alpha: 0.1) : kWhite,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: active ? kTeal.withValues(alpha: 0.3) : kBorder),
                    ),
                    child: Text(f, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: active ? kTeal : kTextSecondary)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Transaction list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final t = filtered[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: t.$3 > 0 ? kTeal.withValues(alpha: 0.1) : kBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(t.$3 > 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: t.$3 > 0 ? kTeal : kTextTertiary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.$1, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: t.$5 == '10%' ? kTeal.withValues(alpha: 0.1) : t.$5 == 'Free' ? kBg : kBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(t.$5 == '10%' ? '10% GST' : t.$5 == 'Free' ? 'GST-Free' : 'N/A',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: t.$5 == '10%' ? kTeal : kTextTertiary)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(4)),
                        child: Text(t.$6, style: GoogleFonts.inter(fontSize: 10, color: kTextTertiary)),
                      ),
                    ]),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${t.$3 > 0 ? "+" : ""}\$${t.$3.abs().toStringAsFixed(2)}',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: t.$3 > 0 ? kTeal : kTextPrimary)),
                    Text(t.$4, style: GoogleFonts.inter(fontSize: 11, color: kTextTertiary)),
                  ]),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}
