import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ledgable brand palette.
///
/// The teal/amber pair and the slate neutrals are carried over from the
/// design prototype so the phone and the web app read as one product. The
/// dark ramp is new: an accounting app gets opened at 11pm and a
/// light-only theme in a dark room is the kind of detail people notice.
const kTeal = Color(0xFF0D9488);
const kTealDark = Color(0xFF134E4A);
const kTeal700 = Color(0xFF0F766E);
const kTealLight = Color(0xFFCCFBF1);
const kTeal50 = Color(0xFFF0FDFA);
// On a dark surface the 500 teal is legible as a fill but not as text;
// 400 clears 4.5:1 against the dark canvas and is used for accent text.
const kTeal400 = Color(0xFF2DD4BF);
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

// Dark ramp. Slate 950 canvas, slate 900 cards, slate 800 hairlines.
const kBgDark = Color(0xFF020617);
const kCardDark = Color(0xFF0F172A);
const kCardDarkRaised = Color(0xFF1E293B);
const kBorderDark = Color(0xFF334155);
const kTextPrimaryDark = Color(0xFFF1F5F9);
const kTextSecondaryDark = Color(0xFFCBD5E1);
// Slate 400 rather than 500: 500 on slate 950 is 4.0:1, under the 4.5:1 floor.
const kTextTertiaryDark = Color(0xFF94A3B8);
const kSuccessDark = Color(0xFF34D399);
const kErrorDark = Color(0xFFF87171);
const kAmberOnDark = Color(0xFFFBBF24);

/// Semantic colours that differ per theme, reached through
/// `Theme.of(context).extension<LedgableColors>()!`.
///
/// Status colours cannot be hard-coded at call sites: `kSuccess` on the dark
/// canvas is 3.4:1, which fails for text. Every screen that renders a
/// positive/negative figure or a status pill goes through here.
@immutable
class LedgableColors extends ThemeExtension<LedgableColors> {
  const LedgableColors({
    required this.canvas,
    required this.card,
    required this.cardRaised,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.accent,
    required this.accentSoft,
  });

  final Color canvas;
  final Color card;

  /// A surface that must sit visibly above [card] — sheets, selected rows.
  final Color cardRaised;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Money in, accepted, paid.
  final Color positive;

  /// Money out, overdue, destructive.
  final Color negative;

  /// Needs attention but nothing is wrong yet.
  final Color warning;

  /// Brand teal at a weight that is legible as text on [canvas].
  final Color accent;

  /// Tinted fill for accent chips and selected states.
  final Color accentSoft;

  static const light = LedgableColors(
    canvas: kBg,
    card: kWhite,
    cardRaised: kBg,
    border: kBorder,
    textPrimary: kTextPrimary,
    textSecondary: kTextSecondary,
    textTertiary: Color(0xFF64748B), // slate 500: 4.8:1 on white, unlike 400
    positive: Color(0xFF047857), // emerald 700 — 4.5:1 as text on white
    negative: Color(0xFFB91C1C), // red 700
    warning: kAmberDark,
    accent: kTeal700,
    accentSoft: kTeal50,
  );

  static const dark = LedgableColors(
    canvas: kBgDark,
    card: kCardDark,
    cardRaised: kCardDarkRaised,
    border: kBorderDark,
    textPrimary: kTextPrimaryDark,
    textSecondary: kTextSecondaryDark,
    textTertiary: kTextTertiaryDark,
    positive: kSuccessDark,
    negative: kErrorDark,
    warning: kAmberOnDark,
    accent: kTeal400,
    accentSoft: Color(0xFF134E4A),
  );

  @override
  LedgableColors copyWith({
    Color? canvas,
    Color? card,
    Color? cardRaised,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? positive,
    Color? negative,
    Color? warning,
    Color? accent,
    Color? accentSoft,
  }) {
    return LedgableColors(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      cardRaised: cardRaised ?? this.cardRaised,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      warning: warning ?? this.warning,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
    );
  }

  @override
  LedgableColors lerp(ThemeExtension<LedgableColors>? other, double t) {
    if (other is! LedgableColors) return this;
    return LedgableColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardRaised: Color.lerp(cardRaised, other.cardRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
    );
  }
}

/// Shorthand for the semantic palette. Every screen uses this.
extension LedgableColorsX on BuildContext {
  LedgableColors get c => Theme.of(this).extension<LedgableColors>()!;
}

ThemeData ledgableTheme() => _build(Brightness.light, LedgableColors.light);

ThemeData ledgableDarkTheme() => _build(Brightness.dark, LedgableColors.dark);

ThemeData _build(Brightness brightness, LedgableColors c) {
  final isDark = brightness == Brightness.dark;
  // ThemeData.light()/dark() are already Material 3 on Flutter 3.41 — passing
  // useMaterial3 explicitly is deprecated.
  final base = isDark ? ThemeData.dark() : ThemeData.light();

  TextTheme textTheme() {
    final inter = GoogleFonts.interTextTheme(base.textTheme);
    return inter.copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        color: c.textPrimary,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        color: c.textPrimary,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: c.textPrimary,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: c.textPrimary,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: c.textPrimary,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: c.textPrimary),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: c.textSecondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: c.textTertiary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.textPrimary,
      ),
    );
  }

  return base.copyWith(
    brightness: brightness,
    scaffoldBackgroundColor: c.canvas,
    primaryColor: kTeal,
    canvasColor: c.canvas,
    dividerColor: c.border,
    colorScheme: (isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      brightness: brightness,
      primary: isDark ? kTeal400 : kTeal,
      onPrimary: isDark ? kTealDark : kWhite,
      secondary: isDark ? kAmberOnDark : kAmber,
      onSecondary: kTextPrimary,
      surface: c.card,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.cardRaised,
      outline: c.border,
      error: c.negative,
      onError: kWhite,
    ),
    textTheme: textTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: c.canvas,
      foregroundColor: c.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: c.textPrimary,
      ),
      iconTheme: IconThemeData(color: c.textSecondary),
    ),
    cardTheme: CardThemeData(
      color: c.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.textSecondary,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: c.textPrimary,
      ),
      subtitleTextStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: c.textSecondary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? kTeal400 : kTeal,
        foregroundColor: isDark ? kTealDark : kWhite,
        // Grey-on-grey disabled buttons are the single most common dark-mode
        // contrast failure; give it an explicit pair in both themes.
        disabledBackgroundColor: isDark ? kBorderDark : kBorder,
        disabledForegroundColor: isDark ? kTextTertiaryDark : kTextSecondary,
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.accent,
        minimumSize: const Size(0, 48),
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: c.card,
      selectedItemColor: c.accent,
      unselectedItemColor: c.textTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.cardRaised,
      side: BorderSide(color: c.border),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: c.textSecondary,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? kCardDarkRaised : kTextPrimary,
      contentTextStyle: GoogleFonts.inter(fontSize: 14, color: kWhite),
      actionTextColor: kTeal400,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      // The prototype left hint and label to the default, which on the dark
      // canvas came out below 4.5:1. Both are set explicitly.
      hintStyle: GoogleFonts.inter(fontSize: 15, color: c.textTertiary),
      labelStyle: GoogleFonts.inter(fontSize: 15, color: c.textSecondary),
      floatingLabelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: c.accent,
      ),
      helperStyle: GoogleFonts.inter(fontSize: 12, color: c.textSecondary),
      errorStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: c.negative),
      prefixIconColor: c.textSecondary,
      suffixIconColor: c.textSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.negative),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.negative, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    extensions: <ThemeExtension<dynamic>>[c],
  );
}
