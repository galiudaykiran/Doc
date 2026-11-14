import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Utility class for improved text rendering across the app
class TextUtils {
  TextUtils._();

  /// Returns a TextStyle with optimized rendering properties
  static TextStyle getClearTextStyle({
    required BuildContext context,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize ?? 14,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
      letterSpacing: letterSpacing ?? 0.25,
      height: height ?? 1.5,
      decoration: decoration,
    );
  }

  /// For headings with maximum clarity
  static TextStyle getHeadingStyle({
    required BuildContext context,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize ?? 24,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color ?? Theme.of(context).textTheme.displayLarge?.color,
      letterSpacing: -0.3,
      height: 1.3,
    );
  }

  /// For body text with optimal readability
  static TextStyle getBodyStyle({
    required BuildContext context,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize ?? 14,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
      letterSpacing: 0.5,
      height: 1.5,
    );
  }

  /// For labels and buttons
  static TextStyle getLabelStyle({
    required BuildContext context,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize ?? 14,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color ?? Theme.of(context).textTheme.labelLarge?.color,
      letterSpacing: 0.1,
      height: 1.4,
    );
  }

  /// For captions and hints
  static TextStyle getCaptionStyle({
    required BuildContext context,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize ?? 12,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color ?? Theme.of(context).textTheme.bodySmall?.color,
      letterSpacing: 0.4,
      height: 1.4,
    );
  }
}
