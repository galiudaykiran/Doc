import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ──── Design System Colors ────
  static const Color primaryIndigo = Color(0xFF000000);
  static const Color deepIndigo = Color(0xFF111111);
  static const Color accentViolet = Color(0xFF333333);
  static const Color accentPink = Color(0xFF555555);
  static const Color accentTeal = Color(0xFF777777);

  /// Generate a light theme with a custom accent color
  static ThemeData lightThemeWith(Color accent) {
    final HSLColor hsl = HSLColor.fromColor(accent);
    final Color secondary = hsl
        .withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0))
        .toColor();
    final Color onPrimary = accent.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: accent,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: AppBarTheme(
        backgroundColor: accent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: onPrimary),
        titleTextStyle: GoogleFonts.poppins(
          color: onPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onPrimary,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onPrimary,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFF78909C),
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          height: 1.4,
        ),
        labelStyle: GoogleFonts.poppins(
          color: const Color(0xFF546E7A),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          height: 1.4,
        ),
        prefixIconColor: const Color(0xFF37474F),
        suffixIconColor: const Color(0xFF37474F),
        iconColor: const Color(0xFF37474F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
        ),
      ),
      textTheme: _lightTextTheme,
      colorScheme: ColorScheme.light(
        primary: accent,
        secondary: secondary,
        tertiary: Colors.grey,
        surface: Colors.white,
        error: const Color(0xFFD50000),
        onPrimary: onPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: accent.withOpacity(0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF37474F), size: 24),
      primaryIconTheme: IconThemeData(color: accent, size: 24),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: accent,
        unselectedItemColor: const Color(0xFF78909C),
        showUnselectedLabels: false,
        elevation: 10,
      ),
    );
  }

  /// Generate a dark theme with a custom accent color
  static ThemeData darkThemeWith(Color accent) {
    final HSLColor hsl = HSLColor.fromColor(accent);
    final Color secondary = hsl
        .withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0))
        .toColor();
    final Color onPrimary = accent.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: accent,
      scaffoldBackgroundColor: const Color(0xFF000000), // OLED Black
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent, // True Glassmorphism starting point
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: accent),
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onPrimary,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF121212).withOpacity(0.6), // Frosted input fields
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFF888888),
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          height: 1.4,
        ),
        labelStyle: GoogleFonts.poppins(
          color: const Color(0xFFAAAAAA),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          height: 1.4,
        ),
        prefixIconColor: accent,
        suffixIconColor: const Color(0xFFAAAAAA),
        iconColor: const Color(0xFFAAAAAA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: accent.withOpacity(0.5), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      textTheme: _darkTextTheme,
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: secondary,
        tertiary: Colors.grey,
        surface: const Color(0xFF0F0F0F), // Near black for surfaces
        error: const Color(0xFFFF5252),
        onPrimary: onPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: const Color(0xFF111111), // Slight elevation color
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
      iconTheme: IconThemeData(color: accent, size: 24),
      primaryIconTheme: IconThemeData(color: accent, size: 24),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent, // Ready for backdrop filter
        selectedItemColor: accent,
        unselectedItemColor: const Color(0xFF6B7280),
        showUnselectedLabels: false,
        elevation: 0,
      ),
    );
  }

  // Backward-compatible static themes using black and white
  static final ThemeData lightTheme = lightThemeWith(const Color(0xFF000000));
  static final ThemeData darkTheme = darkThemeWith(const Color(0xFFFFFFFF));

  // ──── Shared Text Themes ────
  static final TextTheme _lightTextTheme = TextTheme(
    displayLarge: GoogleFonts.poppins(
      color: const Color(0xFF102027),
      fontWeight: FontWeight.bold,
      fontSize: 32,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    displayMedium: GoogleFonts.poppins(
      color: const Color(0xFF102027),
      fontWeight: FontWeight.bold,
      fontSize: 28,
      letterSpacing: -0.3,
      height: 1.2,
    ),
    displaySmall: GoogleFonts.poppins(
      color: const Color(0xFF102027),
      fontWeight: FontWeight.w600,
      fontSize: 24,
      height: 1.3,
    ),
    headlineLarge: GoogleFonts.poppins(
      color: const Color(0xFF102027),
      fontWeight: FontWeight.w600,
      fontSize: 22,
      height: 1.3,
    ),
    headlineMedium: GoogleFonts.poppins(
      color: const Color(0xFF102027),
      fontWeight: FontWeight.w600,
      fontSize: 20,
      letterSpacing: 0.15,
      height: 1.3,
    ),
    titleLarge: GoogleFonts.poppins(
      color: const Color(0xFF102027),
      fontWeight: FontWeight.w600,
      fontSize: 20,
      letterSpacing: 0.15,
      height: 1.4,
    ),
    titleMedium: GoogleFonts.poppins(
      color: const Color(0xFF102027),
      fontWeight: FontWeight.w500,
      fontSize: 16,
      letterSpacing: 0.15,
      height: 1.4,
    ),
    titleSmall: GoogleFonts.poppins(
      color: const Color(0xFF37474F),
      fontWeight: FontWeight.w500,
      fontSize: 14,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    bodyLarge: GoogleFonts.poppins(
      color: const Color(0xFF263238),
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      height: 1.5,
    ),
    bodyMedium: GoogleFonts.poppins(
      color: const Color(0xFF37474F),
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.5,
    ),
    bodySmall: GoogleFonts.poppins(
      color: const Color(0xFF546E7A),
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      height: 1.4,
    ),
    labelLarge: GoogleFonts.poppins(
      color: const Color(0xFF102027),
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    labelMedium: GoogleFonts.poppins(
      color: const Color(0xFF37474F),
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.3,
    ),
    labelSmall: GoogleFonts.poppins(
      color: const Color(0xFF546E7A),
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.3,
    ),
    headlineSmall: GoogleFonts.poppins(
      color: const Color(0xFF102027),
      fontWeight: FontWeight.w600,
      fontSize: 18,
      height: 1.3,
    ),
  );

  static final TextTheme _darkTextTheme = TextTheme(
    displayLarge: GoogleFonts.poppins(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 32,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    displayMedium: GoogleFonts.poppins(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 28,
      letterSpacing: -0.3,
      height: 1.2,
    ),
    displaySmall: GoogleFonts.poppins(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 24,
      height: 1.3,
    ),
    headlineLarge: GoogleFonts.poppins(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 22,
      height: 1.3,
    ),
    headlineMedium: GoogleFonts.poppins(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 20,
      letterSpacing: 0.15,
      height: 1.3,
    ),
    titleLarge: GoogleFonts.poppins(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 20,
      letterSpacing: 0.15,
      height: 1.4,
    ),
    titleMedium: GoogleFonts.poppins(
      color: const Color(0xFFE0E0E0),
      fontWeight: FontWeight.w500,
      fontSize: 16,
      letterSpacing: 0.15,
      height: 1.4,
    ),
    titleSmall: GoogleFonts.poppins(
      color: const Color(0xFFBDBDBD),
      fontWeight: FontWeight.w500,
      fontSize: 14,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    bodyLarge: GoogleFonts.poppins(
      color: const Color(0xFFEEEEEE),
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      height: 1.5,
    ),
    bodyMedium: GoogleFonts.poppins(
      color: const Color(0xFFBDBDBD),
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.5,
    ),
    bodySmall: GoogleFonts.poppins(
      color: const Color(0xFF9E9E9E),
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      height: 1.4,
    ),
    labelLarge: GoogleFonts.poppins(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    labelMedium: GoogleFonts.poppins(
      color: const Color(0xFFBDBDBD),
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.3,
    ),
    labelSmall: GoogleFonts.poppins(
      color: const Color(0xFF9E9E9E),
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.3,
    ),
    headlineSmall: GoogleFonts.poppins(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 18,
      height: 1.3,
    ),
  );
}
