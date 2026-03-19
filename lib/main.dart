import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/gst_screen.dart';
import 'screens/money_rules_screen.dart';
import 'screens/more_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const LedgableApp());
}

class LedgableApp extends StatelessWidget {
  const LedgableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ledgable',
      debugShowCheckedModeBanner: false,
      theme: ledgableTheme(),
      home: const LedgableShell(),
    );
  }
}

class LedgableShell extends StatefulWidget {
  const LedgableShell({super.key});
  @override State<LedgableShell> createState() => _LedgableShellState();
}

class _LedgableShellState extends State<LedgableShell> {
  int _idx = 0;
  final _screens = const [
    DashboardScreen(),
    TransactionsScreen(),
    GSTScreen(),
    MoneyRulesScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: kWhite,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.home_rounded, 'Home', 0),
                _navItem(Icons.receipt_long_rounded, 'Transactions', 1),
                _navItem(Icons.account_balance_rounded, 'GST', 2),
                _navItem(Icons.savings_rounded, 'Rules', 3),
                _navItem(Icons.more_horiz_rounded, 'More', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int idx) {
    final active = _idx == idx;
    return GestureDetector(
      onTap: () => setState(() => _idx = idx),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kTeal.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: active ? kTeal : kTextTertiary),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? kTeal : kTextTertiary)),
        ]),
      ),
    );
  }
}
