import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Ledgable Brand Colors
const kTeal = Color(0xFF0D9488);
const kTealDark = Color(0xFF134E4A);
const kTeal700 = Color(0xFF0F766E);
const kTealLight = Color(0xFFCCFBF1);
const kTeal50 = Color(0xFFF0FDFA);
const kAmber = Color(0xFFF59E0B);
const kAmberDark = Color(0xFFD97706);
const kAmberLight = Color(0xFFFEF3C7);
const kBg = Color(0xFFF8FAFC);
const kWhite = Color(0xFFFFFFFF);
const kTextPrimary = Color(0xFF0F172A);
const kTextSecondary = Color(0xFF475569);
const kTextTertiary = Color(0xFF94A3B8);
const kBorder = Color(0xFFE2E8F0);
const kSurface = Color(0xFFF8FAFC);
const kSuccess = Color(0xFF10B981);
const kError = Color(0xFFEF4444);

ThemeData ledgableTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: kBg,
    primaryColor: kTeal,
    colorScheme: const ColorScheme.light(
      primary: kTeal,
      secondary: kAmber,
      surface: kWhite,
      error: kError,
      onPrimary: kWhite,
      onSurface: kTextPrimary,
    ),
    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(fontSize: 56, fontWeight: FontWeight.w800, color: kTextPrimary),
      displayMedium: GoogleFonts.plusJakartaSans(fontSize: 40, fontWeight: FontWeight.w800, color: kTextPrimary),
      headlineLarge: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700, color: kTextPrimary),
      headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700, color: kTextPrimary),
      headlineSmall: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary),
      titleLarge: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: kTextPrimary),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: kTextPrimary),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: kTextSecondary),
      bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: kTextTertiary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kWhite,
      foregroundColor: kTextPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary),
    ),
    cardTheme: CardThemeData(
      color: kWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorder, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kTeal,
        foregroundColor: kWhite,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kWhite,
      selectedItemColor: kTeal,
      unselectedItemColor: kTextTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kWhite,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kTeal, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
