import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ──── Material Design 3 Design Tokens ────

  // Theme A: Google Daylight (Light Mode - Default)
  static const Color lightBackground = Color(0xFFF8FAFD); // Cool Alabaster
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure White
  static const Color lightSurfaceBorder = Color(0xFFE0E3EB);
  static const Color lightTonal = Color(0xFFE9EEF6); // Google Pill Gray-Blue
  static const Color lightPrimary = Color(0xFF0B57D0); // Google Royal Blue
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFD3E3FD);
  static const Color lightOnPrimaryContainer = Color(0xFF041E49);
  static const Color lightSecondaryContainer = Color(0xFFC2E7FF); // Sky Tint
  static const Color lightOnSecondaryContainer = Color(0xFF001D35);
  static const Color lightTertiaryContainer = Color(0xFFE8DEF8); // Soft Lavender
  static const Color lightOnTertiaryContainer = Color(0xFF1D192B);
  static const Color lightTextPrimary = Color(0xFF1F1F1F);
  static const Color lightTextSecondary = Color(0xFF444746);
  static const Color lightTextMuted = Color(0xFF747775);

  // Theme B: Signature Obsidian Dark Mode
  static const Color darkBackground = Color(0xFF0E1111); // Deep Obsidian
  static const Color darkSurface = Color(0xFF1C1E20);
  static const Color darkSurfaceBorder = Color(0xFF2C2F33);
  static const Color darkTonal = Color(0xFF24272B);
  static const Color darkPrimary = Color(0xFF8F85FF); // Periwinkle Violet
  static const Color darkOnPrimary = Color(0xFF120D3A);
  static const Color darkPrimaryContainer = Color(0xFF2A264A);
  static const Color darkOnPrimaryContainer = Color(0xFFE5E0FF);
  static const Color darkSecondaryAccent = Color(0xFF93E9BE); // Mint Green
  static const Color darkTextPrimary = Color(0xFFE8EBF0);
  static const Color darkTextSecondary = Color(0xFFA6ACB8);
  static const Color darkTextMuted = Color(0xFF80868B);

  // ──── Helper Accessors ────
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? darkBackground : lightBackground;

  static Color surface(BuildContext context) =>
      isDark(context) ? darkSurface : lightSurface;

  static Color surfaceBorder(BuildContext context) =>
      isDark(context) ? darkSurfaceBorder : lightSurfaceBorder;

  static Color tonal(BuildContext context) =>
      isDark(context) ? darkTonal : lightTonal;

  static Color primary(BuildContext context) =>
      isDark(context) ? darkPrimary : lightPrimary;

  static Color primaryContainer(BuildContext context) =>
      isDark(context) ? darkPrimaryContainer : lightPrimaryContainer;

  static Color onPrimaryContainer(BuildContext context) =>
      isDark(context) ? darkOnPrimaryContainer : lightOnPrimaryContainer;

  static Color secondaryContainer(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E3A2F) : lightSecondaryContainer;

  static Color onSecondaryContainer(BuildContext context) =>
      isDark(context) ? darkSecondaryAccent : lightOnSecondaryContainer;

  static Color tertiaryContainer(BuildContext context) =>
      isDark(context) ? const Color(0xFF352B44) : lightTertiaryContainer;

  static Color onTertiaryContainer(BuildContext context) =>
      isDark(context) ? const Color(0xFFE8DEF8) : lightOnTertiaryContainer;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? darkTextPrimary : lightTextPrimary;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? darkTextMuted : lightTextMuted;

  // ──── Light ThemeData ────
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: lightPrimary,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: lightPrimary,
      onPrimary: lightOnPrimary,
      primaryContainer: lightPrimaryContainer,
      onPrimaryContainer: lightOnPrimaryContainer,
      secondary: Color(0xFF0288D1),
      onSecondary: Colors.white,
      secondaryContainer: lightSecondaryContainer,
      onSecondaryContainer: lightOnSecondaryContainer,
      tertiary: Color(0xFF6750A4),
      onTertiary: Colors.white,
      tertiaryContainer: lightTertiaryContainer,
      onTertiaryContainer: lightOnTertiaryContainer,
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: lightSurface,
      onSurface: lightTextPrimary,
      surfaceContainerHighest: lightTonal,
      outline: lightSurfaceBorder,
      outlineVariant: Color(0xFFC4C7C5),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: lightSurfaceBorder, width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: lightTextPrimary, size: 22),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: lightTextPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 22,
        letterSpacing: -0.3,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: lightSurface,
      elevation: 0,
      indicatorColor: lightPrimaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: lightOnPrimaryContainer, size: 24);
        }
        return const IconThemeData(color: lightTextSecondary, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: lightTextPrimary,
          );
        }
        return GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: lightTextSecondary,
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: lightPrimary,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightTonal,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      hintStyle: GoogleFonts.plusJakartaSans(
        color: lightTextMuted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: lightPrimary, width: 1.5),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: lightSurfaceBorder,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    textTheme: _buildTextTheme(lightTextPrimary, lightTextSecondary, lightTextMuted),
  );

  // ──── Dark ThemeData ────
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: darkPrimary,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: darkPrimary,
      onPrimary: darkOnPrimary,
      primaryContainer: darkPrimaryContainer,
      onPrimaryContainer: darkOnPrimaryContainer,
      secondary: darkSecondaryAccent,
      onSecondary: Color(0xFF003822),
      secondaryContainer: Color(0xFF1E3A2F),
      onSecondaryContainer: darkSecondaryAccent,
      tertiary: Color(0xFFD0BCFF),
      onTertiary: Color(0xFF381E72),
      tertiaryContainer: Color(0xFF352B44),
      onTertiaryContainer: Color(0xFFE8DEF8),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: darkTonal,
      outline: darkSurfaceBorder,
      outlineVariant: Color(0xFF444746),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: darkSurfaceBorder, width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: darkTextPrimary, size: 22),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: darkTextPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 22,
        letterSpacing: -0.3,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: darkSurface,
      elevation: 0,
      indicatorColor: darkPrimaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: darkOnPrimaryContainer, size: 24);
        }
        return const IconThemeData(color: darkTextSecondary, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: darkTextPrimary,
          );
        }
        return GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: darkTextSecondary,
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: darkPrimary,
      foregroundColor: darkOnPrimary,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimary,
        foregroundColor: darkOnPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkTonal,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      hintStyle: GoogleFonts.plusJakartaSans(
        color: darkTextMuted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: darkPrimary, width: 1.5),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: darkSurfaceBorder,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    textTheme: _buildTextTheme(darkTextPrimary, darkTextSecondary, darkTextMuted),
  );

  // ──── Backward Compatibility Methods ────
  static ThemeData lightThemeWith(Color accent) => lightTheme;
  static ThemeData darkThemeWith(Color accent) => darkTheme;

  // ──── Typography Hierarchy ────
  static TextTheme _buildTextTheme(Color primary, Color secondary, Color muted) {
    return TextTheme(
      displayLarge: GoogleFonts.plusJakartaSans(
        color: primary,
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        color: primary,
        fontWeight: FontWeight.w700,
        fontSize: 26, // Greeting Header
        letterSpacing: -0.4,
      ),
      displaySmall: GoogleFonts.plusJakartaSans(
        color: primary,
        fontWeight: FontWeight.w600,
        fontSize: 22, // App Title
        letterSpacing: -0.3,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        color: primary,
        fontWeight: FontWeight.w600,
        fontSize: 20,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        color: primary,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        color: primary,
        fontWeight: FontWeight.w600,
        fontSize: 16, // Section Headers
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        color: primary,
        fontWeight: FontWeight.w600,
        fontSize: 15, // Card Titles
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        color: secondary,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        color: primary,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        color: secondary,
        fontSize: 13, // Body / Subtitles
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        color: muted,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        color: primary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        color: secondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        color: muted,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
