import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Utility class for robust, offline-resilient, non-overflowing text rendering
class TextUtils {
  TextUtils._();

  static const List<String> offlineFontFallbacks = [
    'Poppins',
    'Inter',
    'Segoe UI',
    'Roboto',
    '-apple-system',
    'BlinkMacSystemFont',
    'Arial',
    'sans-serif',
  ];

  /// Formats file size in bytes to a human-readable string (B, KB, MB, GB).
  /// Dynamically transitions from KB to MB when size is 1000 KB or larger.
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final double kb = bytes / 1024.0;
    if (kb >= 1000.0) {
      final double mb = kb / 1024.0;
      if (mb >= 1000.0) {
        final double gb = mb / 1024.0;
        return '${gb.toStringAsFixed(2)} GB';
      }
      return '${mb.toStringAsFixed(2)} MB';
    }
    return '${kb.toStringAsFixed(2)} KB';
  }

  /// Returns a TextStyle with optimized rendering properties and offline fallbacks
  static TextStyle getClearTextStyle({
    required BuildContext context,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    try {
      return GoogleFonts.poppins(
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.w400,
        color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
        letterSpacing: letterSpacing ?? 0.25,
        height: height ?? 1.45,
        decoration: decoration,
      );
    } catch (_) {
      return TextStyle(
        fontFamilyFallback: offlineFontFallbacks,
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.w400,
        color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
        letterSpacing: letterSpacing ?? 0.25,
        height: height ?? 1.45,
        decoration: decoration,
      );
    }
  }

  /// For headings with maximum clarity & overflow protection
  static TextStyle getHeadingStyle({
    required BuildContext context,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    try {
      return GoogleFonts.poppins(
        fontSize: fontSize ?? 24,
        fontWeight: fontWeight ?? FontWeight.w600,
        color: color ?? Theme.of(context).textTheme.displayLarge?.color,
        letterSpacing: -0.3,
        height: 1.25,
      );
    } catch (_) {
      return TextStyle(
        fontFamilyFallback: offlineFontFallbacks,
        fontSize: fontSize ?? 24,
        fontWeight: fontWeight ?? FontWeight.w600,
        color: color ?? Theme.of(context).textTheme.displayLarge?.color,
        letterSpacing: -0.3,
        height: 1.25,
      );
    }
  }

  /// For body text with optimal readability
  static TextStyle getBodyStyle({
    required BuildContext context,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    try {
      return GoogleFonts.poppins(
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.w400,
        color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
        letterSpacing: 0.35,
        height: 1.45,
      );
    } catch (_) {
      return TextStyle(
        fontFamilyFallback: offlineFontFallbacks,
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.w400,
        color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
        letterSpacing: 0.35,
        height: 1.45,
      );
    }
  }

  /// For labels and buttons
  static TextStyle getLabelStyle({
    required BuildContext context,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    try {
      return GoogleFonts.poppins(
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.w500,
        color: color ?? Theme.of(context).textTheme.labelLarge?.color,
        letterSpacing: 0.1,
        height: 1.35,
      );
    } catch (_) {
      return TextStyle(
        fontFamilyFallback: offlineFontFallbacks,
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.w500,
        color: color ?? Theme.of(context).textTheme.labelLarge?.color,
        letterSpacing: 0.1,
        height: 1.35,
      );
    }
  }

  /// For captions and hints
  static TextStyle getCaptionStyle({
    required BuildContext context,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    try {
      return GoogleFonts.poppins(
        fontSize: fontSize ?? 12,
        fontWeight: fontWeight ?? FontWeight.w400,
        color: color ?? Theme.of(context).textTheme.bodySmall?.color,
        letterSpacing: 0.3,
        height: 1.35,
      );
    } catch (_) {
      return TextStyle(
        fontFamilyFallback: offlineFontFallbacks,
        fontSize: fontSize ?? 12,
        fontWeight: fontWeight ?? FontWeight.w400,
        color: color ?? Theme.of(context).textTheme.bodySmall?.color,
        letterSpacing: 0.3,
        height: 1.35,
      );
    }
  }

  /// Create safe single-line ellipsis text that never overflows parent width
  static Widget safeSingleLineText(
    String text, {
    TextStyle? style,
    TextAlign? textAlign,
  }) {
    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }
}
