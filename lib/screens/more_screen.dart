import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('More', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
            child: Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [kTeal, kTeal700]), borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text('GC', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Gary Cakir', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
                Text('Business Plan', style: GoogleFonts.inter(fontSize: 12, color: kTextTertiary)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: kTextTertiary),
            ]),
          ),
          const SizedBox(height: 20),
          _section('Tools'),
          _item(Icons.account_balance_rounded, 'Bank Feeds', 'Connected banks', kTeal),
          _item(Icons.trending_up_rounded, 'Cashflow', '30/60/90 day forecast', const Color(0xFF6366F1)),
          _item(Icons.camera_alt_rounded, 'Scan Receipt', 'AI-powered scanning', kAmber),
          _item(Icons.description_rounded, 'Invoicing', 'Create & send', kTeal),
          const SizedBox(height: 16),
          _section('Settings'),
          _item(Icons.business_rounded, 'Business Details', 'ABN, GST, FY', kTextSecondary),
          _item(Icons.people_rounded, 'Team', 'Users & access', kTextSecondary),
          _item(Icons.notifications_rounded, 'Notifications', 'Alerts', kTextSecondary),
          const SizedBox(height: 16),
          _section('Support'),
          _item(Icons.help_outline_rounded, 'Help Centre', 'FAQs & guides', kTextSecondary),
          _item(Icons.chat_rounded, 'Contact', 'hello@ledgable.co', kTextSecondary),
          const SizedBox(height: 24),
          Center(child: Text('Ledgable v1.0.0 · Made in Australia', style: GoogleFonts.inter(fontSize: 11, color: kTextTertiary))),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: kTextTertiary, letterSpacing: 0.5)),
  );

  Widget _item(IconData icon, String title, String sub, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
        Text(sub, style: GoogleFonts.inter(fontSize: 12, color: kTextTertiary)),
      ])),
      const Icon(Icons.chevron_right_rounded, color: kTextTertiary, size: 20),
    ]),
  );
}
